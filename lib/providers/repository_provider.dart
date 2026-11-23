import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/ble/ble_gatt_service.dart';
import '../data/models/enums.dart';
import '../data/repositories/ble_vehicle_repository.dart';
import '../data/repositories/mock_vehicle_repository.dart';
import '../data/repositories/vehicle_repository.dart';

/// Provider for SharedPreferences instance. Overridden in main.dart with initialized instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

/// Mock mode toggle (default ON in debug builds, OFF in release)
final mockModeProvider = StateProvider<bool>((ref) => kDebugMode);

/// Selected mock scenario for demo & testing
final mockScenarioProvider =
    StateProvider<MockScenario>((ref) => MockScenario.normal);

/// Internal BleGattService singleton provider
final _bleGattServiceProvider = Provider<BleGattService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = BleGattService(prefs: prefs);
  ref.onDispose(service.dispose);
  return service;
});

/// Primary VehicleRepository provider — UI code only ever talks to this interface
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final isMock = ref.watch(mockModeProvider);
  final scenario = ref.watch(mockScenarioProvider);

  if (isMock) {
    final repo = MockVehicleRepository(scenario: scenario);
    ref.onDispose(repo.dispose);
    repo.connect();
    return repo;
  } else {
    final gattService = ref.watch(_bleGattServiceProvider);
    final repo = BleVehicleRepository(gattService: gattService);
    ref.onDispose(repo.dispose);
    repo.connect();
    return repo;
  }
});
