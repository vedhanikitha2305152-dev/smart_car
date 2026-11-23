import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';

final _log = Logger('MapServices');

/// Geocoding result from Nominatim
class SearchResult {
  const SearchResult({
    required this.displayName,
    required this.location,
    required this.type,
  });

  final String displayName;
  final LatLng location;
  final String type;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      displayName: json['display_name'] as String? ?? 'Unknown Location',
      location: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String),
      ),
      type: json['type'] as String? ?? 'place',
    );
  }
}

/// Individual turn step from OSRM
class RouteStep {
  const RouteStep({
    required this.dir,
    required this.distanceMeters,
    required this.street,
  });

  final String dir; // 'L', 'R', 'S', 'U'
  final int distanceMeters;
  final String street;
}

/// Route result from OSRM
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    return '${hours}h ${remainingMin}m';
  }
}

/// POI entity found via Overpass
class MapPoi {
  const MapPoi({
    required this.id,
    required this.location,
    required this.name,
    required this.amenityType,
  });

  final int id;
  final LatLng location;
  final String name;
  final String amenityType;
}

class MapServices {
  MapServices({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Rate-limiting timestamp for Nominatim (1 req/sec max)
  static DateTime _lastNominatimCall = DateTime.fromMillisecondsSinceEpoch(0);

  // 5-minute POI cache: key = "${type}_${roundedLat}_${roundedLng}"
  static final Map<String, _PoiCacheEntry> _poiCache = {};

  // High-speed OSM search with Photon + Nominatim fallback
  Future<List<SearchResult>> searchPlaces(String query, {LatLng? near}) async {
    if (query.trim().isEmpty) return const [];

    // 1. Try Photon (fast, no rate-limits, OpenStreetMap based)
    try {
      var photonUrl = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5';
      if (near != null) {
        photonUrl += '&lat=${near.latitude}&lon=${near.longitude}';
      }
      final photonRes = await _client.get(Uri.parse(photonUrl)).timeout(const Duration(seconds: 4));
      if (photonRes.statusCode == 200) {
        final data = jsonDecode(photonRes.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final results = <SearchResult>[];
          for (final f in features) {
            final feat = f as Map<String, dynamic>;
            final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List<dynamic>? ?? [0, 0];
            final props = feat['properties'] as Map<String, dynamic>? ?? {};

            final name = props['name'] as String? ?? '';
            final city = props['city'] as String? ?? (props['district'] as String? ?? '');
            final state = props['state'] as String? ?? '';
            final label = [name, city, state].where((s) => s.isNotEmpty).join(', ');

            if (coords.length >= 2) {
              results.add(SearchResult(
                displayName: label.isNotEmpty ? label : query,
                location: LatLng(
                  (coords[1] as num).toDouble(),
                  (coords[0] as num).toDouble(),
                ),
                type: props['type'] as String? ?? 'place',
              ));
            }
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      _log.warning('Photon geocoder failed, falling back to Nominatim: $e');
    }

    // 2. Fallback to Nominatim
    final now = DateTime.now();
    final elapsed = now.difference(_lastNominatimCall);
    if (elapsed.inMilliseconds < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
    }
    _lastNominatimCall = DateTime.now();

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5',
    );

    try {
      final response = await _client.get(
        url,
        headers: {
          'User-Agent': 'SmartCarApp/1.0 (smartcar-support@example.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _log.warning('Nominatim search failed with status ${response.statusCode}');
        return const [];
      }
    } catch (e, st) {
      _log.warning('Nominatim search exception: $e\n$st');
      return const [];
    }
  }

  // STUB: OSRM public server — replace with a paid routing service for production
  Future<RouteResult?> fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    try {
      final response = await _client.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes == null || routes.isEmpty) return null;

        final route = routes.first as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List<dynamic>;

        final points = coordinates.map((c) {
          final pair = c as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList();

        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();

        // Parse turn-by-turn steps
        final legs = route['legs'] as List<dynamic>? ?? [];
        final steps = <RouteStep>[];
        for (final leg in legs) {
          final legSteps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
          for (final s in legSteps) {
            final stepMap = s as Map<String, dynamic>;
            final maneuver = stepMap['maneuver'] as Map<String, dynamic>? ?? {};
            final modifier = (maneuver['modifier'] as String?)?.toLowerCase() ?? '';
            final type = (maneuver['type'] as String?)?.toLowerCase() ?? '';
            final name = stepMap['name'] as String? ?? '';
            final dist = (stepMap['distance'] as num?)?.round() ?? 0;

            String dir = 'S';
            if (modifier.contains('left')) {
              dir = 'L';
            } else if (modifier.contains('right')) {
              dir = 'R';
            } else if (modifier.contains('uturn')) {
              dir = 'U';
            } else if (type == 'arrive') {
              dir = 'S';
            }

            final streetName = name.isNotEmpty ? name : 'Next Waypoint';
            if (dist > 0 || type == 'arrive') {
              steps.add(RouteStep(dir: dir, distanceMeters: dist, street: streetName));
            }
          }
        }

        return RouteResult(
          points: points,
          distanceMeters: distance,
          durationSeconds: duration,
          steps: steps,
        );
      }
    } catch (e, st) {
      _log.warning('OSRM route fetch failed: $e\n$st');
    }
    return null;
  }

  /// Query Overpass API for POIs around center with 5-minute cache
  Future<List<MapPoi>> fetchAmenities({
    required LatLng center,
    required String amenityType, // "parking", "fuel", "charging_station"
  }) async {
    final cacheKey = '${amenityType}_${center.latitude.toStringAsFixed(2)}_${center.longitude.toStringAsFixed(2)}';
    final cached = _poiCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      _log.info('Returning cached POIs for $cacheKey (${cached.pois.length} items)');
      return cached.pois;
    }

    // 1500m radius query around center
    final overpassQuery =
        '[out:json][timeout:8];node(around:1500,${center.latitude},${center.longitude})[amenity=$amenityType];out 15;';

    final url = Uri.parse(
      'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}',
    );

    try {
      final response = await _client.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = json['elements'] as List<dynamic>? ?? [];

        final pois = elements.map((e) {
          final m = e as Map<String, dynamic>;
          final tags = m['tags'] as Map<String, dynamic>? ?? {};
          return MapPoi(
            id: m['id'] as int,
            location: LatLng(
              (m['lat'] as num).toDouble(),
              (m['lon'] as num).toDouble(),
            ),
            name: tags['name'] as String? ?? _amenityDefaultName(amenityType),
            amenityType: amenityType,
          );
        }).toList();

        _poiCache[cacheKey] = _PoiCacheEntry(
          pois: pois,
          fetchedAt: DateTime.now(),
        );
        return pois;
      }
    } catch (e, st) {
      _log.warning('Overpass query failed: $e\n$st');
    }
    return const [];
  }

  String _amenityDefaultName(String type) {
    switch (type) {
      case 'parking':
        return 'Public Parking';
      case 'fuel':
        return 'Gas Station';
      case 'charging_station':
        return 'EV Charger';
      default:
        return 'POI';
    }
  }
}

class _PoiCacheEntry {
  _PoiCacheEntry({required this.pois, required this.fetchedAt});
  final List<MapPoi> pois;
  final DateTime fetchedAt;

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > const Duration(minutes: 5);
}
