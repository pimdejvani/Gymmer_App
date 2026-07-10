import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/models.dart';
import 'package:gymmer_flutter/screens/exercise_library_page.dart';

import 'support/test_app.dart';

void main() {
  group('filterAndSortExercises', () {
    final exercises = [
      Exercise('Bench Press', 'Chest', 'Barbell'),
      Exercise('Incline Bench Press', 'Chest', 'Dumbbell'),
      Exercise('Squat', 'Quads', 'Barbell'),
    ];

    test('empty query returns all in original order', () {
      final result = filterAndSortExercises(exercises, '');
      expect(result.map((e) => e.name), [
        'Bench Press',
        'Incline Bench Press',
        'Squat',
      ]);
    });

    test('case-insensitive name-contains filter', () {
      final result = filterAndSortExercises(exercises, 'bench');
      expect(result.map((e) => e.name), ['Bench Press', 'Incline Bench Press']);
    });

    test('favorites sort first, preserving order within groups', () {
      final list = [
        Exercise('A', 'Chest', 'Barbell'),
        Exercise('B', 'Chest', 'Barbell', const [], null, const [], true),
        Exercise('C', 'Chest', 'Barbell'),
        Exercise('D', 'Chest', 'Barbell', const [], null, const [], true),
      ];
      final result = filterAndSortExercises(list, '');
      expect(result.map((e) => e.name), ['B', 'D', 'A', 'C']);
    });
  });

  testWidgets('toggling a star persists through store reload', (tester) async {
    final store = await pumpGymmer(tester);
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    // Isolate a single exercise so we know which star we are tapping.
    await tester.enterText(find.byType(TextField).first, 'Barbell Back Squat');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsOneWidget);

    final reloaded = await store.load();
    final squat = reloaded.exercises.firstWhere(
      (e) => e.name == 'Barbell Back Squat',
    );
    expect(squat.isFavorite, isTrue);
  });

  test('sqlite migration adds is_favorite column defaulting to 0', () async {
    final store = await openTestStore();
    final state = await store.load();
    expect(state.exercises.every((e) => e.isFavorite == false), isTrue);

    await store.setExerciseFavorite('Barbell Back Squat', true);
    final reloaded = await store.load();
    final squat = reloaded.exercises.firstWhere(
      (e) => e.name == 'Barbell Back Squat',
    );
    expect(squat.isFavorite, isTrue);
  });
}
