import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import 'ble_uuids.dart';
import 'packet_framer.dart';

/// Full-featured BLE GATT Service managing lifecycle, framing, backoff, and state machine.
class BleGattService {
  BleGattService({SharedPreferences? prefs}) : _prefs = prefs;

  static final _log = Logger('BleGattService');
  static const String prefKeySavedDeviceId = 'saved_ble_device_id';
  static const int maxGatt133Retries = 3;
  static const List<int> backoffSeconds = [1, 2, 4, 8, 16];

  SharedPreferences? _prefs;

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<String> _telemetryLineController =
      StreamController<String>.broadcast();
  final StreamController<String> _gpsLineController =
      StreamController<String>.broadcast();
  final StreamController<int> _fuelStreamController =
      StreamController<int>.broadcast();
  final StreamController<double> _batteryStreamController =
      StreamController<double>.broadcast();

  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;
  Stream<String> get rawTelemetryStream => _telemetryLineController.stream;
  Stream<String> get rawGpsStream => _gpsLineController.stream;
  Stream<int> get fuelStream => _fuelStreamController.stream;
  Stream<double> get batteryStream => _batteryStreamController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.idle;
  ConnectionStatus get currentStatus => _currentStatus;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _controlCharacteristic;
  BluetoothCharacteristic? _telemetryCharacteristic;
  BluetoothCharacteristic? _gpsCharacteristic;
  BluetoothCharacteristic? _fuelCharacteristic;
  BluetoothCharacteristic? _battCharacteristic;
  BluetoothCharacteristic? _turnCharacteristic;

