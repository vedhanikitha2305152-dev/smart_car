import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../data/models/vehicle.dart';
import '../../providers/repository_provider.dart';

// STUB: Garage screen — local vehicle profile storage, no cloud sync
final activeVehicleProvider = StateProvider<Vehicle>((ref) {
  return Vehicle.defaultVehicle;
});

final garageVehiclesProvider = StateNotifierProvider<GarageNotifier, List<Vehicle>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GarageNotifier(prefs);
});

class GarageNotifier extends StateNotifier<List<Vehicle>> {
  GarageNotifier(this._prefs) : super(const [Vehicle.defaultVehicle]) {
    _load();
  }

  final dynamic _prefs;
  static const _key = 'garage_vehicles_json';

  void _load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => Vehicle(
                  id: e['id'] as String,
                  name: e['name'] as String,
                  bleDeviceId: e['bleDeviceId'] as String?,
                  tankCapacity: (e['tankCapacity'] as num?)?.toDouble() ?? 60.0,
                ))
            .toList();
        if (list.isNotEmpty) state = list;
      }
    } catch (_) {}
  }

  void addVehicle(String name, double tankCapacity) {
    final v = Vehicle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      tankCapacity: tankCapacity,
    );
    state = [...state, v];
    _save();
  }

  void removeVehicle(String id) {
    if (state.length <= 1) return; // Keep at least one
    state = state.where((v) => v.id != id).toList();
    _save();
  }

  void _save() {
    final jsonStr = jsonEncode(state
        .map((v) => {
              'id': v.id,
              'name': v.name,
              'bleDeviceId': v.bleDeviceId,
              'tankCapacity': v.tankCapacity,
            })
        .toList());
    _prefs.setString(_key, jsonStr);
  }
}

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  void _showAddVehicleDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '60');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Vehicle Profile', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: AppTypography.body,
              decoration: const InputDecoration(
                labelText: 'Vehicle Model Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: capCtrl,
              style: AppTypography.body,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tank Capacity (Liters)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final cap = double.tryParse(capCtrl.text) ?? 60.0;
              if (name.isNotEmpty) {
                ref.read(garageVehiclesProvider.notifier).addVehicle(name, cap);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(garageVehiclesProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Garage', style: AppTypography.title.copyWith(fontSize: 20)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'YOUR VEHICLES',
                style: AppTypography.label.copyWith(color: AppColors.accent, letterSpacing: 1.0),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Select a vehicle to activate telemetry profiling. Profiles are persisted locally.',
                style: AppTypography.label.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView.separated(
                  itemCount: vehicles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (ctx, i) {
                    final v = vehicles[i];
                    final isActive = v.id == activeVehicle.id;

                    return GlassCard(
                      useRealBlur: false,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(activeVehicleProvider.notifier).state = v;
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: isActive ? AppColors.accent : AppColors.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        v.name,
                                        style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isActive ? AppColors.accent : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tank Capacity: ${v.tankCapacity.toStringAsFixed(0)} L',
                                    style: AppTypography.label.copyWith(fontSize: 11, color: AppColors.textDisabled),
                                  ),
                                ],
                              ),
                            ),
                            if (vehicles.length > 1 && !isActive)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.textDisabled, size: 20),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(garageVehiclesProvider.notifier).removeVehicle(v.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              NeonButton(
                label: 'Add Vehicle',
                icon: Icons.add,
                onTap: () => _showAddVehicleDialog(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
