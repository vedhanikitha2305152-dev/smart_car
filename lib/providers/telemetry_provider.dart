import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/enums.dart';
import '../data/models/telemetry.dart';
import 'repository_provider.dart';

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final repo = ref.watch(vehicleRepositoryProvider);
  return repo.connectionStatus;
});

final telemetryProvider = StreamProvider<Telemetry>((ref) {
  final repo = ref.watch(vehicleRepositoryProvider);
  return repo.telemetryStream;
});

final lastTelemetryProvider = Provider<Telemetry?>((ref) =>
    ref.watch(telemetryProvider).valueOrNull);
