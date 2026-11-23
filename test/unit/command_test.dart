import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/data/models/enums.dart';
import 'package:smart_car/data/models/vehicle_command.dart';

void main() {
  group('VehicleCommand Unit Tests', () {
    test('lock command produces valid v1 JSON with trailing newline', () {
      final cmd = VehicleCommand.lock(42);
      final jsonStr = cmd.toJsonString();

      expect(jsonStr.endsWith('\n'), isTrue);

      final decoded = jsonDecode(jsonStr.trim()) as Map<String, dynamic>;
      expect(decoded['v'], 1);
      expect(decoded['seq'], 42);
      expect(decoded['cmd'], 'lock');
      expect(decoded['val'], true);
    });

    test('unlock command sets val to false', () {
      final cmd = VehicleCommand.unlock(43);
      final decoded = jsonDecode(cmd.toJsonString().trim()) as Map<String, dynamic>;
      expect(decoded['seq'], 43);
      expect(decoded['cmd'], 'lock');
      expect(decoded['val'], false);
    });

    test('drive mode command formats mode in uppercase string', () {
      final cmd = VehicleCommand.driveMode(44, DriveMode.sport);
      final decoded = jsonDecode(cmd.toJsonString().trim()) as Map<String, dynamic>;
      expect(decoded['seq'], 44);
      expect(decoded['cmd'], 'drive_mode');
      expect(decoded['val'], 'SPORT');
    });

    test('snapshot command has no val field', () {
      final cmd = VehicleCommand.snapshot(45);
      final decoded = jsonDecode(cmd.toJsonString().trim()) as Map<String, dynamic>;
      expect(decoded['seq'], 45);
      expect(decoded['cmd'], 'snapshot');
      expect(decoded.containsKey('val'), isFalse);
    });
  });
}
