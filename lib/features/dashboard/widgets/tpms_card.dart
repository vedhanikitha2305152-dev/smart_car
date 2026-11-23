import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/models/tpms_thresholds.dart';

class TpmsCard extends StatefulWidget {
  const TpmsCard({
    super.key,
    required this.tpms,
    required this.unit,
  });

  /// [FL, FR, RL, RR] in PSI
  final List<double> tpms;
  final PressureUnit unit;

  @override
  State<TpmsCard> createState() => _TpmsCardState();
}

class _TpmsCardState extends State<TpmsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color _getTagColor(double psi, bool isPulse) {
    final status = TpmsThresholds.classify(psi);
    switch (status) {
      case TpmsStatus.critical:
        return isPulse
            ? AppColors.danger.withOpacity(0.4 + 0.6 * _pulseCtrl.value)
            : AppColors.danger;
      case TpmsStatus.low:
        return AppColors.warning;
      case TpmsStatus.high:
        return AppColors.warning;
      case TpmsStatus.normal:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fl = widget.tpms.isNotEmpty ? widget.tpms[0] : 37.0;
    final fr = widget.tpms.length > 1 ? widget.tpms[1] : 37.0;
    final rl = widget.tpms.length > 2 ? widget.tpms[2] : 29.1;
    final rr = widget.tpms.length > 3 ? widget.tpms[3] : 29.4;

    return GlassCard(
      useRealBlur: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIRE PRESSURE (TPMS)',
                style: AppTypography.label.copyWith(fontSize: 11, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.unit.name.toUpperCase(),
                  style: AppTypography.label.copyWith(fontSize: 10, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    // Center wireframe car CustomPainter
                    Center(
                      child: SizedBox(
                        width: 130,
                        height: 150,
                        child: CustomPaint(
                          painter: _TpmsWireframePainter(
                            flColor: _getTagColor(fl, false),
                            frColor: _getTagColor(fr, false),
                            rlColor: _getTagColor(rl, false),
                            rrColor: _getTagColor(rr, false),
                          ),
                        ),
                      ),
                    ),

                    // FL Tag (Top Left)
                    Positioned(
                      left: 0,
                      top: 10,
                      child: _TireTag(
                        wheelLabel: 'FRONT LEFT',
                        psi: fl,
                        unit: widget.unit,
                        color: _getTagColor(fl, true),
                      ),
                    ),

                    // FR Tag (Top Right)
                    Positioned(
                      right: 0,
                      top: 10,
                      child: _TireTag(
                        wheelLabel: 'FRONT RIGHT',
                        psi: fr,
                        unit: widget.unit,
                        color: _getTagColor(fr, true),
                        alignRight: true,
                      ),
                    ),

                    // RL Tag (Bottom Left)
                    Positioned(
                      left: 0,
                      bottom: 10,
                      child: _TireTag(
                        wheelLabel: 'REAR LEFT',
                        psi: rl,
                        unit: widget.unit,
                        color: _getTagColor(rl, true),
                      ),
                    ),

                    // RR Tag (Bottom Right)
                    Positioned(
                      right: 0,
                      bottom: 10,
                      child: _TireTag(
                        wheelLabel: 'REAR RIGHT',
                        psi: rr,
                        unit: widget.unit,
                        color: _getTagColor(rr, true),
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TireTag extends StatelessWidget {
  const _TireTag({
    required this.wheelLabel,
    required this.psi,
    required this.unit,
    required this.color,
    this.alignRight = false,
  });

  final String wheelLabel;
  final double psi;
  final PressureUnit unit;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          wheelLabel,
          style: AppTypography.label.copyWith(fontSize: 9, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.6), width: 1),
          ),
          child: Text(
            Formatters.pressure(psi, unit),
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TpmsWireframePainter extends CustomPainter {
  const _TpmsWireframePainter({
    required this.flColor,
    required this.frColor,
    required this.rlColor,
    required this.rrColor,
  });

  final Color flColor;
  final Color frColor;
  final Color rlColor;
  final Color rrColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final chassisPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Body Outline
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.44, height: h * 0.78),
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, chassisPaint);

    // Axles
    canvas.drawLine(Offset(w * 0.28, h * 0.26), Offset(w * 0.72, h * 0.26), chassisPaint);
    canvas.drawLine(Offset(w * 0.28, h * 0.74), Offset(w * 0.72, h * 0.74), chassisPaint);

    // Wheels
    void drawWheel(double cx, double cy, Color color) {
      final wheelRect = Rect.fromCenter(center: Offset(cx, cy), width: 10, height: 22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(wheelRect, const Radius.circular(3)),
        Paint()..color = color,
      );
    }

    drawWheel(w * 0.25, h * 0.26, flColor);
    drawWheel(w * 0.75, h * 0.26, frColor);
    drawWheel(w * 0.25, h * 0.74, rlColor);
    drawWheel(w * 0.75, h * 0.74, rrColor);

    // Connecting lines to outside tags
    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    canvas.drawLine(Offset(w * 0.20, h * 0.26), Offset(0, h * 0.18), linePaint);
    canvas.drawLine(Offset(w * 0.80, h * 0.26), Offset(w, h * 0.18), linePaint);
    canvas.drawLine(Offset(w * 0.20, h * 0.74), Offset(0, h * 0.82), linePaint);
    canvas.drawLine(Offset(w * 0.80, h * 0.74), Offset(w, h * 0.82), linePaint);
  }

  @override
  bool shouldRepaint(_TpmsWireframePainter oldDelegate) =>
      oldDelegate.flColor != flColor ||
      oldDelegate.frColor != frColor ||
      oldDelegate.rlColor != rlColor ||
      oldDelegate.rrColor != rrColor;
}
