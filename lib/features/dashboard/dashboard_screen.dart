import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/enums.dart';
import '../../providers/command_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/telemetry_provider.dart';
import 'widgets/fuel_gauge.dart';
import 'widgets/tpms_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _tickerTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Color _getUpdatedColor(int secondsDiff, bool isConnected) {
    if (!isConnected || secondsDiff > 30) {
      return AppColors.danger;
    } else if (secondsDiff >= 5) {
      return AppColors.warning;
    } else {
      return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(connectionStatusProvider);
    final telemetryAsync = ref.watch(telemetryProvider);
    final lastTelemetry = ref.watch(lastTelemetryProvider);

    final isConnected = (statusAsync.valueOrNull ?? ConnectionStatus.idle) == ConnectionStatus.ready;
    final telemetry = telemetryAsync.valueOrNull ?? lastTelemetry;

    final pressureUnit = ref.watch(pressureUnitProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);
    final fuelUnit = ref.watch(fuelUnitProvider);

    final lastUpdate = telemetry?.timestamp;
    final secondsSince = lastUpdate != null ? _now.difference(lastUpdate).inSeconds : 999;
    final updatedColor = _getUpdatedColor(secondsSince, isConnected);
    final updatedText = lastUpdate != null ? 'Updated ${secondsSince}s ago' : 'No data';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await ref.read(commandControllerProvider.notifier).requestSnapshot();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),

                // ==========================================================
                // HEADER ROW
                // ==========================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dashboard', style: AppTypography.title),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: updatedColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: updatedColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: updatedColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            updatedText,
                            style: AppTypography.label.copyWith(
                              color: updatedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================================
                // 1. FUEL GAUGE
                // ==========================================================
                GlassCard(
                  useRealBlur: false,
                  child: Center(
                    child: FuelGauge(
                      fuel: telemetry?.fuel ?? 54.2,
                      capacity: telemetry?.tankCapacity ?? 60.0,
                      rangeKm: telemetry?.range ?? 62,
                      fuelUnit: fuelUnit,
                      distanceUnit: distanceUnit,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ==========================================================
                // 2. METRIC CARDS (Battery & Odometer, then Oil Life)
                // ==========================================================
                Row(
                  children: [
                    // Live Battery Voltage Card (from ESP32 Pin 34 via BLE)
                    Expanded(
                      child: GlassCard(
                        useRealBlur: false,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'BATTERY',
                                  style: AppTypography.label.copyWith(fontSize: 10),
                                ),
                                Icon(
                                  Icons.battery_charging_full,
                                  color: (telemetry?.batteryVoltage ?? 12.4) < 11.8
                                      ? AppColors.danger
                                      : ((telemetry?.batteryVoltage ?? 12.4) < 12.2
                                          ? AppColors.warning
                                          : AppColors.accent),
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${(telemetry?.batteryVoltage ?? 12.4).toStringAsFixed(2)} V',
                              style: AppTypography.display.copyWith(
                                fontSize: 24,
                                color: (telemetry?.batteryVoltage ?? 12.4) < 11.8
                                    ? AppColors.danger
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              (telemetry?.batteryVoltage ?? 12.4) < 11.8
                                  ? 'Low Voltage'
                                  : 'ESP32 Live Pin 34',
                              style: AppTypography.label.copyWith(
                                fontSize: 10,
                                color: (telemetry?.batteryVoltage ?? 12.4) < 11.8
                                    ? AppColors.danger
                                    : AppColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    // Odometer Card
                    Expanded(
                      child: GlassCard(
                        useRealBlur: false,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ODOMETER',
                                  style: AppTypography.label.copyWith(fontSize: 10),
                                ),
                                const Icon(Icons.speed, color: AppColors.accent, size: 20),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              distanceUnit == DistanceUnit.km
                                  ? Formatters.km(telemetry?.odometer ?? 6721)
                                  : Formatters.miles(telemetry?.odometer ?? 6721),
                              style: AppTypography.display.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Service in 8,279 km',
                              style: AppTypography.label.copyWith(
                                fontSize: 10,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // ==========================================================
                // 3. TPMS CARD
                // ==========================================================
                TpmsCard(
                  tpms: telemetry?.tpms ?? const [37.2, 37.0, 29.1, 29.4],
                  unit: pressureUnit,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
