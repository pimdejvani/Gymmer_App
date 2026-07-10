import '../models.dart';

class WorkoutStoreState {
  const WorkoutStoreState({
    required this.exercises,
    required this.groups,
    required this.history,
    required this.activeWorkout,
  });

  final List<Exercise> exercises;
  final List<RoutineGroup> groups;
  final WorkoutHistory history;
  final ActiveWorkout? activeWorkout;
}

abstract class WorkoutStore {
  Future<WorkoutStoreState> load();

  Future<void> saveExercise(Exercise exercise, {String? originalName});

  Future<void> setExerciseFavorite(String name, bool value);

  Future<void> saveRoutine(
    Routine routine, {
    required String groupName,
    String? originalName,
  });

  Future<void> saveRoutineOrder(List<RoutineGroup> groups);

  Future<void> renameRoutineGroup(String originalName, String newName);

  Future<void> deleteRoutineGroup(String groupName);

  Future<void> deleteRoutine(Routine routine);

  Future<void> saveActiveWorkout(ActiveWorkout workout);

  Future<void> clearActiveWorkout();

  Future<void> finishWorkout(ActiveWorkout workout);

  /// Finished workouts, newest first, for the Profile feed. Loaded lazily
  /// when the Profile tab opens — not part of [WorkoutStoreState].
  Future<List<CompletedWorkout>> loadCompletedWorkouts();

  /// Replaces the recorded sets of [exerciseName] inside completed session
  /// [sessionId]. Sets are renumbered 1..n; an empty list removes the exercise
  /// from that session. Implementations must refresh derived caches.
  Future<void> updateCompletedExerciseSets(
    int sessionId,
    String exerciseName,
    List<({double kg, int reps})> sets,
  );

  /// Updates the start/end timestamps (and therefore the duration) of completed
  /// session [sessionId].
  Future<void> updateCompletedWorkoutTimes(
    int sessionId,
    DateTime startedAt,
    DateTime completedAt,
  );

  /// Body measurements, newest first.
  Future<List<MeasurementEntry>> loadMeasurements();

  /// Upserts a measurement entry keyed by its calendar date.
  Future<void> saveMeasurement(MeasurementEntry entry);

  /// Removes the measurement entry logged on [date].
  Future<void> deleteMeasurement(DateTime date);

  Future<void> close();
}
