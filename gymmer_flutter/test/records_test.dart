import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/domain/records_service.dart';
import 'package:gymmer_flutter/models.dart';

CompletedWorkout _wk(
  String exercise,
  DateTime start,
  List<(double, int)> sets,
) {
  return CompletedWorkout(
    sessionName: 's',
    routineName: null,
    routineGroupName: null,
    startedAt: start,
    completedAt: start.add(const Duration(hours: 1)),
    exercises: [
      CompletedWorkoutExercise(
        exerciseName: exercise,
        sets: [for (final s in sets) (kg: s.$1, reps: s.$2)],
      ),
    ],
  );
}

void main() {
  final day1 = DateTime(2026, 7, 1);
  final day2 = DateTime(2026, 7, 2);

  test('every set of the first-ever session is a record', () {
    final w = _wk('Bench', day1, [(100, 5), (100, 5)]);
    expect(recordsIn(w, [w]), 2);
  });

  test('a later session beating max kg by 2.5 → 1 record', () {
    final earlier = _wk('Bench', day1, [(100, 5)]);
    final later = _wk('Bench', day2, [(102.5, 5)]);
    expect(recordsIn(later, [earlier, later]), 1);
  });

  test('a tie is not a record', () {
    final earlier = _wk('Bench', day1, [(100, 5)]);
    final later = _wk('Bench', day2, [(100, 5)]);
    expect(recordsIn(later, [earlier, later]), 0);
  });

  test('a later heavier session does not erase an old workout badge', () {
    final old = _wk('Bench', day1, [(100, 5)]);
    final heavier = _wk('Bench', day2, [(120, 5)]);
    final all = [old, heavier];
    expect(recordsIn(old, all), 1); // old was a record vs nothing earlier
    expect(recordsIn(heavier, all), 1);
  });

  test('statsFor: series ordered by date; absent exercise excluded', () {
    final all = [
      _wk('Bench', day2, [(102.5, 5)]),
      _wk('Bench', day1, [(100, 8)]),
    ];
    final stats = statsFor('Bench', all);
    expect(stats.totalSessions, 2);
    expect(stats.bestKg, 102.5);
    expect(stats.bestSetVolume, 100 * 8); // 800 > 102.5*5=512.5
    expect(stats.series.map((s) => s.date), [day1, day2]);

    final missing = statsFor('Nope', all);
    expect(missing.totalSessions, 0);
    expect(missing.series, isEmpty);
  });

  test('statsFor: per-session trend values and all-time records', () {
    final all = [
      _wk('Bench', DateTime(2026, 7, 3), [(30, 4), (20, 13)]),
      _wk('Bench', DateTime(2026, 7, 1), [(25, 6), (24, 10)]),
    ];

    final stats = statsFor('Bench', all);

    expect(stats.bestKg, 30);
    expect(stats.best1Rm, 34);
    expect(stats.bestSetVolume, 260);
    expect(stats.bestSetVolumeKg, 20);
    expect(stats.bestSetVolumeReps, 13);
    expect(stats.bestSessionVolume, 390);

    expect(stats.series.first.best1Rm, 32);
    expect(stats.series.first.bestSetVolume, 240);
    expect(stats.series.first.sessionVolume, 390);
    expect(stats.series.first.totalReps, 16);
    expect(stats.series.last.best1Rm, 34);
    expect(stats.series.last.bestSetVolume, 260);
    expect(stats.series.last.sessionVolume, 380);
    expect(stats.series.last.totalReps, 17);
  });
}
