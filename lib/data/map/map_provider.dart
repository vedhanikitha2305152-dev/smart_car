import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Abstract interface for map rendering providers.
/// Allows swapping between flutter_map + CARTO, Google Maps, Mapbox, etc.
abstract class MapProvider {
  Widget buildMap({
    required BuildContext context,
    required LatLng initialCenter,
    required double initialZoom,
    required MapController mapController,
    required List<Marker> markers,
    required List<Polyline> polylines,
    void Function(TapPosition tapPosition, LatLng point)? onTap,
  });

  String get providerName;
  String get attribution;
}

/// Default implementation using flutter_map with OpenStreetMap tiles (100% free, no API key required)
class CartoDarkMapProvider implements MapProvider {
  const CartoDarkMapProvider();

  @override
  String get providerName => 'OpenStreetMap (flutter_map)';

  @override
  String get attribution => '© OpenStreetMap contributors';

  // Standard OpenStreetMap tiles - full actual map details with roads, labels, and landmarks
  static const String tileUrlPattern =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget buildMap({
    required BuildContext context,
    required LatLng initialCenter,
    required double initialZoom,
    required MapController mapController,
    required List<Marker> markers,
    required List<Polyline> polylines,
    void Function(TapPosition tapPosition, LatLng point)? onTap,
  }) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 3,
        maxZoom: 19,
        onTap: onTap,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrlPattern,
          userAgentPackageName: 'com.example.smart_car',
          maxZoom: 19,
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(attribution),
          ],
        ),
      ],
    );
  }
}
