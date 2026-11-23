import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/enums.dart';
import '../../providers/repository_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMock = ref.watch(mockModeProvider);
    final scenario = ref.watch(mockScenarioProvider);
    final pressureUnit = ref.watch(pressureUnitProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);
    final fuelUnit = ref.watch(fuelUnitProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.title.copyWith(fontSize: 20)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // ==========================================================
          // 1. DATA SOURCE & MOCK MODE
          // ==========================================================
          const _SectionHeader(title: 'DATA SOURCE'),
          GlassCard(
            useRealBlur: false,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mock Mode (Simulated Data)', style: AppTypography.body),
                  subtitle: Text(
                    'Emits telemetry drift, GPS loops & scenarios',
                    style: AppTypography.label.copyWith(color: AppColors.textDisabled),
                  ),
                  activeColor: AppColors.accent,
                  value: isMock,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    ref.read(mockModeProvider.notifier).state = val;
                  },
                ),
                if (isMock) ...[
                  const Divider(color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mock Scenario', style: AppTypography.body),
                      DropdownButton<MockScenario>(
                        dropdownColor: AppColors.surfaceHigh,
                        value: scenario,
                        underline: const SizedBox(),
                        style: AppTypography.body.copyWith(color: AppColors.accent),
                        items: MockScenario.values.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(_scenarioLabel(s)),
                          );
                        }).toList(),
                        onChanged: (s) {
                          if (s != null) {
                            HapticFeedback.lightImpact();
                            ref.read(mockScenarioProvider.notifier).state = s;
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ==========================================================
          // 2. UNITS
          // ==========================================================
          const _SectionHeader(title: 'PREFERENCES & UNITS'),
          GlassCard(
            useRealBlur: false,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              children: [
                // Tire Pressure Unit
                _UnitRow<PressureUnit>(
                  label: 'Tire Pressure',
                  value: pressureUnit,
                  items: PressureUnit.values,
                  itemLabel: (u) => u.name.toUpperCase(),
                  onChanged: (u) => ref.read(pressureUnitProvider.notifier).state = u,
                ),
                const Divider(color: AppColors.border),
                // Distance Unit
                _UnitRow<DistanceUnit>(
                  label: 'Distance & Speed',
                  value: distanceUnit,
                  items: DistanceUnit.values,
                  itemLabel: (u) => u == DistanceUnit.km ? 'Kilometers (km)' : 'Miles (mi)',
                  onChanged: (u) => ref.read(distanceUnitProvider.notifier).state = u,
                ),
                const Divider(color: AppColors.border),
                // Fuel Unit
                _UnitRow<FuelUnit>(
                  label: 'Fuel Volume',
                  value: fuelUnit,
                  items: FuelUnit.values,
                  itemLabel: (u) => u == FuelUnit.liters ? 'Liters (L)' : 'Gallons (gal)',
                  onChanged: (u) => ref.read(fuelUnitProvider.notifier).state = u,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ==========================================================
          // 3. HARDWARE & BLUETOOTH
          // ==========================================================
          const _SectionHeader(title: 'BLUETOOTH HARDWARE'),
          GlassCard(
            useRealBlur: false,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bluetooth_disabled, color: AppColors.danger),
                  title: const Text('Forget Saved Vehicle BLE Device', style: TextStyle(color: AppColors.danger)),
                  subtitle: Text(
                    'Clears paired MAC address and forces scan next time',
                    style: AppTypography.label.copyWith(color: AppColors.textDisabled),
                  ),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await ref.read(vehicleRepositoryProvider).disconnect();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.surfaceHigh,
                        content: Text('Saved vehicle device forgotten.'),
                      ),
                    );
                  },
                ),
                const Divider(color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('BLE Framing MTU Target', style: AppTypography.body),
                    Text('247 bytes', style: AppTypography.label.copyWith(color: AppColors.accent)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ==========================================================
          // 4. ABOUT & LICENSES
          // ==========================================================
          const _SectionHeader(title: 'ABOUT'),
          const GlassCard(
            useRealBlur: false,
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Smart Car Luxury Dark Companion', style: AppTypography.body),
                  subtitle: Text('v1.0.0 (Build 2026.11)', style: AppTypography.label),
                  trailing: Icon(Icons.info_outline, color: AppColors.textSecondary),
                ),
                Divider(color: AppColors.border),
                _LicenseTile(),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _scenarioLabel(MockScenario s) {
    switch (s) {
      case MockScenario.normal:
        return 'Normal Driving';
      case MockScenario.slowTireLeak:
        return 'Slow Tire Leak (RR)';
      case MockScenario.lowFuel:
        return 'Low Fuel Alert';
      case MockScenario.connectionDrops:
        return 'Connection Drops (20s)';
      case MockScenario.commandFailure:
        return 'Command Timeout (3s)';
      case MockScenario.staleData:
        return 'Stale Data (Stop emitting)';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          letterSpacing: 1.0,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _LicenseTile extends StatelessWidget {
  const _LicenseTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Open Source Licenses', style: AppTypography.body),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () {
        HapticFeedback.lightImpact();
        showLicensePage(
          context: context,
          applicationName: 'Smart Car',
          applicationVersion: '1.0.0',
        );
      },
    );
  }
}

class _UnitRow<T> extends StatelessWidget {
  const _UnitRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body),
        DropdownButton<T>(
          dropdownColor: AppColors.surfaceHigh,
          value: value,
          underline: const SizedBox(),
          style: AppTypography.body.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              HapticFeedback.lightImpact();
              onChanged(v);
            }
          },
        ),
      ],
    );
  }
}
