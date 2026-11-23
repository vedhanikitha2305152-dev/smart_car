import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFF0B0C10);
  static const Color surface = Color(0xFF14161D);
  static const Color surfaceHigh = Color(0xFF1F222E);

  /// White at 8% opacity — used for borders
  static const Color border = Color(0x14FFFFFF);

  static const Color primary = Color(0xFF007AFF);
  static const Color accent = Color(0xFF00D2FF);

  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF453A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9AA0B4);
  static const Color textDisabled = Color(0xFF5A6072);

  /// White at 4% — glass card fill (lighter)
  static const Color glassWhite4 = Color(0x0AFFFFFF);

  /// White at 6% — glass card fill (default)
  static const Color glassWhite6 = Color(0x0FFFFFFF);

  /// Primary at 12% — soft glow
  static const Color primaryGlow = Color(0x1F007AFF);
}
