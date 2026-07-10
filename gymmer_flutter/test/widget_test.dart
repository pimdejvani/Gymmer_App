import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/data/workout_store_sqlite.dart';
import 'package:gymmer_flutter/models.dart';
import 'package:gymmer_flutter/screens/active_workout_page.dart';
import 'package:gymmer_flutter/widgets/exercise_picker_page.dart';
import 'package:path/path.dart' as p;

import 'support/test_app.dart';

void main() {
  test('formats workout session timestamp without minutes', () {
    final timestamp = formatSessionTimestamp(DateTime(2026, 7, 5, 14, 30));

    expect(timestamp, '5 Jul 2 PM');
  });

  test('autofills routine sets from previous history', () {
    final exercises = [
      Exercise('Incline Dumbbell Press', 'Chest', 'Dumbbell'),
      Exercise('Cable Lateral Raise', 'Side Delt', 'Cable'),
    ];
    final history = WorkoutHistory.seeded(exercises);
    final routine = Routine('Push A', 'Chest day', [
      RoutineExercise(exercises.first, 2, 90),
    ]);

    final workout = ActiveWorkout.fromRoutine(
      routine,
      groupName: 'Push',
      history: history,
    );

    expect(workout.routineGroupName, 'Push');
    expect(workout.exercises.first.sets.first.kg.text, '22.5');
    expect(workout.exercises.first.sets.first.reps.text, '9');
    expect(workout.exercises.first.sets[1].kg.text, '22.5');
    expect(workout.exercises.first.sets[1].reps.text, '8');
  });

  test('recorded workout becomes latest previous value', () {
    final exercise = Exercise('Incline Dumbbell Press', 'Chest', 'Dumbbell');
    final history = WorkoutHistory([]);
    final workout = ActiveWorkout(
      sessionName: 'Push A 5 Jul 2 PM',
      source: 'Push A',
      routineName: 'Push A',
      routineGroupName: 'Push',
      exercises: [
        WorkoutExercise(exercise, 90, [
          WorkoutSet(kgText: '30', repsText: '6')..completed = true,
        ]),
      ],
    );

    history.recordWorkout(workout);

    final previous = history.previousFor(
      exerciseName: exercise.name,
      routineName: 'Push A',
      setPosition: 1,
    );
    expect(previous?.kgText, '30');
    expect(previous?.reps, 6);
    expect(previous?.routineGroupName, 'Push');
  });

  test('sqlite store saves and restores active workout draft', () async {
    final store = await openTestStore();
    final state = await store.load();
    final routine = state.groups.first.routines.first;
    final workout = ActiveWorkout.fromRoutine(
      routine,
      groupName: state.groups.first.name,
      history: state.history,
    );
    workout.exercises.first.sets.first.kg.text = '35';
    workout.exercises.first.sets.first.reps.text = '5';
    workout.exercises.first.sets.first.completed = true;

    await store.saveActiveWorkout(workout);
    final restored = (await store.load()).activeWorkout;

    expect(restored?.sessionName, workout.sessionName);
    expect(restored?.exercises.first.sets.first.kg.text, '35');
    expect(restored?.exercises.first.sets.first.reps.text, '5');
    expect(restored?.exercises.first.sets.first.completed, isTrue);
  });

  test('sqlite store saves exercise thumbnail and media metadata', () async {
    final store = await openTestStore();
    await store.load();
    await store.saveExercise(
      Exercise(
        'Standing Calf Raise',
        'Calves',
        'Machine',
        const ['Hamstrings'],
        r'C:\media\calf-thumb.png',
        const [
          ExerciseMedia(
            path: r'C:\media\calf-demo.png',
            type: ExerciseMediaType.image,
          ),
          ExerciseMedia(
            path: r'C:\media\calf-demo.mp4',
            type: ExerciseMediaType.video,
          ),
        ],
      ),
    );

    final saved = (await store.load()).exercises.firstWhere(
      (exercise) => exercise.name == 'Standing Calf Raise',
    );

    expect(saved.thumbnailPath, r'C:\media\calf-thumb.png');
    expect(saved.media, hasLength(2));
    expect(saved.media.last.type, ExerciseMediaType.video);
  });

  test('sqlite store updates an existing exercise when renamed', () async {
    final store = await openTestStore();
    await store.load();

    await store.saveExercise(
      Exercise('Cable Side Raise', 'Side Delt', 'Cable', const ['Traps']),
      originalName: 'Cable Lateral Raise',
    );
    final reloaded = await store.load();

    expect(
      reloaded.exercises.any((exercise) => exercise.name == 'Cable Side Raise'),
      isTrue,
    );
    expect(
      reloaded.exercises.any(
        (exercise) => exercise.name == 'Cable Lateral Raise',
      ),
      isFalse,
    );
    expect(
      reloaded.groups.first.routines.first.exercises.last.exercise.name,
      'Cable Side Raise',
    );
  });

  test(
    'sqlite store finishes workout and rebuilds statistic snapshots',
    () async {
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

      await store.saveActiveWorkout(workout);
      await store.finishWorkout(workout);
      final reloaded = await store.load();
      final previous = reloaded.history.previousFor(
        exerciseName: routine.exercises.first.exercise.name,
        routineName: routine.name,
        setPosition: 1,
      );

      expect(reloaded.activeWorkout, isNull);
      expect(previous?.kgText, '40');
      expect(previous?.reps, 5);
      expect(store.previousSnapshotCount(), greaterThan(0));
      expect(store.bestSnapshotCount(), greaterThan(0));
    },
  );

  test('sqlite store persists data across close and reopen', () async {
    final tempDir = await Directory.systemTemp.createTemp('gymmer_reopen_');
    final path = p.join(tempDir.path, 'persist.sqlite');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final s1 = GymmerSqliteStore.openPath(path);
    final state1 = await s1.load();
    final seedExerciseCount = state1.exercises.length;
    final routine = state1.groups.first.routines.first;
    final workout = ActiveWorkout.fromRoutine(
      routine,
      groupName: state1.groups.first.name,
      history: state1.history,
    );
    workout.exercises.first.sets.first.kg.text = '42.5';
    workout.exercises.first.sets.first.reps.text = '7';
    workout.exercises.first.sets.first.completed = true;
    await s1.saveActiveWorkout(workout);
    await s1.saveExercise(
      Exercise('Farmer Carry', 'Forearms', 'Dumbbell', const ['Traps']),
    );
    await s1.close();

    final s2 = GymmerSqliteStore.openPath(path);
    final state2 = await s2.load();

    expect(state2.activeWorkout, isNotNull);
    expect(state2.activeWorkout!.exercises.first.sets.first.kg.text, '42.5');
    expect(state2.activeWorkout!.exercises.first.sets.first.reps.text, '7');
    expect(state2.activeWorkout!.exercises.first.sets.first.completed, isTrue);
    expect(state2.exercises.any((e) => e.name == 'Farmer Carry'), isTrue);
    expect(
      state2.exercises.length,
      seedExerciseCount + 1,
      reason: 'seed must be idempotent; only the custom exercise adds a row',
    );

    await s2.close();
  });

  test(
    'sqlite store completed history survives close and reopen (DB audit #5)',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('gymmer_hist_');
      final path = p.join(tempDir.path, 'hist.sqlite');
      addTearDown(() async {
        try {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        } on FileSystemException {
          // Windows sometimes holds the sqlite file handle briefly after
          // close(); leaking the temp dir is fine for a test tear-down.
        }
      });

      final s1 = GymmerSqliteStore.openPath(path);
      final state1 = await s1.load();
      // Pick a routine (Legs A / Barbell Back Squat) that has no seed history
      // so the finished record we insert is the only match on that key.
      final routine = state1.groups
          .firstWhere((g) => g.name == 'Legs')
          .routines
          .firstWhere((r) => r.name == 'Legs A');
      final exercise = routine.exercises.first.exercise;
      final workout = ActiveWorkout.fromRoutine(
        routine,
        groupName: state1.groups.first.name,
        history: state1.history,
      );
      workout.exercises.first.sets.first.kg.text = '55';
      workout.exercises.first.sets.first.reps.text = '5';
      workout.exercises.first.sets.first.completed = true;
      await s1.saveActiveWorkout(workout);
      await s1.finishWorkout(workout);
      final previousCountBefore = s1.previousSnapshotCount();
      final bestCountBefore = s1.bestSnapshotCount();
      await s1.close();

      final s2 = GymmerSqliteStore.openPath(path);
      final state2 = await s2.load();

      final finishedRecord = state2.history.records.firstWhere(
        (record) =>
            record.exerciseName == exercise.name &&
            record.routineName == routine.name &&
            record.setPosition == 1,
      );
      expect(finishedRecord.kg, 55.0);
      expect(finishedRecord.reps, 5);
      expect(s2.previousSnapshotCount(), previousCountBefore);
      expect(s2.bestSnapshotCount(), bestCountBefore);

      await s2.close();
    },
  );

  test(
    'sqlite store Previous uses persisted snapshot after finish + reopen (DB audit #6)',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('gymmer_prev_');
      final path = p.join(tempDir.path, 'prev.sqlite');
      addTearDown(() async {
        try {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        } on FileSystemException {
          // Windows sometimes holds the sqlite file handle briefly after
          // close(); leaking the temp dir is fine for a test tear-down.
        }
      });

      final s1 = GymmerSqliteStore.openPath(path);
      final state1 = await s1.load();
      // Pick a routine (Legs A / Barbell Back Squat) that has no seed history
      // so the finished record we insert is the only match on that key.
      final routine = state1.groups
          .firstWhere((g) => g.name == 'Legs')
          .routines
          .firstWhere((r) => r.name == 'Legs A');
      final exercise = routine.exercises.first.exercise;
      final workout = ActiveWorkout.fromRoutine(
        routine,
        groupName: state1.groups.first.name,
        history: state1.history,
      );
      workout.exercises.first.sets.first.kg.text = '77.5';
      workout.exercises.first.sets.first.reps.text = '3';
      workout.exercises.first.sets.first.completed = true;
      await s1.finishWorkout(workout);
      await s1.close();

      final s2 = GymmerSqliteStore.openPath(path);
      await s2.load();

      final snapshot = s2.previousSnapshotForTesting(
        exerciseName: exercise.name,
        routineName: routine.name,
        setPosition: 1,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.kg, 77.5);
      expect(snapshot.reps, 3);

      await s2.close();
    },
  );

  test(
    'sqlite store No Routine sessions do not feed Previous snapshots (DB audit #7)',
    () async {
      final store = await openTestStore();
      final state = await store.load();
      // Pick a routine that has no seed history so any Previous snapshot we
      // find must come from THIS test.
      final routine = state.groups
          .firstWhere((g) => g.name == 'Legs')
          .routines
          .firstWhere((r) => r.name == 'Legs A');
      final exercise = routine.exercises.first.exercise;

      final noRoutine = ActiveWorkout(
        sessionName: 'No Routine test',
        source: 'No Routine',
        routineName: null,
        routineGroupName: null,
        exercises: [
          WorkoutExercise(exercise, null, [
            WorkoutSet(kgText: '999', repsText: '999')..completed = true,
          ]),
        ],
      );
      await store.finishWorkout(noRoutine);

      // Previous snapshot for this exercise + routine must NOT exist, because
      // No Routine sessions must not contribute to routine Previous values.
      final snapshot = store.previousSnapshotForTesting(
        exerciseName: exercise.name,
        routineName: routine.name,
        setPosition: 1,
      );
      expect(snapshot, isNull);

      // Best snapshots should still include an all-scope entry (all routines
      // include No Routine) AND a no_routine-scope entry, but not a
      // routine-scope entry pinned to any routine id.
      final bests = store.bestSnapshotsForTesting(exerciseName: exercise.name);
      expect(bests.any((b) => b.sourceType == 'all'), isTrue);
      expect(bests.any((b) => b.sourceType == 'no_routine'), isTrue);
      expect(
        bests.any((b) => b.sourceType == 'routine' && b.routineId != null),
        isFalse,
      );
    },
  );

  test(
    'sqlite store best snapshots track max weight and max volume (DB audit #8)',
    () async {
      final store = await openTestStore();
      final state = await store.load();
      final routine = state.groups.first.routines.first;
      final exercise = routine.exercises.first.exercise;

      // Set A: heavy but low volume -> should win Max Weight.
      // Set B: light but highest volume -> should win Max Volume.
      final workout = ActiveWorkout(
        sessionName: 'audit 8',
        source: routine.name,
        routineName: routine.name,
        routineGroupName: state.groups.first.name,
        exercises: [
          WorkoutExercise(exercise, null, [
            WorkoutSet(kgText: '100', repsText: '2')
              ..completed = true, // 200 vol
            WorkoutSet(kgText: '50', repsText: '20')
              ..completed = true, // 1000 vol
          ]),
        ],
      );
      await store.finishWorkout(workout);

      final bests = store.bestSnapshotsForTesting(exerciseName: exercise.name);

      final allWeight = bests.firstWhere(
        (b) => b.sourceType == 'all' && b.kind == 'weight',
      );
      final allVolume = bests.firstWhere(
        (b) => b.sourceType == 'all' && b.kind == 'volume',
      );
      expect(allWeight.kg, 100.0);
      expect(allWeight.reps, 2);
      expect(allVolume.kg, 50.0);
      expect(allVolume.reps, 20);
      expect(allVolume.volume, 1000.0);
    },
  );

  test('sqlite store seed covers every muscle map name', () async {
    final store = await openTestStore();
    final state = await store.load();

    final coveredMuscles = <String>{
      for (final exercise in state.exercises) exercise.muscle,
      for (final exercise in state.exercises) ...exercise.secondaryMuscles,
    };

    for (final muscle in const [
      'Chest',
      'Front Delt',
      'Side Delt',
      'Rear Delt',
      'Biceps',
      'Triceps',
      'Forearms',
      'Traps',
      'Rhomboids',
      'Lats',
      'Abs',
      'Quads',
      'Glutes',
      'Hamstrings',
      'Calves',
    ]) {
      expect(
        coveredMuscles,
        contains(muscle),
        reason: 'seed exercises must reference $muscle',
      );
    }
  });

  test('new set falls back to current session completed set', () {
    final exercise = Exercise('Lat Pulldown', 'Lats', 'Cable');
    final workoutExercise = WorkoutExercise(exercise, 90, [
      WorkoutSet(kgText: '55', repsText: '10')..completed = true,
    ]);

    final next = workoutExercise.nextSetFromCurrentSession();

    expect(next.kg.text, '55');
    expect(next.reps.text, '10');
  });

  testWidgets('opens to workout screen', (tester) async {
    await pumpGymmer(tester);

    expect(find.text('GYMMER'), findsOneWidget);
    expect(find.text('Start Empty'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Push B'), findsOneWidget);
  });

  testWidgets('starting a routine shows folder and autofilled sets', (
    tester,
  ) async {
    await pumpGymmer(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Routine').first);
    await tester.pumpAndSettle();

    expect(find.text('Active Workout'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Workout Muscle Map'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Front Delt'), findsOneWidget);
    expect(find.text('Triceps'), findsOneWidget);
    expect(
      find.text('Chest primary / Front Delt, Triceps secondary / Dumbbell'),
      findsOneWidget,
    );
    expect(
      find.text('Previous 22.5kg x 9 / Autofilled from routine history'),
      findsOneWidget,
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[1].controller?.text, '22.5');
    expect(fields[2].controller?.text, '9');
  });

  testWidgets('exercise creation shows anatomy layers and media controls', (
    tester,
  ) async {
    await pumpGymmer(tester);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Create Exercise'), findsOneWidget);
    expect(find.text('Muscle Map'), findsNothing);
    expect(find.text('Anatomy'), findsOneWidget);
    final imageCountBefore = find.byType(Image).evaluate().length;
    await tester.tap(find.text('Front Delt'));
    await tester.pumpAndSettle();
    expect(find.byType(Image).evaluate().length, greaterThan(imageCountBefore));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Thumbnail'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
  });

  testWidgets('anatomy layer assets exist for every muscle', (tester) async {
    await rootBundle.load('assets/muscle_layers/base_front.png');
    await rootBundle.load('assets/muscle_layers/base_back.png');
    for (final muscle in const [
      'Chest',
      'Front_Delt',
      'Side_Delt',
      'Rear_Delt',
      'Biceps',
      'Triceps',
      'Forearms',
      'Traps',
      'Rhomboids',
      'Lats',
      'Abs',
      'Quads',
      'Glutes',
      'Hamstrings',
      'Calves',
    ]) {
      await rootBundle.load('assets/muscle_layers/${muscle}_front.png');
      await rootBundle.load('assets/muscle_layers/${muscle}_back.png');
      await rootBundle.load(
        'assets/muscle_layers/${muscle}_front_secondary.png',
      );
      await rootBundle.load(
        'assets/muscle_layers/${muscle}_back_secondary.png',
      );
      await rootBundle.load('assets/muscle_layers/${muscle}_front_mask.png');
      await rootBundle.load('assets/muscle_layers/${muscle}_back_mask.png');
    }
  });

  testWidgets('routine rest timer opens popup with 15 second controls', (
    tester,
  ) async {
    await pumpGymmer(tester);

    // Tapping a routine card opens its builder (the old per-card menu is gone).
    await tester.tap(find.text('Push A'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '1m 30s').first);
    await tester.pumpAndSettle();

    expect(find.text('Rest Timer'), findsOneWidget);
    expect(find.byTooltip('Increase 15 seconds'), findsOneWidget);
    expect(find.byTooltip('Decrease 15 seconds'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase 15 seconds'));
    await tester.pump();
    expect(find.text('1m 45s'), findsOneWidget);
  });

  testWidgets('new routine can be saved into a new folder', (tester) async {
    await pumpGymmer(tester);

    await tester.tap(find.byTooltip('New Routine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Leg Day');
    await tester.enterText(find.byType(TextField).at(1), 'Legs');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Legs'), 500);
    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
  });

  testWidgets('exercise library opens an existing exercise for editing', (
    tester,
  ) async {
    await pumpGymmer(tester);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    // Narrow the list via the search field so the row is on-screen and
    // hittable regardless of catalog size.
    // Search 'Cable' so both the original and the renamed exercise remain
    // visible after the edit (the search field keeps filtering on pop-back).
    await tester.enterText(find.byType(TextField).first, 'Cable');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cable Lateral Raise'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Exercise'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Cable Side Raise');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cable Side Raise'), findsOneWidget);
    expect(find.text('Cable Lateral Raise'), findsNothing);
  });

  testWidgets('routine folder can be renamed from the workout screen', (
    tester,
  ) async {
    await pumpGymmer(tester);

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Upper');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Upper'), findsOneWidget);
    expect(find.text('Push'), findsNothing);
  });

  testWidgets(
    'active workout supports session rename, replace, and set delete',
    (tester) async {
      // Tall surface so the whole active-workout page (header + muscle map +
      // exercise cards) fits without scrolling, keeping swipe action buttons
      // on-screen and hittable.
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpGymmer(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Start Routine').first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Heavy Push');
      await tester.pump();

      // Replace is now a swipe-left action on the exercise card. Use a stepped
      // gesture so the horizontal drag wins the arena and the pane latches open.
      final swipeCard = await tester.startGesture(
        tester.getCenter(find.text('Incline Dumbbell Press')),
      );
      await swipeCard.moveBy(const Offset(-30, 0));
      await tester.pump();
      await swipeCard.moveBy(const Offset(-450, 0));
      await tester.pump();
      await swipeCard.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      final latPulldownInPicker = find.descendant(
        of: find.byType(ExercisePickerPage),
        matching: find.text('Lat Pulldown'),
      );
      await tester.scrollUntilVisible(
        latPulldownInPicker,
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(latPulldownInPicker, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ActiveWorkoutPage),
          matching: find.text('Lat Pulldown'),
        ),
        findsOneWidget,
      );

      // Delete Set is now a swipe-left action on the set row (drag the
      // non-editable "Set 1" label so the gesture reaches the Slidable).
      await tester.drag(find.text('Set 1').first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Set 1'), findsWidgets);

      expect(find.text('Heavy Push'), findsOneWidget);
    },
  );
}
