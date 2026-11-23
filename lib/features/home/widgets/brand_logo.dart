import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Generic luxury geometric mark (NOT the BMW logo).
/// Uses intersecting isometric diamond polygons.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandLogoPainter(),
      ),
    );
  }
}

class _BrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintStroke = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final paintFill = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Diamond 1
    final path1 = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.9, h * 0.5)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.1, h * 0.5)
      ..close();

    // Inner diamond inverted
    final path2 = Path()
      ..moveTo(w * 0.5, h * 0.25)
      ..lineTo(w * 0.75, h * 0.5)
      ..lineTo(w * 0.5, h * 0.75)
      ..lineTo(w * 0.25, h * 0.5)
      ..close();

    canvas.drawPath(path1, paintFill);
    canvas.drawPath(path1, paintStroke);
    canvas.drawPath(
      path2,
      Paint()
        ..color = AppColors.accent.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
