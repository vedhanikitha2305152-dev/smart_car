import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/enums.dart';

class FuelGauge extends StatelessWidget {
  const FuelGauge({
    super.key,
    required this.fuel,
    required this.capacity,
    required this.rangeKm,
    this.fuelUnit = FuelUnit.liters,
    this.distanceUnit = DistanceUnit.km,
  });

  final double fuel;
  final double capacity;
  final int rangeKm;
  final FuelUnit fuelUnit;
  final DistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context) {
    final ratio = (fuel / (capacity > 0 ? capacity : 60)).clamp(0.0, 1.0);

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final fuelText = fuelUnit == FuelUnit.liters
        ? Formatters.liters(fuel)
        : Formatters.gallons(fuel);

    final rangeText = distanceUnit == DistanceUnit.km
        ? '${Formatters.km(rangeKm)} left'
        : '${Formatters.miles(rangeKm)} left';

    return TweenAnimationBuilder<double>(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: ratio),
      builder: (context, animatedRatio, child) {
        return SizedBox(
          width: 240,
          height: 190,
          child: CustomPaint(
            painter: _FuelArcPainter(
              fillRatio: animatedRatio,
            ),
            child: Align(
              alignment: const Alignment(0, 0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fuelText,
                    style: AppTypography.display.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeText,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FuelArcPainter extends CustomPainter {
  const _FuelArcPainter({required this.fillRatio});

  final double fillRatio;

  // 240 degrees arc = 4π / 3 radians
  // Center is bottom, starting at 150 deg (5π/6) to 390 deg (13π/6)
  static const double _startAngle = 5 * math.pi / 6; // 150°
  static const double _sweepTotal = 4 * math.pi / 3; // 240°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    final radius = size.width * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track Background
    final trackPaint = Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepTotal, false, trackPaint);

    if (fillRatio <= 0.001) return;

    // Determine color by threshold: <8% Red, <15% Amber, else Neon Blue gradient
    final Color startColor;
    final Color endColor;
    if (fillRatio < 0.08) {
      startColor = AppColors.danger;
      endColor = const Color(0xFFFF6961);
    } else if (fillRatio < 0.15) {
      startColor = AppColors.warning;
      endColor = const Color(0xFFFFD166);
    } else {
      startColor = AppColors.primary;
      endColor = AppColors.accent;
    }

    final currentSweep = _sweepTotal * fillRatio;

    final arcGradient = SweepGradient(
      startAngle: _startAngle,
      endAngle: _startAngle + _sweepTotal,
      colors: [startColor, endColor],
    );

    final activePaint = Paint()
      ..shader = arcGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Glow at tip
    final glowPaint = Paint()
      ..color = endColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawArc(rect, _startAngle, currentSweep, false, glowPaint);
    canvas.drawArc(rect, _startAngle, currentSweep, false, activePaint);

    // Tip Indicator Dot
    final tipAngle = _startAngle + currentSweep;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);

    canvas.drawCircle(
      Offset(tipX, tipY),
      5,
      Paint()..color = AppColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(_FuelArcPainter oldDelegate) =>
      oldDelegate.fillRatio != fillRatio;
}
