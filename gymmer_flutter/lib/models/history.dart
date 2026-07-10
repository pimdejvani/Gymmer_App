/// Completed-history entities: immutable records of finished sets, plus the
/// in-memory history queries (previousFor) used for Previous autofill.
///
/// Completed history is the source of truth; snapshot tables in the SQLite
/// store are rebuildable caches over these records.
library;

import '../domain/finish_workout_service.dart';
import 'exercise.dart';
import 'workout.dart';

class WorkoutHistory {
  WorkoutHistory(this.records);

  factory WorkoutHistory.seeded(List<Exercise> exercises) {
    return WorkoutHistory([
      CompletedSetRecord(
        exerciseName: exercises[0].name,
        routineName: 'Push A',
        routineGroupName: 'Push',
        setPosition: 1,
        kg: 22.5,
        reps: 9,
        completedAt: DateTime(2026, 7, 4, 18),
      ),
      CompletedSetRecord(
        exerciseName: exercises[0].name,
        routineName: 'Push A',
        routineGroupName: 'Push',
        setPosition: 2,
        kg: 22.5,
        reps: 8,
        completedAt: DateTime(2026, 7, 4, 18, 5),
      ),
      CompletedSetRecord(
        exerciseName: exercises[1].name,
        routineName: 'Push A',
        routineGroupName: 'Push',
        setPosition: 1,
        kg: 10,
        reps: 12,
        completedAt: DateTime(2026, 7, 4, 18, 20),
      ),
    ]);
  }

  final List<CompletedSetRecord> records;

  CompletedSetRecord? previousFor({
    required String exerciseName,
    required String routineName,
    required int setPosition,
  }) {
    final matches =
        records
            .where(
              (record) =>
                  record.exerciseName == exerciseName &&
                  record.routineName == routineName &&
                  record.setPosition == setPosition,
            )
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return matches.isEmpty ? null : matches.first;
  }

  /// Records every completed, valid set from [workout] into history.
  ///
  /// The rule for which sets qualify (and the "No Routine" / "No Group"
  /// fallback naming) lives in `domain/finish_workout_service.dart`, shared
  /// with the SQLite store so both stores apply the exact same finish-workout
  /// rule.
  void recordWorkout(ActiveWorkout workout) {
    records.addAll(buildCompletedSetRecords(workout));
  }
}

class CompletedSetRecord {
  CompletedSetRecord({
    required this.exerciseName,
    required this.routineName,
    required this.routineGroupName,
    required this.setPosition,
    required this.kg,
    required this.reps,
    required this.completedAt,
  });

  final String exerciseName;
  final String routineName;
  final String routineGroupName;
  final int setPosition;
  final double kg;
  final int reps;
  final DateTime completedAt;

  String get kgText {
    if (kg == kg.roundToDouble()) return kg.toStringAsFixed(0);
    return kg.toString();
  }
}
