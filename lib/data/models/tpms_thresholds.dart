/// Configurable TPMS pressure thresholds.
/// Order in data array: [FL, FR, RL, RR]
///
/// Threshold rules:
/// - Normal: 30.0 – 42.0 psi (inclusive)
/// - Low: 25.0 – 29.9 psi
/// - Critical: < 25.0 psi
/// - High: > 42.0 psi
abstract final class TpmsThresholds {
  static const double normalMin = 30.0;
  static const double normalMax = 42.0;
  static const double lowMin = 25.0;
  static const double criticalMax = 25.0;
  static const double highMin = 42.0;

  static TpmsStatus classify(double psi) {
    if (psi < criticalMax) {
      return TpmsStatus.critical;
    } else if (psi < normalMin) {
      return TpmsStatus.low;
    } else if (psi > highMin) {
      return TpmsStatus.high;
    } else {
      return TpmsStatus.normal;
    }
  }
}

enum TpmsStatus {
  normal,
  low,
  critical,
  high,
}
