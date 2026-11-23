import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.color = AppColors.primary,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = (isEnabled && !isLoading)
        ? () {
            HapticFeedback.lightImpact();
            onTap?.call();
          }
        : null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: effectiveOnTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
            border: Border.all(color: color),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(64),
                blurRadius: 12,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withAlpha(51), color.withAlpha(26)],
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.label.copyWith(color: color),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
