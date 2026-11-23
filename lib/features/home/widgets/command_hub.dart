import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_ring.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/telemetry.dart';
import '../../../data/models/vehicle_command.dart';
import '../../../providers/command_provider.dart';

class CommandHub extends ConsumerStatefulWidget {
  const CommandHub({
    super.key,
    required this.telemetry,
    required this.isConnected,
  });

  final Telemetry? telemetry;
  final bool isConnected;

  @override
  ConsumerState<CommandHub> createState() => _CommandHubState();
}

class _CommandHubState extends ConsumerState<CommandHub> {
  bool _isLockingPending = false;
  bool _isUnlockingPending = false;
  Timer? _timeoutTimer;

  @override
  void didUpdateWidget(covariant CommandHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If telemetry arrived with confirmed state, clear pending spinners
    if (widget.telemetry != null && oldWidget.telemetry != widget.telemetry) {
      if (_isLockingPending && widget.telemetry!.locked) {
        _clearPending();
      } else if (_isUnlockingPending && !widget.telemetry!.locked) {
        _clearPending();
      }
    }
  }

  void _clearPending() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLockingPending = false;
        _isUnlockingPending = false;
      });
    }
  }

  Future<void> _handleLockTap(bool targetLock) async {
    if (!widget.isConnected || _isLockingPending || _isUnlockingPending) return;

    HapticFeedback.lightImpact();

    setState(() {
      if (targetLock) {
        _isLockingPending = true;
      } else {
        _isUnlockingPending = true;
      }
    });

    // 3-second timeout watchdog
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_isLockingPending || _isUnlockingPending)) {
        HapticFeedback.heavyImpact();
        setState(() {
          _isLockingPending = false;
          _isUnlockingPending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            content: Text(
              targetLock ? 'Lock command failed or timed out' : 'Unlock command failed or timed out',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        );
      }
    });

    final result = await ref
        .read(commandControllerProvider.notifier)
        .sendLock(locked: targetLock);

    if (result != CommandResult.success && mounted) {
      _timeoutTimer?.cancel();
      HapticFeedback.heavyImpact();
      setState(() {
        _isLockingPending = false;
        _isUnlockingPending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Vehicle rejected the security command',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  RingStatus _deriveRingStatus(AlertCode? alert) {
    switch (alert) {
      case AlertCode.critical:
        return RingStatus.critical;
      case AlertCode.lowFuel:
      case AlertCode.lowTire:
      case AlertCode.lowOil:
      case AlertCode.doorOpen:
        return RingStatus.warning;
      case AlertCode.ok:
      case null:
        return RingStatus.allSet;
    }
  }

  String _deriveAlertLabel(AlertCode? alert) {
    switch (alert) {
      case AlertCode.critical:
        return 'Critical';
      case AlertCode.lowFuel:
        return 'Low Fuel';
      case AlertCode.lowTire:
        return 'Low Tire';
      case AlertCode.lowOil:
        return 'Service';
      case AlertCode.doorOpen:
        return 'Door Open';
      case AlertCode.ok:
      case null:
        return 'All Set';
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.telemetry?.locked ?? true;
    final ringStatus = _deriveRingStatus(widget.telemetry?.alertCode);
    final alertText = _deriveAlertLabel(widget.telemetry?.alertCode);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Lock Button (Left)
        _HubActionButton(
          label: 'LOCK',
          icon: Icons.lock_outline,
          isActive: locked,
          isLoading: _isLockingPending,
          isEnabled: widget.isConnected && !locked,
          onTap: () => _handleLockTap(true),
        ),

        const SizedBox(width: AppSpacing.lg),

        // Center Status Ring
        StatusRing(
          status: ringStatus,
          label: 'ALERTS',
          statusText: alertText,
          size: 110,
        ),

        const SizedBox(width: AppSpacing.lg),

        // Unlock Button (Right)
        _HubActionButton(
          label: 'UNLOCK',
          icon: Icons.lock_open_outlined,
          isActive: !locked,
          isLoading: _isUnlockingPending,
          isEnabled: widget.isConnected && locked,
          onTap: () => _handleLockTap(false),
        ),
      ],
    );
  }
}

class _HubActionButton extends StatelessWidget {
  const _HubActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isLoading,
    required this.isEnabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.textSecondary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled || isLoading ? 1.0 : 0.4,
      child: InkWell(
        onTap: isEnabled && !isLoading ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withOpacity(0.18) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
            border: Border.all(
              color: isActive ? AppColors.primary.withOpacity(0.6) : AppColors.border,
              width: 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
