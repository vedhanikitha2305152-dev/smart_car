import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/formatters.dart';
import '../data/models/enums.dart';

final pressureUnitProvider =
    StateProvider<PressureUnit>((ref) => PressureUnit.psi);

final distanceUnitProvider =
    StateProvider<DistanceUnit>((ref) => DistanceUnit.km);

final fuelUnitProvider = StateProvider<FuelUnit>((ref) => FuelUnit.liters);
