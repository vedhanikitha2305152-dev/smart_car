import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/gps_fix.dart';
import 'repository_provider.dart';

final gpsProvider = StreamProvider<GpsFix>((ref) {
  final repo = ref.watch(vehicleRepositoryProvider);
  return repo.gpsStream;
});

final lastGpsProvider =
    Provider<GpsFix?>((ref) => ref.watch(gpsProvider).valueOrNull);
