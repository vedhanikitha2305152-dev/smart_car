import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import '../ble/ble_gatt_service.dart';
import '../models/enums.dart';
import '../models/gps_fix.dart';
import '../models/telemetry.dart';
import '../models/vehicle_command.dart';
import 'vehicle_repository.dart';

class BleVehicleRepository implements VehicleRepository {
  BleVehicleRepository({required this.gattService}) {
    _initEsp32Listeners();
  }

  final BleGattService gattService;
  static final _log = Logger('BleVehicleRepository');

  Telemetry _currentTelemetry = Telemetry.mock;
  final StreamController<Telemetry> _telemetryController =
      StreamController<Telemetry>.broadcast();

  StreamSubscription<int>? _fuelSub;
  StreamSubscription<double>? _battSub;
  StreamSubscription<String>? _rawSub;

  void _initEsp32Listeners() {
    // 1. ESP32 live fuel percentage updates (0-100%)
    _fuelSub = gattService.fuelStream.listen((fuelPercent) {
      final liters = (fuelPercent / 100.0) * _currentTelemetry.tankCapacity;
      _currentTelemetry = _currentTelemetry.copyWith(
        fuel: liters,
        range: (fuelPercent * 1.5).round(),
        alertCode: fuelPercent < 15 ? AlertCode.lowFuel : AlertCode.ok,
        timestamp: DateTime.now(),
      );
      if (!_telemetryController.isClosed) {
        _telemetryController.add(_currentTelemetry);
      }
    });

    // 2. ESP32 live battery voltage updates (e.g. 12.40 V)
    _battSub = gattService.batteryStream.listen((volts) {
      _currentTelemetry = _currentTelemetry.copyWith(
        batteryVoltage: volts,
        alertCode: volts < 11.8 ? AlertCode.critical : _currentTelemetry.alertCode,
        timestamp: DateTime.now(),
      );
      if (!_telemetryController.isClosed) {
        _telemetryController.add(_currentTelemetry);
      }
    });

    // 3. Optional fallback: JSON stream
    _rawSub = gattService.rawTelemetryStream.listen((line) {
      final parsed = _safeParseTelemetry(line);
      if (parsed != null) {
        _currentTelemetry = parsed;
        if (!_telemetryController.isClosed) {
          _telemetryController.add(_currentTelemetry);
        }
      }
    });
  }

  @override
  Stream<ConnectionStatus> get connectionStatus => gattService.connectionStatus;

  @override
  Stream<Telemetry> get telemetryStream => _telemetryController.stream;

  @override
  Stream<GpsFix> get gpsStream => gattService.rawGpsStream
      .map(_safeParseGps)
      .where((g) => g != null)
      .cast<GpsFix>();

  Telemetry? _safeParseTelemetry(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;

      // Schema check
      final version = json['v'];
      if (version == null) {
        _log.warning('Malformed telemetry packet: missing version "v"');
        return null;
      }
      if (version != 1) {
        _log.warning('Unknown telemetry protocol version: $version');
      }

      final cap = (json['cap'] as num?)?.toDouble() ?? 60.0;
      final rawFuel = (json['fuel'] as num?)?.toDouble();
      if (rawFuel == null) {
        _log.warning('Malformed telemetry packet: missing "fuel"');
        return null;
      }
      final clampedFuel = rawFuel.clamp(0.0, cap);

      final rawOil = (json['oil'] as num?)?.toInt() ?? 0;
      final clampedOil = rawOil.clamp(0, 100);

      final rawTpms = json['tpms'] as List<dynamic>? ?? [0.0, 0.0, 0.0, 0.0];
      final clampedTpms = rawTpms
          .map((e) => (e as num).toDouble().clamp(0.0, 80.0))
          .toList();

      final modeStr = json['mode'] as String? ?? 'COMFORT';
      final alertStr = json['alert'] as String? ?? 'OK';

      return Telemetry(
        version: (version as num).toInt(),
        fuel: clampedFuel,
        tankCapacity: cap,
        range: (json['range'] as num?)?.toInt() ?? 0,
        oilLife: clampedOil,
        odometer: (json['odo'] as num?)?.toInt() ?? 0,
        tpms: clampedTpms,
        locked: json['locked'] as bool? ?? true,
        driveMode: _parseDriveMode(modeStr),
        lightsOn: json['lights'] as bool? ?? false,
        alertCode: _parseAlertCode(alertStr),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          ((json['ts'] as num?)?.toInt() ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000)) * 1000,
        ),
      );
    } catch (e, st) {
      _log.warning('Telemetry parse error: $e\nRaw: "$line"\n$st');
      return null;
    }
  }

  GpsFix? _safeParseGps(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final version = json['v'] as int?;
      if (version == null) {
        _log.warning('Malformed GPS packet: missing version "v"');
        return null;
      }
      return GpsFix.fromJson(json);
    } catch (e, st) {
      _log.warning('GPS parse error: $e\nRaw: "$line"\n$st');
      return null;
    }
  }

  static DriveMode _parseDriveMode(String s) {
    switch (s.toUpperCase()) {
      case 'SPORT':
        return DriveMode.sport;
      case 'ECO':
        return DriveMode.eco;
      default:
        return DriveMode.comfort;
    }
  }

  static AlertCode _parseAlertCode(String s) {
    switch (s.toUpperCase()) {
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

  @override
  Future<CommandResult> send(VehicleCommand command) async {
    final payload = command.toJsonString();
    final bytes = utf8.encode(payload);
    _log.info('Sending command via BLE: $payload');

    final success = await gattService.writeControlCommand(bytes);
    return success ? CommandResult.success : CommandResult.failure;
  }

  @override
  Future<bool> sendTurn({
    required String dir,
    required int distanceMeters,
    required String street,
  }) async {
    return gattService.writeTurn(dir, distanceMeters, street);
  }

  @override
  Future<void> connect() async {
    await gattService.init();
    await gattService.startConnectionFlow();
  }

  @override
  Future<void> disconnect() async {
    await gattService.forgetDevice();
  }

  @override
  void dispose() {
    _fuelSub?.cancel();
    _battSub?.cancel();
    _rawSub?.cancel();
    _telemetryController.close();
    gattService.dispose();
  }
}
