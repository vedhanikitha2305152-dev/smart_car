import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';

import '../models/enums.dart';
import '../models/gps_fix.dart';
import '../models/telemetry.dart';
import '../models/vehicle_command.dart';
import 'vehicle_repository.dart';

class MockVehicleRepository implements VehicleRepository {
  MockVehicleRepository({this.scenario = MockScenario.normal});

  MockScenario scenario;

  final _log = Logger('MockVehicleRepository');
  final _connCtrl = StreamController<ConnectionStatus>.broadcast();
  final _telemCtrl = StreamController<Telemetry>.broadcast();
  final _gpsCtrl = StreamController<GpsFix>.broadcast();

  Timer? _telemTimer;
  Timer? _gpsTimer;
  Timer? _dropTimer;
  Timer? _staleTimer;

  // Mutable mock state
  double _fuel = 54.2;
  final int _oil = 83;
  int _odo = 6721;
  List<double> _tpms = [37.2, 37.0, 29.1, 29.4];
  bool _locked = true;
  DriveMode _mode = DriveMode.comfort;
  bool _lights = false;
  AlertCode _alert = AlertCode.ok;
  int _tick = 0;
  bool _stale = false;

  // GPS loop — Madrid mini-loop
  static const _gpsLoop = [
    [40.4168, -3.7038],
    [40.4178, -3.7020],
    [40.4190, -3.7010],
    [40.4185, -3.7025],
    [40.4170, -3.7045],
  ];
  int _gpsIdx = 0;
  double _lat = 40.4168;
  double _lng = -3.7038;
  double _heading = 90;

  final _rng = Random();

  @override
  Stream<ConnectionStatus> get connectionStatus => _connCtrl.stream;

  @override
  Stream<Telemetry> get telemetryStream => _telemCtrl.stream;

  @override
  Stream<GpsFix> get gpsStream => _gpsCtrl.stream;

  @override
  Future<void> connect() async {
    _log.info('Mock connecting...');
    _connCtrl.add(ConnectionStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _connCtrl.add(ConnectionStatus.ready);
    _startStreams();
  }

  @override
  Future<void> disconnect() async {
    _stopAll();
    _connCtrl.add(ConnectionStatus.idle);
  }

  void _startStreams() {
    _stopAll();
    _applyScenario();

    _telemTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stale) return;
      _tick++;
      _drift();
      _telemCtrl.add(_buildTelemetry());
    });

    _gpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stale) return;
      _moveGps();
      _gpsCtrl.add(_buildGps());
    });
  }

  void _applyScenario() {
    switch (scenario) {
      case MockScenario.lowFuel:
        _fuel = 4.5;
        _alert = AlertCode.lowFuel;
        break;
      case MockScenario.connectionDrops:
        _dropTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
          _connCtrl.add(ConnectionStatus.reconnecting);
          _telemTimer?.cancel();
          _gpsTimer?.cancel();
          await Future<void>.delayed(const Duration(seconds: 3));
          _connCtrl.add(ConnectionStatus.ready);
          _startStreams();
        });
        break;
      case MockScenario.staleData:
        _staleTimer = Timer(const Duration(seconds: 5), () {
          _stale = true;
          _log.info('Mock: stale data scenario — stopped emitting');
        });
        break;
      case MockScenario.normal:
      case MockScenario.slowTireLeak:
      case MockScenario.commandFailure:
        break;
    }
  }

  void _drift() {
    _fuel = max(0, _fuel - 0.002);
    _odo++;

    _tpms = _tpms
        .map((p) => (p + (_rng.nextDouble() - 0.5) * 0.2).clamp(0.0, 80.0))
        .toList();

    if (scenario == MockScenario.slowTireLeak) {
      final drop = _tick * (25.0 / 60.0);
      _tpms[3] = max(4.0, 29.4 - drop);
      if (_tpms[3] < 25) _alert = AlertCode.lowTire;
    }

    if (scenario != MockScenario.slowTireLeak) {
      if (_fuel / 60 < 0.08) {
        _alert = AlertCode.lowFuel;
      } else if (_fuel / 60 < 0.15) {
        _alert = AlertCode.lowFuel;
      } else {
        _alert = AlertCode.ok;
      }
    }
  }

  void _moveGps() {
    _gpsIdx = (_gpsIdx + 1) % _gpsLoop.length;
    _lat = _gpsLoop[_gpsIdx][0] + (_rng.nextDouble() - 0.5) * 0.00005;
    _lng = _gpsLoop[_gpsIdx][1] + (_rng.nextDouble() - 0.5) * 0.00005;
    _heading = (_heading + 5) % 360;
  }

  Telemetry _buildTelemetry() => Telemetry(
        version: 1,
        fuel: _fuel,
        tankCapacity: 60,
        range: (_fuel * 10).toInt(),
        oilLife: _oil,
        odometer: _odo,
        tpms: List<double>.from(_tpms),
        locked: _locked,
        driveMode: _mode,
        lightsOn: _lights,
        alertCode: _alert,
        timestamp: DateTime.now(),
      );

  GpsFix _buildGps() => GpsFix(
        version: 1,
        lat: _lat,
        lng: _lng,
        speed: 0,
        heading: _heading,
        timestamp: DateTime.now(),
      );

  @override
  Future<CommandResult> send(VehicleCommand command) async {
    _log.info('Mock command: ${command.cmd} val=${command.val}');

    if (scenario == MockScenario.commandFailure) {
      await Future<void>.delayed(const Duration(seconds: 3));
      return CommandResult.timeout;
    }

    final delayMs = 300 + _rng.nextInt(500);
    await Future<void>.delayed(Duration(milliseconds: delayMs));

    switch (command.cmd) {
      case 'lock':
        _locked = command.val as bool;
        break;
      case 'drive_mode':
        _mode = DriveMode.values.firstWhere(
          (m) => m.name.toUpperCase() == (command.val as String),
          orElse: () => DriveMode.comfort,
        );
        break;
      case 'lights':
        _lights = command.val as bool;
        break;
      case 'snapshot':
        // emit immediately
        break;
    }
    _telemCtrl.add(_buildTelemetry());
    return CommandResult.success;
  }

  @override
  Future<bool> sendTurn({
    required String dir,
    required int distanceMeters,
    required String street,
  }) async {
    _log.info('Mock sending turn: $dir,$distanceMeters,$street');
    return true;
  }

  void _stopAll() {
    _telemTimer?.cancel();
    _gpsTimer?.cancel();
    _dropTimer?.cancel();
    _staleTimer?.cancel();
    _stale = false;
    _tick = 0;
  }

  @override
  void dispose() {
    _stopAll();
    _connCtrl.close();
    _telemCtrl.close();
    _gpsCtrl.close();
  }
}
