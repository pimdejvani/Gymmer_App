import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/data/workout_store_memory.dart';
import 'package:gymmer_flutter/domain/finish_workout_service.dart';
import 'package:gymmer_flutter/models.dart';
import 'package:gymmer_flutter/screens/profile/workout_detail_page.dart';
import 'package:gymmer_flutter/widgets/profile/workout_feed_card.dart';

import 'support/test_app.dart';

CompletedWorkout _demo(int exerciseCount) {
  return CompletedWorkout(
    sessionName: 'Demo',
    routineName: null,
    routineGroupName: null,
    startedAt: DateTime(2026, 7, 4, 18),
    completedAt: DateTime(2026, 7, 4, 19),
    exercises: [
      for (var i = 0; i < exerciseCount; i++)
        CompletedWorkoutExercise(
          exerciseName: 'Exercise ${i + 1}',
          sets: const [(kg: 20, reps: 10)],
        ),
    ],
  );
}

void main() {
  test(
    'finishing a workout appends a completed workout with correct stats',
    () async {
      final store = MemoryWorkoutStore.seeded();
      expect((await store.loadCompletedWorkouts()).length, 1);

      final exercise = store.exercises.first;
      final workout = ActiveWorkout(
        sessionName: 'Test Session',
        source: 'Push A',
        routineName: 'Push A',
        routineGroupName: 'Push',
        exercises: [
          WorkoutExercise(exercise, 90, [
            WorkoutSet(kgText: '50', repsText: '10')..completed = true,
            WorkoutSet(kgText: '50', repsText: '8')..completed = true,
          ]),
        ],
      );
      await store.finishWorkout(workout);

      final list = await store.loadCompletedWorkouts();
      expect(list.length, 2);
      // Newest first.
      final newest = list.first;
      expect(newest.totalSets, 2);
      expect(newest.totalVolumeKg, 50 * 10 + 50 * 8);
    },
  );

  test('buildCompletedWorkout skips incomplete/invalid sets', () {
    final exercise = Exercise('Bench', 'Chest', 'Barbell');
    final workout = ActiveWorkout(
      sessionName: 'S',
      source: 'S',
      routineName: null,
      routineGroupName: null,
      exercises: [
        WorkoutExercise(exercise, null, [
          WorkoutSet(kgText: '40', repsText: '5')..completed = true,
          WorkoutSet(kgText: '40', repsText: '5'), // not completed
          WorkoutSet(kgText: '', repsText: '')..completed = true, // invalid
        ]),
      ],
    );

    final built = buildCompletedWorkout(workout, completedAt: DateTime.now());
    final records = buildCompletedSetRecords(workout);
    expect(built.totalSets, records.length);
    expect(built.totalSets, 1);
  });

  testWidgets('feed card shows 3 exercise lines and "See 1 more exercises"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutFeedCard(workout: _demo(4))),
      ),
    );

    expect(find.text('1 sets Exercise 1'), findsOneWidget);
    expect(find.text('1 sets Exercise 2'), findsOneWidget);
    expect(find.text('1 sets Exercise 3'), findsOneWidget);
    expect(find.text('1 sets Exercise 4'), findsNothing);
    expect(find.text('See 1 more exercises'), findsOneWidget);
  });

  testWidgets('tapping a feed card opens the detail page listing every set', (
    tester,
  ) async {
    final workout = CompletedWorkout(
      sessionName: 'Detail Demo',
      routineName: 'Push A',
      routineGroupName: 'Push',
      startedAt: DateTime(2026, 7, 4, 18),
      completedAt: DateTime(2026, 7, 4, 19),
      exercises: [
        CompletedWorkoutExercise(
          exerciseName: 'Bench',
          sets: const [(kg: 50, reps: 10), (kg: 55, reps: 8)],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: WorkoutFeedCard(
              workout: workout,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailPage(
                    store: MemoryWorkoutStore.seeded(),
                    workout: workout,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(WorkoutFeedCard));
    await tester.pumpAndSettle();

    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('50 kg × 10'), findsOneWidget);
    expect(find.text('55 kg × 8'), findsOneWidget);
  });

  testWidgets('Profile tab is reachable and shows the workout feed', (
    tester,
  ) async {
    await pumpGymmer(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Feed sits below the chart + dashboard; scroll it into view.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.byType(WorkoutFeedCard), findsWidgets);
  });

  testWidgets('Profile workout detail edits a logged session, not a routine', (
    tester,
  ) async {
    await pumpGymmer(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WorkoutFeedCard).first);
    await tester.pumpAndSettle();

    // The app-bar Edit opens the whole-session editor: duration + set editing,
    // not a routine editor.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Add Set'), findsWidgets);
    expect(find.textContaining('Routine Builder'), findsNothing);
  });

  testWidgets('About page shows anatomy license credits', (tester) async {
    await pumpGymmer(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('About GYMMER'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('About GYMMER'));
    await tester.pumpAndSettle();

    expect(find.textContaining('AnatomyTOOL'), findsWidgets);
    expect(find.textContaining('CC BY-NC-SA'), findsOneWidget);
  });

  testWidgets('exercise detail shows PRs and reps trend chip', (tester) async {
    await pumpGymmer(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incline Dumbbell Press'));
    await tester.pumpAndSettle();

    expect(find.text('Personal Records'), findsOneWidget);
    expect(find.text('Best 1RM'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total Reps'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('reps trend')), findsOneWidget);
  });

  test('sqlite store updates completed exercise sets and snapshots', () async {
    final store = await openTestStore();
    final state = await store.load();
    final routine = state.groups.first.routines.first;
    final exercise = routine.exercises.first.exercise;
    final workout = ActiveWorkout.fromRoutine(
      routine,
      groupName: state.groups.first.name,
      history: state.history,
    );
    workout.exercises.first.sets.first.kg.text = '40';
    workout.exercises.first.sets.first.reps.text = '5';
    workout.exercises.first.sets.first.completed = true;
    await store.finishWorkout(workout);

    final session = (await store.loadCompletedWorkouts()).first;
    expect(session.id, isNotNull);
    await store.updateCompletedExerciseSets(session.id!, exercise.name, const [
      (kg: 66, reps: 4),
    ]);

    final updated = (await store.loadCompletedWorkouts()).first;
    expect(updated.exercises.first.sets.first.kg, 66);
    final previous = (await store.load()).history.previousFor(
      exerciseName: exercise.name,
      routineName: routine.name,
      setPosition: 1,
    );
    expect(previous?.kg, 66);
  });

  test('sqlite store empty set update removes exercise from session', () async {
    final store = await openTestStore();
    final state = await store.load();
    final routine = state.groups.first.routines.first;
    final exercise = routine.exercises.first.exercise;
    final workout = ActiveWorkout.fromRoutine(
      routine,
      groupName: state.groups.first.name,
      history: state.history,
    );
    workout.exercises.first.sets.first.kg.text = '40';
    workout.exercises.first.sets.first.reps.text = '5';
    workout.exercises.first.sets.first.completed = true;
    await store.finishWorkout(workout);

    final session = (await store.loadCompletedWorkouts()).first;
    await store.updateCompletedExerciseSets(
      session.id!,
      exercise.name,
      const [],
    );

    final updated = (await store.loadCompletedWorkouts()).first;
    expect(
      updated.exercises.any((item) => item.exerciseName == exercise.name),
      isFalse,
    );
  });

  test('sqlite store updates completed workout duration', () async {
    final store = await openTestStore();
    final state = await store.load();
    final routine = state.groups.first.routines.first;
    final workout = ActiveWorkout.fromRoutine(
      routine,
      groupName: state.groups.first.name,
      history: state.history,
    );
    workout.exercises.first.sets.first.kg.text = '40';
    workout.exercises.first.sets.first.reps.text = '5';
    workout.exercises.first.sets.first.completed = true;
    await store.finishWorkout(workout);

    final session = (await store.loadCompletedWorkouts()).first;
    final newStart = DateTime(2026, 7, 4, 10);
    await store.updateCompletedWorkoutTimes(
      session.id!,
      newStart,
      newStart.add(const Duration(minutes: 75)),
    );

    final updated = (await store.loadCompletedWorkouts()).firstWhere(
      (w) => w.id == session.id,
    );
    expect(updated.startedAt, newStart);
    expect(updated.duration, const Duration(minutes: 75));
  });

  testWidgets('editing a session set refreshes exercise stats', (tester) async {
    await pumpGymmer(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incline Dumbbell Press'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 Jul 2026').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'kg').first, '35');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('35 kg ×'), findsOneWidget);
    expect(find.text('35kg'), findsWidgets);
  });
}
