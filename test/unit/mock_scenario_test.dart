import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/data/models/enums.dart';
import 'package:smart_car/data/models/vehicle_command.dart';
import 'package:smart_car/data/repositories/mock_vehicle_repository.dart';

void main() {
  group('MockVehicleRepository Scenario Tests', () {
    test('Normal scenario connects and emits telemetry & GPS', () async {
      final repo = MockVehicleRepository(scenario: MockScenario.normal);
      addTearDown(repo.dispose);

      final statusFuture = repo.connectionStatus.firstWhere((s) => s == ConnectionStatus.ready);
      final telemFuture = repo.telemetryStream.first;

      await repo.connect();

      final status = await statusFuture.timeout(const Duration(seconds: 2));
      expect(status, ConnectionStatus.ready);

      final telem = await telemFuture.timeout(const Duration(seconds: 2));
      expect(telem.fuel, greaterThan(0));
      expect(telem.tpms.length, 4);
      expect(telem.alertCode, AlertCode.ok);
    });

    test('Low fuel scenario starts with low fuel and LOW_FUEL alert', () async {
      final repo = MockVehicleRepository(scenario: MockScenario.lowFuel);
      addTearDown(repo.dispose);

      await repo.connect();
      final telem = await repo.telemetryStream.first.timeout(const Duration(seconds: 2));

      expect(telem.fuel, lessThan(10.0));
      expect(telem.alertCode, AlertCode.lowFuel);
    });

    test('Command failure scenario times out commands after 3 seconds', () async {
      final repo = MockVehicleRepository(scenario: MockScenario.commandFailure);
      addTearDown(repo.dispose);

      await repo.connect();
      final cmd = VehicleCommand.lock(1);
      final result = await repo.send(cmd);

      expect(result, CommandResult.timeout);
    });

    test('Normal command execution modifies state and emits updated telemetry', () async {
      final repo = MockVehicleRepository(scenario: MockScenario.normal);
      addTearDown(repo.dispose);

      await repo.connect();

      // Send unlock
      final unlockResult = await repo.send(VehicleCommand.unlock(2));
      expect(unlockResult, CommandResult.success);

      final telem = await repo.telemetryStream.first.timeout(const Duration(seconds: 2));
      expect(telem.locked, isFalse);

      // Send drive mode SPORT
      final sportResult = await repo.send(VehicleCommand.driveMode(3, DriveMode.sport));
      expect(sportResult, CommandResult.success);
    });
  });
}
