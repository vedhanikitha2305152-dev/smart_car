import '../models/telemetry.dart';
import '../models/gps_fix.dart';
import '../models/vehicle_command.dart';
import '../models/enums.dart';

abstract class VehicleRepository {
  Stream<ConnectionStatus> get connectionStatus;
  Stream<Telemetry> get telemetryStream;
  Stream<GpsFix> get gpsStream;
  Future<CommandResult> send(VehicleCommand command);
  Future<bool> sendTurn({required String dir, required int distanceMeters, required String street});
  Future<void> connect();
  Future<void> disconnect();
  void dispose();
}
