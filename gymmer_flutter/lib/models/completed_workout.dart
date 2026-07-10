/// A finished workout as shown in the Profile feed and detail page. Built
/// from an [ActiveWorkout] at finish time (see `buildCompletedWorkout` in
/// `domain/finish_workout_service.dart`) and loaded back from the store.
library;

class CompletedWorkout {
  CompletedWorkout({
    this.id,
    required this.sessionName,
    required this.routineName,
    required this.routineGroupName,
    required this.startedAt,
    required this.completedAt,
    required this.exercises,
  });

  final int? id;
  final String sessionName;
  final String? routineName;
  final String? routineGroupName;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<CompletedWorkoutExercise> exercises;

  Duration get duration => completedAt.difference(startedAt);

  double get totalVolumeKg =>
      exercises.fold(0, (sum, exercise) => sum + exercise.volumeKg);

  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);
}

class CompletedWorkoutExercise {
  CompletedWorkoutExercise({required this.exerciseName, required this.sets});

  final String exerciseName;
  final List<({double kg, int reps})> sets;

  double get volumeKg => sets.fold(0, (sum, set) => sum + set.kg * set.reps);
}
