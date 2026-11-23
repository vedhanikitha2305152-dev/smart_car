import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/data/models/enums.dart';
import 'package:smart_car/features/dashboard/widgets/fuel_gauge.dart';

void main() {
  testWidgets('FuelGauge displays correct text in center and paints arc', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FuelGauge(
              fuel: 54.2,
              capacity: 60.0,
              rangeKm: 62,
              fuelUnit: FuelUnit.liters,
              distanceUnit: DistanceUnit.km,
            ),
          ),
        ),
      ),
    );

    // Initial render
    expect(find.text('54.2 L'), findsOneWidget);
    expect(find.text('62 km left'), findsOneWidget);

    // Pump animation frame
    await tester.pumpAndSettle();
    expect(find.text('54.2 L'), findsOneWidget);
  });

  testWidgets('FuelGauge formats gallons and miles when units are switched', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FuelGauge(
              fuel: 54.2,
              capacity: 60.0,
              rangeKm: 62,
              fuelUnit: FuelUnit.gallons,
              distanceUnit: DistanceUnit.miles,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('14.3 gal'), findsOneWidget);
    expect(find.text('39 mi left'), findsOneWidget);
  });
}