  final PacketFramer _telemetryFramer = PacketFramer();
  final PacketFramer _gpsFramer = PacketFramer();

  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSubscription;
  StreamSubscription<List<int>>? _telemetrySubscription;
  StreamSubscription<List<int>>? _gpsSubscription;
  StreamSubscription<List<int>>? _fuelSubscription;
  StreamSubscription<List<int>>? _battSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  int _gatt133ErrorCount = 0;
  bool _shouldAutoReconnect = true;
  int _negotiatedMtu = 23;
  int get negotiatedMtu => _negotiatedMtu;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Listen to adapter state (Bluetooth on/off)
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        _log.warning('Bluetooth adapter turned off ($state)');
        _emitStatus(ConnectionStatus.bluetoothOff);
      } else if (_currentStatus == ConnectionStatus.bluetoothOff) {
        _emitStatus(ConnectionStatus.idle);
        if (_shouldAutoReconnect) {
          startConnectionFlow();
        }
      }
    });
  }

  void _emitStatus(ConnectionStatus status) {
    _currentStatus = status;
    _log.info('BLE Status: $status');
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Entry point: checks saved device or starts 10-second scan
  Future<void> startConnectionFlow() async {
    _shouldAutoReconnect = true;
    _reconnectTimer?.cancel();

    // Verify adapter is on
    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) {
      _emitStatus(ConnectionStatus.bluetoothOff);
      return;
    }

    final savedId = _prefs?.getString(prefKeySavedDeviceId);
    if (savedId != null && savedId.isNotEmpty) {
      _log.info('Connecting directly to saved device ID: $savedId');
      final device = BluetoothDevice.fromId(savedId);
      await _connectToDevice(device);
    } else {
      await startScan();
    }
  }

  /// Scan for Natchathira / RP5_CAR_DASHBOARD / Service UUID for up to 10 seconds
  Future<void> startScan() async {
    _emitStatus(ConnectionStatus.scanning);
    _log.info('Starting 10-second BLE scan for device: ${BleUuids.deviceName}');

    StreamSubscription<List<ScanResult>>? scanSubscription;
    final completer = Completer<BluetoothDevice?>();

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final matchesUuid = result.advertisementData.serviceUuids.any((uuid) {
          final u = uuid.toString().toLowerCase();
          return u == BleUuids.vehServiceUuid ||
              u == BleUuids.navServiceUuid ||
              u == BleUuids.serviceUuid;
        });
        final devName = (result.device.advName.isNotEmpty
                ? result.device.advName
                : result.advertisementData.advName)
            .toLowerCase();
        final matchesName = devName.contains(BleUuids.deviceName.toLowerCase()) ||
            devName.contains('rp5_car_dashboard');

        if (matchesUuid || matchesName) {
          _log.info('Found candidate vehicle peripheral: ${result.device.remoteId} ($devName)');
          if (!completer.isCompleted) {
            completer.complete(result.device);
          }
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      // Wait until scan finishes or device found
      final foundDevice = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      await FlutterBluePlus.stopScan();
      await scanSubscription.cancel();

      if (foundDevice != null) {
        await _connectToDevice(foundDevice);
      } else {
        _log.warning('No matching vehicle device found within scan timeout');
        _emitStatus(ConnectionStatus.failed);
      }
    } catch (e, st) {
      _log.severe('Scan failed: $e\n$st');
      await scanSubscription.cancel();
      _emitStatus(ConnectionStatus.failed);
    }
  }

  Future<void> connectSelectedDevice(BluetoothDevice device) async {
    _shouldAutoReconnect = true;
    await _connectToDevice(device);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _connectedDevice = device;
    _emitStatus(ConnectionStatus.connecting);

    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      _log.warning('Connect exception: $e');
      final errorStr = e.toString();
      // Handle Android GATT Error 133
      if (errorStr.contains('133') && _gatt133ErrorCount < maxGatt133Retries) {
        _gatt133ErrorCount++;
        _log.warning('Encountered GATT Error 133 (attempt $_gatt133ErrorCount). Backing off 500ms...');
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
        return _connectToDevice(device);
      }

      _emitStatus(ConnectionStatus.failed);
      _scheduleReconnect();
      return;
    }

    _gatt133ErrorCount = 0;

    // Monitor connection drops
    _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _log.warning('Vehicle disconnected from BLE');
        _cleanupSubscriptions();
        if (_shouldAutoReconnect) {
          _emitStatus(ConnectionStatus.reconnecting);
          _scheduleReconnect();
        } else {
          _emitStatus(ConnectionStatus.idle);
        }
      }
    });

    await _discoverServicesAndSetup(device);
  }

  Future<void> _discoverServicesAndSetup(BluetoothDevice device) async {
    _emitStatus(ConnectionStatus.discoveringServices);

    try {
      final services = await device.discoverServices();
      _log.info('Discovered ${services.length} services on ${device.remoteId}');

      // MTU Negotiation
      _emitStatus(ConnectionStatus.negotiating);
      try {
        _negotiatedMtu = await device.requestMtu(247).timeout(
              const Duration(seconds: 4),
              onTimeout: () => 23,
            );
        _log.info('Negotiated MTU: $_negotiatedMtu');
      } catch (e) {
        _log.warning('MTU request threw: $e, using default 23');
        _negotiatedMtu = 23;
      }

      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toString().toLowerCase();

          // ESP32 "Natchathira" characteristics
          if (uuid == BleUuids.fuelCharUuid.toLowerCase()) {
            _fuelCharacteristic = characteristic;
            _log.info('Found ESP32 Fuel Characteristic');
          } else if (uuid == BleUuids.battCharUuid.toLowerCase()) {
            _battCharacteristic = characteristic;
            _log.info('Found ESP32 Battery Characteristic');
          } else if (uuid == BleUuids.turnCharUuid.toLowerCase()) {
            _turnCharacteristic = characteristic;
            _log.info('Found ESP32 Turn Characteristic');
          }

          // Legacy / Generic characteristics
          if (uuid == BleUuids.telemetryUuid.toLowerCase()) {
            _telemetryCharacteristic = characteristic;
          } else if (uuid == BleUuids.controlUuid.toLowerCase()) {
            _controlCharacteristic = characteristic;
          } else if (uuid == BleUuids.gpsUuid.toLowerCase()) {
            _gpsCharacteristic = characteristic;
          }
        }
      }

      // 1. Subscribe to ESP32 Fuel notifications
      if (_fuelCharacteristic != null) {
        await _fuelCharacteristic!.setNotifyValue(true);
        _fuelSubscription?.cancel();
        _fuelSubscription = _fuelCharacteristic!.lastValueStream.listen((bytes) {
          if (bytes.isNotEmpty) {
            final val = bytes[0].clamp(0, 100);
            if (!_fuelStreamController.isClosed) {
              _fuelStreamController.add(val);
            }
          }
        });
        // Initial read
        try {
          final initFuel = await _fuelCharacteristic!.read();
          if (initFuel.isNotEmpty && !_fuelStreamController.isClosed) {
            _fuelStreamController.add(initFuel[0].clamp(0, 100));
          }
        } catch (_) {}
      }

      // 2. Subscribe to ESP32 Battery notifications
      if (_battCharacteristic != null) {
        await _battCharacteristic!.setNotifyValue(true);
        _battSubscription?.cancel();
        _battSubscription = _battCharacteristic!.lastValueStream.listen((bytes) {
          if (bytes.length >= 2) {
            final raw = bytes[0] | (bytes[1] << 8); // uint16 little-endian
            final volts = raw / 100.0;
            if (!_batteryStreamController.isClosed) {
              _batteryStreamController.add(volts);
            }
          }
        });
        // Initial read
        try {
          final initBatt = await _battCharacteristic!.read();
          if (initBatt.length >= 2 && !_batteryStreamController.isClosed) {
            final raw = initBatt[0] | (initBatt[1] << 8);
            _batteryStreamController.add(raw / 100.0);
          }
        } catch (_) {}
      }

      // 3. Subscribe to Telemetry notifications (legacy)
      if (_telemetryCharacteristic != null && _telemetryCharacteristic != _fuelCharacteristic) {
        await _telemetryCharacteristic!.setNotifyValue(true);
        _telemetrySubscription?.cancel();
        _telemetrySubscription =
            _telemetryCharacteristic!.lastValueStream.listen((bytes) {
          final lines = _telemetryFramer.feed(bytes);
          for (final line in lines) {
            if (!_telemetryLineController.isClosed) {
              _telemetryLineController.add(line);
            }
          }
        });
      }

      // 4. Subscribe to GPS notifications (legacy)
      if (_gpsCharacteristic != null) {
        await _gpsCharacteristic!.setNotifyValue(true);
        _gpsSubscription?.cancel();
        _gpsSubscription = _gpsCharacteristic!.lastValueStream.listen((bytes) {
          final lines = _gpsFramer.feed(bytes);
          for (final line in lines) {
            if (!_gpsLineController.isClosed) {
              _gpsLineController.add(line);
            }
          }
        });
      }

      // Trigger bonding state
      _emitStatus(ConnectionStatus.bonding);
      await Future.delayed(const Duration(milliseconds: 500));

      // Persist connected device ID
      await _prefs?.setString(prefKeySavedDeviceId, device.remoteId.str);

      _reconnectAttempts = 0;
      _emitStatus(ConnectionStatus.ready);
      _log.info('BLE GATT pipeline fully initialized and ready');
    } catch (e, st) {
      _log.severe('Error discovering services: $e\n$st');
      _emitStatus(ConnectionStatus.failed);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldAutoReconnect) return;
    _reconnectTimer?.cancel();

    final delaySeconds = _reconnectAttempts < backoffSeconds.length
        ? backoffSeconds[_reconnectAttempts]
        : 30;
    _reconnectAttempts++;

    _log.info('Scheduling reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldAutoReconnect && _connectedDevice != null) {
        _connectToDevice(_connectedDevice!);
      } else if (_shouldAutoReconnect) {
        startConnectionFlow();
      }
    });
  }

  /// Write turn instruction to ESP32: "DIR,DIST_M,STREET" (e.g. "L,200,MG Road")
  Future<bool> writeTurn(String dir, int distMeters, String street) async {
    final targetChar = _turnCharacteristic ?? _controlCharacteristic;
    if (targetChar == null) {
      _log.warning('Cannot write turn: Turn characteristic not discovered');
      return false;
    }
    try {
      final payload = '$dir,$distMeters,$street';
      final bytes = utf8.encode(payload);
      _log.info('Sending navigation turn to ESP32: $payload');
      await targetChar.write(bytes, withoutResponse: false);
      return true;
    } catch (e) {
      _log.warning('Turn characteristic write failed: $e');
      return false;
    }
  }

  Future<bool> writeControlCommand(List<int> bytes) async {
    final target = _controlCharacteristic ?? _turnCharacteristic;
    if (target == null) {
      _log.warning('Cannot write: Control characteristic not discovered');
      return false;
    }
    try {
      await target.write(bytes, withoutResponse: false);
      return true;
    } catch (e) {
      _log.warning('Control characteristic write failed: $e');
      return false;
    }
  }

  Future<void> forgetDevice() async {
    _shouldAutoReconnect = false;
    _reconnectTimer?.cancel();
    await _prefs?.remove(prefKeySavedDeviceId);
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _cleanupSubscriptions();
    _emitStatus(ConnectionStatus.idle);
  }

  void _cleanupSubscriptions() {
    _telemetrySubscription?.cancel();
    _gpsSubscription?.cancel();
    _fuelSubscription?.cancel();
    _battSubscription?.cancel();
    _telemetryFramer.reset();
    _gpsFramer.reset();
  }

  void dispose() {
    _shouldAutoReconnect = false;
    _reconnectTimer?.cancel();
    _adapterStateSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
    _cleanupSubscriptions();
    _connectedDevice?.disconnect();
    _statusController.close();
    _telemetryLineController.close();
    _gpsLineController.close();
    _fuelStreamController.close();
    _batteryStreamController.close();
  }
}
