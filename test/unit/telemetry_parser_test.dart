import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/data/models/enums.dart';
import 'package:smart_car/data/models/telemetry.dart';

void main() {
  group('Telemetry Model & Schema Validation Tests', () {
    final validJson = <String, dynamic>{
      'v': 1,
      'fuel': 54.2,
      'cap': 60,
      'range': 62,
      'oil': 83,
      'odo': 6721,
      'tpms': [37.2, 37.0, 29.1, 29.4],
      'locked': true,
      'mode': 'COMFORT',
      'lights': false,
      'alert': 'OK',
      'ts': 1731900000,
    };

    test('parses nominal valid telemetry packet', () {
      final t = Telemetry.fromJson(validJson);
      expect(t.version, 1);
      expect(t.fuel, 54.2);
      expect(t.tankCapacity, 60.0);
      expect(t.range, 62);
      expect(t.oilLife, 83);
      expect(t.odometer, 6721);
      expect(t.tpms, [37.2, 37.0, 29.1, 29.4]);
      expect(t.locked, isTrue);
      expect(t.driveMode, DriveMode.comfort);
      expect(t.lightsOn, isFalse);
      expect(t.alertCode, AlertCode.ok);
    });

    test('clamps fuel value to tankCapacity when out of bounds', () {
      final json = Map<String, dynamic>.from(validJson)..['fuel'] = 95.0;
      final t = Telemetry.fromJson(json);
      expect(t.fuel, 60.0); // clamped to cap
    });

    test('clamps oil life to 0-100 percentage range', () {
      final overJson = Map<String, dynamic>.from(validJson)..['oil'] = 140;
      final underJson = Map<String, dynamic>.from(validJson)..['oil'] = -10;

      expect(Telemetry.fromJson(overJson).oilLife, 100);
      expect(Telemetry.fromJson(underJson).oilLife, 0);
    });

    test('clamps TPMS values to 0.0 - 80.0 range', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['tpms'] = [120.0, -12.0, 32.0, 35.0];
      final t = Telemetry.fromJson(json);
      expect(t.tpms[0], 80.0);
      expect(t.tpms[1], 0.0);
    });

    test('correctly maps DriveMode enums', () {
      final sport = Map<String, dynamic>.from(validJson)..['mode'] = 'SPORT';
      final eco = Map<String, dynamic>.from(validJson)..['mode'] = 'ECO';
      final unknown = Map<String, dynamic>.from(validJson)..['mode'] = 'HYPER';

      expect(Telemetry.fromJson(sport).driveMode, DriveMode.sport);
      expect(Telemetry.fromJson(eco).driveMode, DriveMode.eco);
      expect(Telemetry.fromJson(unknown).driveMode, DriveMode.comfort);
    });

    test('correctly maps AlertCode enums', () {
      final lowFuel = Map<String, dynamic>.from(validJson)..['alert'] = 'LOW_FUEL';
      final lowTire = Map<String, dynamic>.from(validJson)..['alert'] = 'LOW_TIRE';
      final critical = Map<String, dynamic>.from(validJson)..['alert'] = 'CRITICAL';

      expect(Telemetry.fromJson(lowFuel).alertCode, AlertCode.lowFuel);
      expect(Telemetry.fromJson(lowTire).alertCode, AlertCode.lowTire);
      expect(Telemetry.fromJson(critical).alertCode, AlertCode.critical);
    });
  });
}
