import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pulsing_dot.dart';
import '../../data/models/enums.dart';
import '../../providers/repository_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../discovery/discovery_modal.dart';
import 'widgets/brand_logo.dart';
import 'widgets/car_painter.dart';
import 'widgets/command_hub.dart';
import 'widgets/quick_action_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openDiscoveryModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadiusLarge)),
      ),
      builder: (ctx) => const DiscoveryModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusProvider);
    final telemetryAsync = ref.watch(telemetryProvider);
    final lastTelemetry = ref.watch(lastTelemetryProvider);

    final connectionStatus = statusAsync.valueOrNull ?? ConnectionStatus.idle;
    final isConnected = connectionStatus == ConnectionStatus.ready;
    final activeTelemetry = telemetryAsync.valueOrNull ?? lastTelemetry;

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // ==========================================================
              // 1. HEADER ROW
              // ==========================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const BrandLogo(size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BMW M Sport',
                          style: AppTypography.title.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: activeTelemetry != null
                                      ? (activeTelemetry.fuel / activeTelemetry.tankCapacity).clamp(0.0, 1.0)
                                      : 0.8,
                                  backgroundColor: AppColors.surfaceHigh,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              activeTelemetry != null
                                  ? '${activeTelemetry.fuel.toStringAsFixed(0)} / ${activeTelemetry.tankCapacity.toStringAsFixed(0)} L'
                                  : '54 / 60 L',
                              style: AppTypography.label.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // BLE Status Icon
                  _BleStatusIndicator(
                    status: connectionStatus,
                    onTapDisconnected: () => _openDiscoveryModal(context),
                  ),

                  const SizedBox(width: AppSpacing.xs),

                  // Settings Gear
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/settings');
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Disconnected Banner
              if (!isConnected)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Not connected – showing last known data',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.read(vehicleRepositoryProvider).connect(),
                        child: const Text('Reconnect', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),

              // ==========================================================
              // 2. HERO: PERSPECTIVE TILTED CAR Silhoutte
              // ==========================================================
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isConnected ? 1.0 : 0.65,
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: reduceMotion
                          ? Matrix4.identity()
                          : (Matrix4.identity()
                            ..setEntry(3, 2, 0.0018) // perspective
                            ..rotateX(0.42) // tilt back
                            ..rotateZ(-0.06)),
                      child: SizedBox(
                        width: 140,
                        height: 220,
                        child: CustomPaint(
                          painter: CarPainter(
                            primaryColor: isConnected ? AppColors.primary : AppColors.textDisabled,
                            accentColor: isConnected ? AppColors.accent : AppColors.textSecondary,
                            isLightOn: activeTelemetry?.lightsOn ?? false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ==========================================================
              // 3. COMMAND HUB
              // ==========================================================
              CommandHub(
                telemetry: activeTelemetry,
                isConnected: isConnected,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ==========================================================
              // 4. 2x2 QUICK ACTION GRID
              // ==========================================================
              QuickActionGrid(
                telemetry: activeTelemetry,
                isConnected: isConnected,
                onLocateCarTap: () {
                  // Switch to Map tab
                  final shell = StatefulNavigationShell.of(context);
                  shell.goBranch(2);
                },
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _BleStatusIndicator extends StatelessWidget {
  const _BleStatusIndicator({
    required this.status,
    required this.onTapDisconnected,
  });

  final ConnectionStatus status;
  final VoidCallback onTapDisconnected;

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.ready) {
      return const PulsingDot(color: AppColors.success, size: 9);
    } else if (status == ConnectionStatus.connecting ||
        status == ConnectionStatus.scanning ||
        status == ConnectionStatus.negotiating ||
        status == ConnectionStatus.discoveringServices) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.bluetooth_searching, color: AppColors.danger, size: 22),
        tooltip: 'Connect BLE Device',
        onPressed: onTapDisconnected,
      );
    }
  }
}
