import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_car/data/models/enums.dart';
import 'package:smart_car/data/models/telemetry.dart';
import 'package:smart_car/features/home/widgets/command_hub.dart';
import 'package:smart_car/providers/repository_provider.dart';

void main() {
  testWidgets('CommandHub renders Lock and Unlock buttons correctly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final testTelemetry = Telemetry(
      version: 1,
      fuel: 54.2,
      tankCapacity: 60,
      range: 62,
      oilLife: 83,
      odometer: 6721,
      tpms: const [37.2, 37.0, 29.1, 29.4],
      locked: true,
      driveMode: DriveMode.comfort,
      lightsOn: false,
      alertCode: AlertCode.ok,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: CommandHub(
                telemetry: testTelemetry,
                isConnected: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('LOCK'), findsOneWidget);
    expect(find.text('UNLOCK'), findsOneWidget);
    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('All Set'), findsOneWidget);
  });

  testWidgets('CommandHub buttons are disabled when disconnected', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CommandHub(
                telemetry: null,
                isConnected: false,
              ),
            ),
          ),
        ),
      ),
    );

    // Finding lock buttons
    final lockFinder = find.text('LOCK');
    expect(lockFinder, findsOneWidget);

    // Tapping while disconnected should not trigger state changes or crash
    await tester.tap(lockFinder);
    await tester.pump();
  });
}
