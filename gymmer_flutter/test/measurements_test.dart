import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/data/workout_store_memory.dart';
import 'package:gymmer_flutter/models.dart';
import 'package:gymmer_flutter/screens/profile/measurements_page.dart';

import 'support/test_app.dart';

void main() {
  test(
    'memory store: save, overwrite same date, delete, blanks stay null',
    () async {
      final store = MemoryWorkoutStore.seeded();
      expect(await store.loadMeasurements(), isEmpty);

      await store.saveMeasurement(
        MeasurementEntry(date: DateTime(2026, 7, 4), bodyWeightKg: 72.5),
      );
      var list = await store.loadMeasurements();
      expect(list, hasLength(1));
      expect(list.first.bodyWeightKg, 72.5);
      expect(list.first.waistCm, isNull); // blank field stays null

      // Same-date save overwrites.
      await store.saveMeasurement(
        MeasurementEntry(date: DateTime(2026, 7, 4, 10), bodyWeightKg: 73.0),
      );
      list = await store.loadMeasurements();
      expect(list, hasLength(1));
      expect(list.first.bodyWeightKg, 73.0);

      await store.deleteMeasurement(DateTime(2026, 7, 4));
      expect(await store.loadMeasurements(), isEmpty);
    },
  );

  test('sqlite store: migration creates table and upserts by date', () async {
    final store = await openTestStore();
    expect(await store.loadMeasurements(), isEmpty);

    await store.saveMeasurement(
      MeasurementEntry(
        date: DateTime(2026, 7, 4),
        bodyWeightKg: 80,
        waistCm: 82.5,
      ),
    );
    await store.saveMeasurement(
      MeasurementEntry(date: DateTime(2026, 7, 4, 9), bodyWeightKg: 79.5),
    );

    final list = await store.loadMeasurements();
    expect(list, hasLength(1)); // upsert by calendar date
    expect(list.first.bodyWeightKg, 79.5);
    expect(list.first.waistCm, isNull); // overwritten entry left it blank
  });

  testWidgets('log page saves weight 72.5 → list shows 72.5kg', (tester) async {
    final store = MemoryWorkoutStore.seeded();
    await tester.pumpWidget(
      MaterialApp(
        home: MeasurementsPage(
          load: store.loadMeasurements,
          save: store.saveMeasurement,
          delete: store.deleteMeasurement,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log Measurements'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Body Weight (kg)'),
      '72.5',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('72.5kg'), findsOneWidget);
  });
}
