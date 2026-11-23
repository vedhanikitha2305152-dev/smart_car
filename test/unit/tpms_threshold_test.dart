import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/data/models/tpms_thresholds.dart';

void main() {
  group('TPMS Threshold Classification Tests', () {
    test('classifies normal pressures (30.0 to 42.0 psi)', () {
      expect(TpmsThresholds.classify(30.0), TpmsStatus.normal);
      expect(TpmsThresholds.classify(36.5), TpmsStatus.normal);
      expect(TpmsThresholds.classify(42.0), TpmsStatus.normal);
    });

    test('classifies low pressures (25.0 to 29.9 psi)', () {
      expect(TpmsThresholds.classify(25.0), TpmsStatus.low);
      expect(TpmsThresholds.classify(27.4), TpmsStatus.low);
      expect(TpmsThresholds.classify(29.9), TpmsStatus.low);
    });

    test('classifies critical pressures (< 25.0 psi)', () {
      expect(TpmsThresholds.classify(24.9), TpmsStatus.critical);
      expect(TpmsThresholds.classify(18.0), TpmsStatus.critical);
      expect(TpmsThresholds.classify(0.0), TpmsStatus.critical);
    });

    test('classifies high pressures (> 42.0 psi)', () {
      expect(TpmsThresholds.classify(42.1), TpmsStatus.high);
      expect(TpmsThresholds.classify(55.0), TpmsStatus.high);
    });
  });
}
