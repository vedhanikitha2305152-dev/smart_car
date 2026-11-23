import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum RingStatus { allSet, warning, critical }

extension RingStatusX on RingStatus {
  Color get color {
    switch (this) {
      case RingStatus.allSet:
        return AppColors.success;
      case RingStatus.warning:
        return AppColors.warning;
      case RingStatus.critical:
        return AppColors.danger;
    }
  }

  String get displayText {
    switch (this) {
      case RingStatus.allSet:
        return 'All Set';
      case RingStatus.warning:
        return 'Warning';
      case RingStatus.critical:
        return 'Critical';
    }
  }
}

class StatusRing extends StatelessWidget {
  const StatusRing({
    super.key,
    required this.status,
    this.label = 'ALERTS',
    this.statusText,
    this.size = 120,
  });

  final RingStatus status;
  final String label;
  final String? statusText;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(color: status.color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.label.copyWith(fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                statusText ?? status.displayText,
                style: AppTypography.body.copyWith(
                  color: status.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final glowPaint = Paint()
      ..color = color.withAlpha(76)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, linePaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
