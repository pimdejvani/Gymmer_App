import '../models.dart';

/// One set from an in-progress [ActiveWorkout] that qualifies to be recorded
/// into history when the workout is finished.
///
/// A set qualifies only when it has been marked `completed` and its kg/reps
/// values are valid (see [WorkoutSet.canComplete]). This is the single source
/// of truth for that rule; the SQLite store and the in-memory store both use
/// it so they can never disagree about which sets get persisted.
class CompletedSetEntry {
  const CompletedSetEntry({
    required this.exercise,
    required this.position,
    required this.set,
  });

  final WorkoutExercise exercise;

  /// 1-based set position within [exercise].
  final int position;
  final WorkoutSet set;

  double get kg => double.parse(set.kg.text.trim());
  int get reps => int.parse(set.reps.text.trim());
}

/// Applies the finish-workout completed-set rule to [workout] and returns
/// every set that should be persisted to history, in the same order the
/// workout stores them.
List<CompletedSetEntry> completedSetEntriesForFinish(ActiveWorkout workout) {
  final entries = <CompletedSetEntry>[];
  for (final exercise in workout.exercises) {
    for (var index = 0; index < exercise.sets.length; index++) {
      final set = exercise.sets[index];
      if (set.completed && set.canComplete) {
        entries.add(
          CompletedSetEntry(exercise: exercise, position: index + 1, set: set),
        );
      }
    }
  }
  return entries;
}

/// Builds the [CompletedWorkout] view (Profile feed / detail) from [workout],
/// applying the exact same qualifying-set rule as [buildCompletedSetRecords]
/// (incomplete/invalid sets are skipped, exercise order is preserved).
CompletedWorkout buildCompletedWorkout(
  ActiveWorkout workout, {
  required DateTime completedAt,
}) {
  final exercises = <CompletedWorkoutExercise>[];
  final setsByExercise = <WorkoutExercise, List<({double kg, int reps})>>{};
  for (final entry in completedSetEntriesForFinish(workout)) {
    final sets = setsByExercise.putIfAbsent(entry.exercise, () {
      final list = <({double kg, int reps})>[];
      exercises.add(
        CompletedWorkoutExercise(
          exerciseName: entry.exercise.exercise.name,
          sets: list,
        ),
      );
      return list;
    });
    sets.add((kg: entry.kg, reps: entry.reps));
  }
  return CompletedWorkout(
    sessionName: workout.sessionName,
    routineName: workout.routineName,
    routineGroupName: workout.routineGroupName,
    startedAt: workout.startedAt,
    completedAt: completedAt,
    exercises: exercises,
  );
}

/// Builds the [CompletedSetRecord] rows that finishing [workout] should add
/// to history, applying the "No Routine" / "No Group" fallback naming rule.
List<CompletedSetRecord> buildCompletedSetRecords(
  ActiveWorkout workout, {
  DateTime? completedAt,
}) {
  final routineName = workout.routineName ?? 'No Routine';
  final routineGroupName = workout.routineGroupName ?? 'No Group';
  final resolvedCompletedAt = completedAt ?? DateTime.now();
  return [
    for (final entry in completedSetEntriesForFinish(workout))
      CompletedSetRecord(
        exerciseName: entry.exercise.exercise.name,
        routineName: routineName,
        routineGroupName: routineGroupName,
        setPosition: entry.position,
        kg: entry.kg,
        reps: entry.reps,
        completedAt: resolvedCompletedAt,
      ),
  ];
}
