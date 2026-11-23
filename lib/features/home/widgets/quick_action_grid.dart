import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/telemetry.dart';
import '../../../data/models/vehicle_command.dart';
import '../../../providers/command_provider.dart';

class QuickActionGrid extends ConsumerWidget {
  const QuickActionGrid({
    super.key,
    required this.telemetry,
    required this.isConnected,
    required this.onLocateCarTap,
  });

  final Telemetry? telemetry;
  final bool isConnected;
  final VoidCallback onLocateCarTap;

  void _showDriveModeBottomSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadiusLarge)),
      ),
      builder: (ctx) => _DriveModeSheet(
        currentMode: telemetry?.driveMode ?? DriveMode.comfort,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveMode = telemetry?.driveMode ?? DriveMode.comfort;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: [
        // 1. Drive Mode Card
        _ActionCard(
          icon: Icons.tune,
          title: 'DRIVE MODE',
          value: driveMode.name.toUpperCase(),
          valueColor: driveMode == DriveMode.sport
              ? AppColors.danger
              : (driveMode == DriveMode.eco ? AppColors.success : AppColors.accent),
          onTap: isConnected ? () => _showDriveModeBottomSheet(context, ref) : null,
        ),

        // 2. Change Car Card
        _ActionCard(
          icon: Icons.garage_outlined,
          title: 'GARAGE',
          value: 'Switch Car',
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/garage');
          },
        ),

        // 3. Digital Key / Share (STUB)
        _ActionCard(
          icon: Icons.key_outlined,
          title: 'DIGITAL KEY',
          value: isConnected ? 'Phone Paired' : 'Not Paired',
          badgeText: 'Coming Soon',
          onTap: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.surfaceHigh,
                behavior: SnackBarBehavior.floating,
                content: Text('// STUB: Digital Key sharing coming in future update.'),
              ),
            );
          },
        ),

        // 4. Car Location Card
        _ActionCard(
          icon: Icons.near_me_outlined,
          title: 'CAR LOCATION',
          value: 'Show on Map',
          onTap: () {
            HapticFeedback.lightImpact();
            onLocateCarTap();
          },
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.badgeText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  final String? badgeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      useRealBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppColors.accent, size: 22),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      badgeText!,
                      style: AppTypography.label.copyWith(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, color: AppColors.textDisabled, size: 12),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(fontSize: 10, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveModeSheet extends ConsumerStatefulWidget {
  const _DriveModeSheet({required this.currentMode});

  final DriveMode currentMode;

  @override
  ConsumerState<_DriveModeSheet> createState() => _DriveModeSheetState();
}

class _DriveModeSheetState extends ConsumerState<_DriveModeSheet> {
  DriveMode? _pendingMode;

  Future<void> _selectMode(DriveMode mode) async {
    if (_pendingMode != null) return;
    setState(() => _pendingMode = mode);
    HapticFeedback.lightImpact();

    final result = await ref
        .read(commandControllerProvider.notifier)
        .sendDriveMode(mode);

    if (mounted) {
      if (result == CommandResult.success) {
        Navigator.pop(context);
      } else {
        setState(() => _pendingMode = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to change drive mode', style: TextStyle(color: AppColors.danger)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SELECT DRIVE MODE', style: AppTypography.title.copyWith(fontSize: 18)),
            const SizedBox(height: AppSpacing.lg),
            _ModeOptionTile(
              mode: DriveMode.comfort,
              title: 'Comfort',
              description: 'Balanced suspension, smooth throttle and steering response',
              icon: Icons.nightlife,
              color: AppColors.accent,
              isSelected: widget.currentMode == DriveMode.comfort,
              isPending: _pendingMode == DriveMode.comfort,
              onTap: () => _selectMode(DriveMode.comfort),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModeOptionTile(
              mode: DriveMode.sport,
              title: 'Sport',
              description: 'Aggressive throttle mapping, firmer dampers, sport exhaust open',
              icon: Icons.electric_bolt,
              color: AppColors.danger,
              isSelected: widget.currentMode == DriveMode.sport,
              isPending: _pendingMode == DriveMode.sport,
              onTap: () => _selectMode(DriveMode.sport),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModeOptionTile(
              mode: DriveMode.eco,
              title: 'Eco Pro',
              description: 'Maximum fuel efficiency, coasting decoupling, optimized HVAC',
              icon: Icons.eco,
              color: AppColors.success,
              isSelected: widget.currentMode == DriveMode.eco,
              isPending: _pendingMode == DriveMode.eco,
              onTap: () => _selectMode(DriveMode.eco),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  const _ModeOptionTile({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isPending,
    required this.onTap,
  });

  final DriveMode mode;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.12) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: isPending ? null : onTap,
        leading: Icon(icon, color: isSelected ? color : AppColors.textSecondary),
        title: Text(
          title,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isSelected ? color : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          description,
          style: AppTypography.label.copyWith(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: isPending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              )
            : (isSelected ? Icon(Icons.check_circle, color: color, size: 20) : null),
      ),
    );
  }
}
