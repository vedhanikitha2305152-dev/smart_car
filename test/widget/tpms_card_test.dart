import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/core/utils/formatters.dart';
import 'package:smart_car/features/dashboard/widgets/tpms_card.dart';

void main() {
  testWidgets('TpmsCard displays 4 tire tags with proper labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TpmsCard(
            tpms: [37.2, 37.0, 29.1, 29.4],
            unit: PressureUnit.psi,
          ),
        ),
      ),
    );

    expect(find.text('TIRE PRESSURE (TPMS)'), findsOneWidget);
    expect(find.text('FRONT LEFT'), findsOneWidget);
    expect(find.text('FRONT RIGHT'), findsOneWidget);
    expect(find.text('REAR LEFT'), findsOneWidget);
    expect(find.text('REAR RIGHT'), findsOneWidget);

    expect(find.text('37.2 psi'), findsOneWidget);
    expect(find.text('37.0 psi'), findsOneWidget);
    expect(find.text('29.1 psi'), findsOneWidget);
    expect(find.text('29.4 psi'), findsOneWidget);
  });

  testWidgets('TpmsCard formats pressure in bar when bar unit is provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TpmsCard(
            tpms: [37.0, 37.0, 29.0, 29.0],
            unit: PressureUnit.bar,
          ),
        ),
      ),
    );

    expect(find.text('BAR'), findsOneWidget);
    expect(find.text('2.55 bar'), findsNWidgets(2)); // 37.0 * 0.0689476 = 2.55
    expect(find.text('2.00 bar'), findsNWidgets(2)); // 29.0 * 0.0689476 = 2.00
  });
}
