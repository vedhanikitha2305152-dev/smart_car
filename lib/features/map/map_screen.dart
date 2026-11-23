import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/debouncer.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/map/map_provider.dart';
import '../../data/map/map_services.dart';
import '../../data/models/enums.dart';
import '../../data/models/gps_fix.dart';
import '../../providers/gps_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/telemetry_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final MapProvider _mapProvider = const CartoDarkMapProvider();
  final MapServices _mapServices = MapServices();
  final Debouncer _searchDebouncer = Debouncer(duration: const Duration(milliseconds: 500));
  final TextEditingController _searchController = TextEditingController();

  LatLng _currentCarLocation = const LatLng(40.4168, -3.7038);
  double _currentHeading = 90.0;
  DateTime? _lastGpsTimestamp;

  LatLng? _phoneLocation;
  bool _phoneLocationAvailable = false;

  // Search
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  bool _showSearchResults = false;

  // Routing
  RouteResult? _activeRoute;
  String? _destinationName;
  int _currentStepIndex = 0;

  // POIs
  String? _selectedAmenity; // "parking", "fuel", "charging_station"
  List<MapPoi> _activePois = [];

  Timer? _staleCheckTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPersistedLocation();
    _initPhoneLocation();

    _staleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadPersistedLocation() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final lat = prefs.getDouble('last_car_lat');
    final lng = prefs.getDouble('last_car_lng');
    final ts = prefs.getInt('last_car_ts');
    if (lat != null && lng != null) {
      setState(() {
        _currentCarLocation = LatLng(lat, lng);
        if (ts != null) {
          _lastGpsTimestamp = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      });
    }
  }

  Future<void> _initPhoneLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (mounted) {
          setState(() {
            _phoneLocation = LatLng(pos.latitude, pos.longitude);
            _phoneLocationAvailable = true;
            _currentCarLocation = _phoneLocation!;
          });
          _mapController.move(_phoneLocation!, 15.0);
        }
      }
    } catch (_) {
      // Permission denied or GPS disabled — gracefully hide phone dot
    }
  }

  void _onGpsFixReceived(GpsFix fix) {
    _lastGpsTimestamp = fix.timestamp;
    _currentHeading = fix.heading;
    _currentCarLocation = LatLng(fix.lat, fix.lng);

    // Persist fix
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setDouble('last_car_lat', fix.lat);
    prefs.setDouble('last_car_lng', fix.lng);
    prefs.setInt('last_car_ts', fix.timestamp.millisecondsSinceEpoch);
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    _searchDebouncer(() async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await _mapServices.searchPlaces(query, near: _phoneLocation ?? _currentCarLocation);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
        });
      }
    });
  }

  void _onSearchSubmitted(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    final results = await _mapServices.searchPlaces(query, near: _phoneLocation ?? _currentCarLocation);
    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
      });
      if (results.isNotEmpty) {
        _selectSearchResult(results.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            content: Text('No places found. Tap directly on the map to navigate.',
                style: TextStyle(color: AppColors.warning)),
          ),
        );
      }
    }
  }

  Future<void> _selectSearchResult(SearchResult place) async {
    HapticFeedback.lightImpact();
    setState(() {
      _showSearchResults = false;
      _destinationName = place.displayName.split(',').first;
      _searchController.text = _destinationName!;
    });
    FocusScope.of(context).unfocus();

    _mapController.move(place.location, 14.5);

    // Fetch OSRM route from car/phone to destination
    final start = _phoneLocation ?? _currentCarLocation;
    final route = await _mapServices.fetchRoute(start, place.location);
    if (mounted) {
      setState(() {
        _activeRoute = route;
        _currentStepIndex = 0;
      });
      if (route != null && route.steps.isNotEmpty) {
        final step = route.steps.first;
        ref.read(vehicleRepositoryProvider).sendTurn(
          dir: step.dir,
          distanceMeters: step.distanceMeters,
          street: step.street,
        );
      }
    }
  }

  Future<void> _routeToPoint(LatLng dest, {String name = 'Destination'}) async {
    HapticFeedback.lightImpact();
    final start = _phoneLocation ?? _currentCarLocation;
    setState(() {
      _destinationName = name;
      _searchController.text = name;
      _isSearching = true;
    });

    final route = await _mapServices.fetchRoute(start, dest);
    if (mounted) {
      setState(() {
        _isSearching = false;
        _activeRoute = route;
        _currentStepIndex = 0;
      });
      if (route != null && route.steps.isNotEmpty) {
        final step = route.steps.first;
        ref.read(vehicleRepositoryProvider).sendTurn(
          dir: step.dir,
          distanceMeters: step.distanceMeters,
          street: step.street,
        );
      }
    }
  }

  int _testTurnIdx = 0;
  static const _testTurns = [
    ('L', 200, 'MG Road'),
    ('R', 1500, 'Anna Salai'),
    ('S', 80, 'Mount Road'),
    ('U', 50, 'Outer Ring Road'),
  ];

  void _sendTestTurnToEsp32() {
    HapticFeedback.lightImpact();
    final turn = _testTurns[_testTurnIdx % _testTurns.length];
    _testTurnIdx++;
    ref.read(vehicleRepositoryProvider).sendTurn(
      dir: turn.$1,
      distanceMeters: turn.$2,
      street: turn.$3,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Sent to ESP32: ${turn.$1}, ${turn.$2}m onto ${turn.$3}',
          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _advanceToNextTurn() {
    if (_activeRoute == null || _activeRoute!.steps.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentStepIndex = (_currentStepIndex + 1) % _activeRoute!.steps.length;
    });
    final step = _activeRoute!.steps[_currentStepIndex];
    ref.read(vehicleRepositoryProvider).sendTurn(
      dir: step.dir,
      distanceMeters: step.distanceMeters,
      street: step.street,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Sent to ESP32: ${step.dir}, ${step.distanceMeters}m onto ${step.street}',
          style: const TextStyle(color: AppColors.accent),
        ),
      ),
    );
  }

  Future<void> _toggleAmenity(String amenityType) async {
    HapticFeedback.lightImpact();
    if (_selectedAmenity == amenityType) {
      setState(() {
        _selectedAmenity = null;
        _activePois = [];
      });
      return;
    }

    setState(() {
      _selectedAmenity = amenityType;
    });

    final center = _mapController.camera.center;
    final pois = await _mapServices.fetchAmenities(
      center: center,
      amenityType: amenityType,
    );

    if (mounted) {
      setState(() {
        _activePois = pois;
      });
      if (pois.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            content: Text('No nearby locations found', style: TextStyle(color: AppColors.textSecondary)),
          ),
        );
      }
    }
  }

  void _recenterOnCar() {
    HapticFeedback.lightImpact();
    _mapController.move(_currentCarLocation, 16.0);
  }

  @override
  void dispose() {
    _staleCheckTimer?.cancel();
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(connectionStatusProvider);
    final gpsAsync = ref.watch(gpsProvider);
    final lastGps = ref.watch(lastGpsProvider);

    final isConnected = (statusAsync.valueOrNull ?? ConnectionStatus.idle) == ConnectionStatus.ready;

    // React to new GPS fix
    final fix = gpsAsync.valueOrNull ?? lastGps;
    if (fix != null && fix.timestamp != _lastGpsTimestamp) {
      _onGpsFixReceived(fix);
    }

    final isStale = !isConnected ||
        (_lastGpsTimestamp != null && _now.difference(_lastGpsTimestamp!).inSeconds > 30);

    // Build Markers
    final markers = <Marker>[];

    // 1. Phone marker
    if (_phoneLocationAvailable && _phoneLocation != null) {
      markers.add(
        Marker(
          point: _phoneLocation!,
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Car Marker (Neon Blue glowing dot with heading arrow)
    final carColor = isStale ? AppColors.textDisabled : AppColors.accent;
    markers.add(
      Marker(
        point: _currentCarLocation,
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!isStale)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 16,
                      spreadRadius: 4,
                    )
                  ],
                ),
              ),
            Transform.rotate(
              angle: _currentHeading * (3.14159265 / 180.0),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: carColor, width: 2.5),
                ),
                child: Center(
                  child: Icon(
                    Icons.navigation,
                    size: 15,
                    color: carColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 3. POI Markers
    for (final poi in _activePois) {
      markers.add(
        Marker(
          point: poi.location,
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  content: Text(poi.name, style: const TextStyle(color: AppColors.textPrimary)),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
              child: Icon(
                poi.amenityType == 'parking'
                    ? Icons.local_parking
                    : (poi.amenityType == 'fuel' ? Icons.local_gas_station : Icons.ev_station),
                size: 16,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      );
    }

    // 4. Destination Marker
    if (_activeRoute != null && _activeRoute!.points.isNotEmpty) {
      markers.add(
        Marker(
          point: _activeRoute!.points.last,
          width: 36,
          height: 36,
          child: const Icon(Icons.location_on, color: AppColors.danger, size: 36),
        ),
      );
    }

    // Polylines
    final polylines = <Polyline>[];
    if (_activeRoute != null) {
      polylines.add(
        Polyline(
          points: _activeRoute!.points,
          strokeWidth: 4.5,
          color: AppColors.accent,
          borderStrokeWidth: 2,
          borderColor: AppColors.primary,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ==========================================================
          // 1. FULLSCREEN MAP
          // ==========================================================
          _mapProvider.buildMap(
            context: context,
            initialCenter: _currentCarLocation,
            initialZoom: 15.5,
            mapController: _mapController,
            markers: markers,
            polylines: polylines,
            onTap: (_, point) {
              if (_showSearchResults) {
                setState(() => _showSearchResults = false);
                return;
              }
              FocusScope.of(context).unfocus();
              _routeToPoint(point);
            },
          ),

          // ==========================================================
          // 2. STALE CAR LOCATION CHIP
          // ==========================================================
          if (isStale)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, color: AppColors.warning, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _lastGpsTimestamp != null
                            ? 'Stale location: Last seen ${Formatters.timeAgo(_lastGpsTimestamp!)}'
                            : 'Vehicle offline – showing cached fix',
                        style: AppTypography.label.copyWith(color: AppColors.warning),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ==========================================================
          // 3. TOP SEARCH BAR (Glass)
          // ==========================================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassCard(
                    useRealBlur: true,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.search, color: AppColors.accent, size: 22),
                          onPressed: () => _onSearchSubmitted(_searchController.text),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: AppTypography.body,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search city, street or place...',
                              hintStyle: AppTypography.body.copyWith(color: AppColors.textDisabled),
                              border: InputBorder.none,
                            ),
                            onChanged: _onSearchChanged,
                            onSubmitted: _onSearchSubmitted,
                          ),
                        ),
                        if (_isSearching)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          )
                        else if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _showSearchResults = false;
                                _activeRoute = null;
                                _destinationName = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),

                  // Search Results Dropdown List
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, color: AppColors.accent, size: 18),
                            title: Text(
                              item.displayName,
                              style: AppTypography.body.copyWith(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ==========================================================
          // 4. ROUTE INFO & LIVE TURN BANNER (Sent to ESP32)
          // ==========================================================
          if (_activeRoute != null)
            Positioned(
              bottom: 84,
              left: 16,
              right: 16,
              child: Center(
                child: GlassCard(
                  useRealBlur: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _destinationName ?? 'Route',
                              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_activeRoute!.formattedDistance} • ${_activeRoute!.formattedDuration}',
                              style: AppTypography.label.copyWith(color: AppColors.accent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                            onPressed: () => setState(() => _activeRoute = null),
                          ),
                        ],
                      ),
                      if (_activeRoute!.steps.isNotEmpty && _currentStepIndex < _activeRoute!.steps.length) ...[
                        const Divider(color: AppColors.border, height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _activeRoute!.steps[_currentStepIndex].dir == 'L'
                                    ? Icons.turn_left
                                    : (_activeRoute!.steps[_currentStepIndex].dir == 'R'
                                        ? Icons.turn_right
                                        : (_activeRoute!.steps[_currentStepIndex].dir == 'U'
                                            ? Icons.u_turn_left
                                            : Icons.straight)),
                                color: AppColors.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_activeRoute!.steps[_currentStepIndex].dir == 'L' ? 'Turn Left' : (_activeRoute!.steps[_currentStepIndex].dir == 'R' ? 'Turn Right' : (_activeRoute!.steps[_currentStepIndex].dir == 'U' ? 'U-Turn' : 'Straight'))} in ${_activeRoute!.steps[_currentStepIndex].distanceMeters}m',
                                    style: AppTypography.label.copyWith(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'onto ${_activeRoute!.steps[_currentStepIndex].street}',
                                    style: AppTypography.label.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _advanceToNextTurn,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Next',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // ==========================================================
          // 5. BOTTOM FLOATING CHIPS ROW
          // ==========================================================
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                children: [
                  // My Car Re-center
                  _MapChip(
                    icon: Icons.my_location,
                    label: 'My Car',
                    isSelected: false,
                    onTap: _recenterOnCar,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Send Test Turn directly to ESP32
                  _MapChip(
                    icon: Icons.send_to_mobile,
                    label: 'Test Turn to ESP32',
                    isSelected: false,
                    onTap: _sendTestTurnToEsp32,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Parking
                  _MapChip(
                    icon: Icons.local_parking,
                    label: 'Parking',
                    isSelected: _selectedAmenity == 'parking',
                    onTap: () => _toggleAmenity('parking'),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Stations
                  _MapChip(
                    icon: Icons.local_gas_station,
                    label: 'Stations',
                    isSelected: _selectedAmenity == 'fuel',
                    onTap: () => _toggleAmenity('fuel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Chargers
                  _MapChip(
                    icon: Icons.ev_station,
                    label: 'Chargers',
                    isSelected: _selectedAmenity == 'charging_station',
                    onTap: () => _toggleAmenity('charging_station'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(color: AppColors.primaryGlow, blurRadius: 12),
                ]
              : const [
                  BoxShadow(color: Colors.black45, blurRadius: 4),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
