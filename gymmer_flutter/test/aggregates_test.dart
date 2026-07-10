import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/domain/workout_aggregates.dart';
import 'package:gymmer_flutter/models.dart';

CompletedWorkout _wk({
  required DateTime start,
  Duration dur = const Duration(minutes: 30),
  List<CompletedWorkoutExercise>? exercises,
}) {
  return CompletedWorkout(
    sessionName: 'x',
    routineName: null,
    routineGroupName: null,
    startedAt: start,
    completedAt: start.add(dur),
    exercises:
        exercises ??
        [
          CompletedWorkoutExercise(
            exerciseName: 'E',
            sets: const [(kg: 10, reps: 5)],
          ),
        ],
  );
}

void main() {
  // 2026-07-08 is a Wednesday; that week's Monday is 2026-07-06.
  final now = DateTime(2026, 7, 8);

  test('two workouts in the same week merge into one bucket', () {
    final weeks = weeklyTotals(
      [
        _wk(start: DateTime(2026, 7, 6), dur: const Duration(minutes: 30)),
        _wk(start: DateTime(2026, 7, 8), dur: const Duration(minutes: 45)),
      ],
      ProgressMetric.duration,
      now: now,
      weeks: 1,
    );
    expect(weeks, hasLength(1));
    expect(weeks.single.value, 75);
  });

  test('Sunday and Monday split across the week boundary', () {
    final weeks = weeklyTotals(
      [
        _wk(start: DateTime(2026, 7, 5), dur: const Duration(minutes: 20)),
        _wk(start: DateTime(2026, 7, 6), dur: const Duration(minutes: 40)),
      ],
      ProgressMetric.duration,
      now: now,
      weeks: 2,
    );
    expect(weeks, hasLength(2));
    expect(weeks[0].weekStart, DateTime(2026, 6, 29));
    expect(weeks[0].value, 20); // Sunday 5 Jul belongs to previous week
    expect(weeks[1].weekStart, DateTime(2026, 7, 6));
    expect(weeks[1].value, 40); // Monday 6 Jul is the current week
  });

  test('zero-fills every week and matches the requested length', () {
    final weeks = weeklyTotals([], ProgressMetric.volume, now: now, weeks: 12);
    expect(weeks, hasLength(12));
    expect(weeks.every((w) => w.value == 0), isTrue);
  });

  test('metric math: duration minutes, volume, reps', () {
    final workout = _wk(
      start: DateTime(2026, 7, 6),
      dur: const Duration(minutes: 40),
      exercises: [
        CompletedWorkoutExercise(
          exerciseName: 'A',
          sets: const [(kg: 50, reps: 10), (kg: 50, reps: 8)],
        ),
        CompletedWorkoutExercise(
          exerciseName: 'B',
          sets: const [(kg: 20, reps: 12)],
        ),
      ],
    );

    expect(
      weeklyTotals(
        [workout],
        ProgressMetric.duration,
        now: now,
        weeks: 1,
      ).single.value,
      40,
    );
    expect(
      weeklyTotals(
        [workout],
        ProgressMetric.volume,
        now: now,
        weeks: 1,
      ).single.value,
      50 * 10 + 50 * 8 + 20 * 12, // 1140
    );
    expect(
      weeklyTotals(
        [workout],
        ProgressMetric.reps,
        now: now,
        weeks: 1,
      ).single.value,
      10 + 8 + 12, // 30
    );
  });

  test('thisWeekDuration sums only the current week', () {
    final total = thisWeekDuration([
      _wk(start: DateTime(2026, 7, 6), dur: const Duration(minutes: 30)),
      _wk(start: DateTime(2026, 7, 8), dur: const Duration(minutes: 45)),
      _wk(start: DateTime(2026, 6, 30), dur: const Duration(minutes: 99)),
    ], now: now);
    expect(total, const Duration(minutes: 75));
  });
}
