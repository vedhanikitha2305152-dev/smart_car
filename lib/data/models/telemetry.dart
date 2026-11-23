import 'enums.dart';

class Telemetry {
  const Telemetry({
    required this.version,
    required this.fuel,
    required this.tankCapacity,
    required this.range,
    required this.oilLife,
    required this.odometer,
    required this.tpms,
    required this.locked,
    required this.driveMode,
    required this.lightsOn,
    required this.alertCode,
    required this.timestamp,
    this.batteryVoltage = 12.4,
  });

  final int version;
  final double fuel;
  final double tankCapacity;
  final int range;
  final int oilLife;
  final int odometer;
  final List<double> tpms; // [FL, FR, RL, RR]
  final bool locked;
  final DriveMode driveMode;
  final bool lightsOn;
  final AlertCode alertCode;
  final DateTime timestamp;
  final double batteryVoltage;

  Telemetry copyWith({
    int? version,
    double? fuel,
    double? tankCapacity,
    int? range,
    int? oilLife,
    int? odometer,
    List<double>? tpms,
    bool? locked,
    DriveMode? driveMode,
    bool? lightsOn,
    AlertCode? alertCode,
    DateTime? timestamp,
    double? batteryVoltage,
  }) {
    return Telemetry(
      version: version ?? this.version,
      fuel: fuel ?? this.fuel,
      tankCapacity: tankCapacity ?? this.tankCapacity,
      range: range ?? this.range,
      oilLife: oilLife ?? this.oilLife,
      odometer: odometer ?? this.odometer,
      tpms: tpms ?? this.tpms,
      locked: locked ?? this.locked,
      driveMode: driveMode ?? this.driveMode,
      lightsOn: lightsOn ?? this.lightsOn,
      alertCode: alertCode ?? this.alertCode,
      timestamp: timestamp ?? this.timestamp,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
    );
  }

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    final cap = (json['cap'] as num).toDouble();
    final fuel = (json['fuel'] as num).toDouble().clamp(0.0, cap);
    return Telemetry(
      version: (json['v'] as num).toInt(),
      fuel: fuel,
      tankCapacity: cap,
      range: (json['range'] as num).toInt(),
      oilLife: (json['oil'] as num).toInt().clamp(0, 100),
      odometer: (json['odo'] as num).toInt(),
      tpms: (json['tpms'] as List<dynamic>)
          .map((e) => (e as num).toDouble().clamp(0.0, 80.0))
          .toList(),
      locked: json['locked'] as bool,
      driveMode: _parseMode(json['mode'] as String),
      lightsOn: json['lights'] as bool,
      alertCode: _parseAlert(json['alert'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((json['ts'] as num).toInt()) * 1000,
      ),
      batteryVoltage: (json['batt'] as num?)?.toDouble() ?? 12.4,
    );
  }

  static DriveMode _parseMode(String s) {
    switch (s.toUpperCase()) {
      case 'SPORT':
        return DriveMode.sport;
      case 'ECO':
        return DriveMode.eco;
      default:
        return DriveMode.comfort;
    }
  }

  static AlertCode _parseAlert(String s) {
    switch (s) {
      case 'LOW_FUEL':
        return AlertCode.lowFuel;
      case 'LOW_TIRE':
        return AlertCode.lowTire;
      case 'LOW_OIL':
        return AlertCode.lowOil;
      case 'DOOR_OPEN':
        return AlertCode.doorOpen;
      case 'CRITICAL':
        return AlertCode.critical;
      default:
        return AlertCode.ok;
    }
  }

  static Telemetry get mock => Telemetry(
        version: 1,
        fuel: 54.2,
        tankCapacity: 60,
        range: 62,
        oilLife: 83,
        odometer: 6721,
        tpms: const [37.2, 37.0, 29.1, 29.4],
        locked: true,
        driveMode: DriveMode.comfort,
        lightsOn: false,
        alertCode: AlertCode.ok,
        timestamp: DateTime.now(),
      );
}
