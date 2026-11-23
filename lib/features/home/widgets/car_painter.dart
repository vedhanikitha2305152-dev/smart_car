import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Top-down silhouette of the luxury vehicle drawn with CustomPainter.
/// Tilted using Matrix4 perspective in the hero section.
class CarPainter extends CustomPainter {
  const CarPainter({
    this.primaryColor = AppColors.primary,
    this.accentColor = AppColors.accent,
    this.isLightOn = false,
  });

  final Color primaryColor;
  final Color accentColor;
  final bool isLightOn;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Body Paint
    final bodyPaint = Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.fill;

    final bodyStroke = Paint()
      ..color = primaryColor.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = accentColor.withOpacity(0.25)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Car Body Path (sleek GT coupé proportions)
    final path = Path()
      ..moveTo(w * 0.30, h * 0.08) // front bumper left
      ..quadraticBezierTo(w * 0.50, h * 0.05, w * 0.70, h * 0.08) // nose curve
      ..lineTo(w * 0.76, h * 0.20) // front right fender
      ..lineTo(w * 0.82, h * 0.35) // right mirror / door start
      ..lineTo(w * 0.82, h * 0.65) // right door
      ..lineTo(w * 0.85, h * 0.80) // rear right hip
      ..quadraticBezierTo(w * 0.84, h * 0.94, w * 0.68, h * 0.95) // rear bumper right
      ..lineTo(w * 0.32, h * 0.95) // rear bumper center
      ..quadraticBezierTo(w * 0.16, h * 0.94, w * 0.15, h * 0.80) // rear left hip
      ..lineTo(w * 0.18, h * 0.65) // left door
      ..lineTo(w * 0.18, h * 0.35) // left mirror start
      ..lineTo(w * 0.24, h * 0.20) // front left fender
      ..close();

    // Wheels (FL, FR, RL, RR)
    final wheelPaint = Paint()
      ..color = const Color(0xFF0F1015)
      ..style = PaintingStyle.fill;
    final wheelStroke = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final wheelW = w * 0.10;
    final wheelH = h * 0.14;

    void drawWheel(double cx, double cy) {
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: wheelW, height: wheelH);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, wheelPaint);
      canvas.drawRRect(rrect, wheelStroke);
    }

    drawWheel(w * 0.18, h * 0.24); // FL
    drawWheel(w * 0.82, h * 0.24); // FR
    drawWheel(w * 0.15, h * 0.78); // RL
    drawWheel(w * 0.85, h * 0.78); // RR

    // Draw main body
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, bodyStroke);

    // Windshield (Front)
    final glassPaint = Paint()
      ..color = const Color(0xFF080A10)
      ..style = PaintingStyle.fill;

    final frontGlass = Path()
      ..moveTo(w * 0.32, h * 0.30)
      ..lineTo(w * 0.68, h * 0.30)
      ..lineTo(w * 0.64, h * 0.44)
      ..lineTo(w * 0.36, h * 0.44)
      ..close();
    canvas.drawPath(frontGlass, glassPaint);

    // Roof & Rear Glass
    final rearGlass = Path()
      ..moveTo(w * 0.36, h * 0.60)
      ..lineTo(w * 0.64, h * 0.60)
      ..lineTo(w * 0.68, h * 0.76)
      ..lineTo(w * 0.32, h * 0.76)
      ..close();
    canvas.drawPath(rearGlass, glassPaint);

    // Headlights
    final headlightPaint = Paint()
      ..color = isLightOn ? AppColors.accent : AppColors.textSecondary.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final lightGlow = Paint()
      ..color = isLightOn ? AppColors.accent.withOpacity(0.6) : Colors.transparent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(Offset(w * 0.32, h * 0.10), 4, lightGlow);
    canvas.drawCircle(Offset(w * 0.68, h * 0.10), 4, lightGlow);
    canvas.drawCircle(Offset(w * 0.32, h * 0.10), 3, headlightPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.10), 3, headlightPaint);

    // Taillights
    final tailPaint = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.28, h * 0.94), Offset(w * 0.44, h * 0.94), tailPaint);
    canvas.drawLine(Offset(w * 0.56, h * 0.94), Offset(w * 0.72, h * 0.94), tailPaint);
  }

  @override
  bool shouldRepaint(CarPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isLightOn != isLightOn;
}
