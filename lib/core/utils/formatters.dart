import 'package:intl/intl.dart';

enum PressureUnit { psi, bar, kPa }

class Formatters {
  Formatters._();

  static String liters(double v, {int decimals = 1}) =>
      '${v.toStringAsFixed(decimals)} L';

  static String gallons(double v, {int decimals = 1}) =>
      '${(v * 0.264172).toStringAsFixed(decimals)} gal';

  static String km(int v) =>
      '${NumberFormat('#,###', 'en_US').format(v)} km';

  static String miles(int v) =>
      '${NumberFormat('#,###', 'en_US').format((v * 0.621371).round())} mi';

  static String percent(int v) => '$v%';

  static String pressure(double psi, PressureUnit unit) {
    switch (unit) {
      case PressureUnit.psi:
        return '${psi.toStringAsFixed(1)} psi';
      case PressureUnit.bar:
        return '${(psi * 0.0689476).toStringAsFixed(2)} bar';
      case PressureUnit.kPa:
        return '${(psi * 6.89476).toStringAsFixed(0)} kPa';
    }
  }

  static String timeAgo(DateTime then) {
    final diff = DateTime.now().difference(then);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  static String updatedAgo(DateTime? then) {
    if (then == null) return 'Never';
    return 'Updated ${timeAgo(then)}';
  }
}
