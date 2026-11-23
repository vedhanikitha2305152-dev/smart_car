import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A frosted-glass card.
/// [useRealBlur] enables BackdropFilter — use on at most 3 cards per screen.
/// Elsewhere keep [useRealBlur] false for a gradient fill approximation.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.useRealBlur = false,
    this.showGlow = false,
    this.radius = AppSpacing.cardRadiusLarge,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final bool useRealBlur;
  final bool showGlow;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);

    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        color: useRealBlur ? Colors.transparent : null,
        gradient: useRealBlur
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.glassWhite6, AppColors.glassWhite4],
              ),
        border: Border.all(color: AppColors.border),
        boxShadow: showGlow
            ? const [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 24,
                )
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (useRealBlur) {
      content = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      );
    }

    return content;
  }
}
