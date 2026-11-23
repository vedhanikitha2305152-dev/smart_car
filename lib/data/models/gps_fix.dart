class GpsFix {
  const GpsFix({
    required this.version,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.timestamp,
  });

  final int version;
  final double lat;
  final double lng;
  final double speed;
  final double heading;
  final DateTime timestamp;

  factory GpsFix.fromJson(Map<String, dynamic> json) => GpsFix(
        version: (json['v'] as num).toInt(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
        heading: (json['heading'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          ((json['ts'] as num).toInt()) * 1000,
        ),
      );

  factory GpsFix.mock() => GpsFix(
        version: 1,
        lat: 40.4168,
        lng: -3.7038,
        speed: 0,
        heading: 90,
        timestamp: DateTime.now(),
      );
}
