import '../domain/finish_workout_service.dart';
import '../models.dart';
import 'seed_data.dart';
import 'workout_store.dart';

Future<WorkoutStore> openPlatformWorkoutStore() async {
  return MemoryWorkoutStore.seeded();
}

class MemoryWorkoutStore implements WorkoutStore {
  MemoryWorkoutStore({
    required this.exercises,
    required this.groups,
    required this.history,
    List<CompletedWorkout>? completedWorkouts,
    this.activeWorkout,
  }) : completedWorkouts = completedWorkouts ?? [] {
    var maxId = 0;
    for (var i = 0; i < this.completedWorkouts.length; i++) {
      final workout = this.completedWorkouts[i];
      final id = workout.id ?? i + 1;
      maxId = id > maxId ? id : maxId;
      if (workout.id == null) {
        this.completedWorkouts[i] = _withId(workout, id);
      }
    }
    _nextCompletedWorkoutId = maxId + 1;
  }

  factory MemoryWorkoutStore.seeded() {
    final exercises = prototypeExercises();
    return MemoryWorkoutStore(
      exercises: exercises,
      groups: prototypeGroups(exercises),
      history: prototypeHistory(exercises),
      completedWorkouts: [_seededCompletedWorkout(exercises)],
    );
  }

  final List<Exercise> exercises;
  final List<RoutineGroup> groups;
  final WorkoutHistory history;
  final List<CompletedWorkout> completedWorkouts;
  ActiveWorkout? activeWorkout;
  late int _nextCompletedWorkoutId;

  /// One demo entry mirroring [WorkoutHistory.seeded] so the Profile feed is
  /// non-empty on web / in tests.
  static CompletedWorkout _seededCompletedWorkout(List<Exercise> exercises) {
    return CompletedWorkout(
      id: 1,
      sessionName: 'Push A',
      routineName: 'Push A',
      routineGroupName: 'Push',
      startedAt: DateTime(2026, 7, 4, 18),
      completedAt: DateTime(2026, 7, 4, 18, 25),
      exercises: [
        CompletedWorkoutExercise(
          exerciseName: exercises[0].name,
          sets: const [(kg: 22.5, reps: 9), (kg: 22.5, reps: 8)],
        ),
        CompletedWorkoutExercise(
          exerciseName: exercises[1].name,
          sets: const [(kg: 10, reps: 12)],
        ),
      ],
    );
  }

  @override
  Future<WorkoutStoreState> load() async {
    return WorkoutStoreState(
      exercises: exercises,
      groups: groups,
      history: history,
      activeWorkout: activeWorkout,
    );
  }

  @override
  Future<void> saveExercise(Exercise exercise, {String? originalName}) async {
    final lookupName = originalName ?? exercise.name;
    final index = exercises.indexWhere((item) => item.name == lookupName);
    if (index >= 0) {
      exercises[index] = exercise;
      _replaceExerciseReferences(lookupName, exercise);
      return;
    }
    if (exercises.any((item) => item.name == exercise.name)) return;
    exercises.add(exercise);
  }

  @override
  Future<void> setExerciseFavorite(String name, bool value) async {
    final index = exercises.indexWhere((item) => item.name == name);
    if (index >= 0) {
      exercises[index].isFavorite = value;
    }
  }

  @override
  Future<void> saveRoutine(
    Routine routine, {
    required String groupName,
    String? originalName,
  }) async {
    final group = groups.firstWhere(
      (item) => item.name == groupName,
      orElse: () {
        final created = RoutineGroup(groupName, []);
        groups.add(created);
        return created;
      },
    );
    final index = group.routines.indexWhere(
      (item) => item.name == (originalName ?? routine.name),
    );
    if (index >= 0) {
      group.routines[index] = routine;
    } else {
      group.routines.add(routine);
    }
  }

  @override
  Future<void> saveRoutineOrder(List<RoutineGroup> groups) async {}

  @override
  Future<void> renameRoutineGroup(String originalName, String newName) async {
    for (final group in groups) {
      if (group.name == originalName) {
        group.name = newName;
        return;
      }
    }
  }

  @override
  Future<void> deleteRoutineGroup(String groupName) async {
    groups.removeWhere(
      (group) => group.name == groupName && group.routines.isEmpty,
    );
  }

  @override
  Future<void> deleteRoutine(Routine routine) async {
    for (final group in groups) {
      group.routines.remove(routine);
    }
  }

  @override
  Future<void> saveActiveWorkout(ActiveWorkout workout) async {
    activeWorkout = workout;
  }

  @override
  Future<void> clearActiveWorkout() async {
    activeWorkout = null;
  }

  @override
  Future<void> finishWorkout(ActiveWorkout workout) async {
    history.recordWorkout(workout);
    if (completedSetEntriesForFinish(workout).isNotEmpty) {
      completedWorkouts.add(
        _withId(
          buildCompletedWorkout(workout, completedAt: DateTime.now()),
          _nextCompletedWorkoutId++,
        ),
      );
    }
    activeWorkout = null;
  }

  @override
  Future<List<CompletedWorkout>> loadCompletedWorkouts() async {
    return completedWorkouts.reversed.toList();
  }

  @override
  Future<void> updateCompletedExerciseSets(
    int sessionId,
    String exerciseName,
    List<({double kg, int reps})> sets,
  ) async {
    final workout = completedWorkouts.where((item) => item.id == sessionId);
    if (workout.isEmpty) return;
    final session = workout.first;
    final index = session.exercises.indexWhere(
      (item) => item.exerciseName == exerciseName,
    );
    if (index < 0) return;
    if (sets.isEmpty) {
      session.exercises.removeAt(index);
    } else {
      session.exercises[index] = CompletedWorkoutExercise(
        exerciseName: exerciseName,
        sets: [...sets],
      );
    }
    _rebuildHistoryFromCompletedWorkouts();
  }

  @override
  Future<void> updateCompletedWorkoutTimes(
    int sessionId,
    DateTime startedAt,
    DateTime completedAt,
  ) async {
    final index = completedWorkouts.indexWhere((item) => item.id == sessionId);
    if (index < 0) return;
    final workout = completedWorkouts[index];
    completedWorkouts[index] = CompletedWorkout(
      id: workout.id,
      sessionName: workout.sessionName,
      routineName: workout.routineName,
      routineGroupName: workout.routineGroupName,
      startedAt: startedAt,
      completedAt: completedAt,
      exercises: workout.exercises,
    );
    _rebuildHistoryFromCompletedWorkouts();
  }

  final List<MeasurementEntry> measurements = [];

  @override
  Future<List<MeasurementEntry>> loadMeasurements() async {
    final sorted = [...measurements]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  @override
  Future<void> saveMeasurement(MeasurementEntry entry) async {
    final key = _dateKey(entry.date);
    measurements.removeWhere((m) => _dateKey(m.date) == key);
    measurements.add(entry);
  }

  @override
  Future<void> deleteMeasurement(DateTime date) async {
    final key = _dateKey(date);
    measurements.removeWhere((m) => _dateKey(m.date) == key);
  }

  DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<void> close() async {}

  void _replaceExerciseReferences(String originalName, Exercise updated) {
    for (final group in groups) {
      for (final routine in group.routines) {
        for (var i = 0; i < routine.exercises.length; i++) {
          final item = routine.exercises[i];
          if (item.exercise.name == originalName) {
            routine.exercises[i] = RoutineExercise(
              updated,
              item.sets,
              item.restSeconds,
            );
          }
        }
      }
    }
    final workout = activeWorkout;
    if (workout == null) return;
    for (var i = 0; i < workout.exercises.length; i++) {
      final item = workout.exercises[i];
      if (item.exercise.name == originalName) {
        workout.exercises[i] = WorkoutExercise(
          updated,
          item.restSeconds,
          item.sets,
        );
      }
    }
  }

  static CompletedWorkout _withId(CompletedWorkout workout, int id) {
    return CompletedWorkout(
      id: id,
      sessionName: workout.sessionName,
      routineName: workout.routineName,
      routineGroupName: workout.routineGroupName,
      startedAt: workout.startedAt,
      completedAt: workout.completedAt,
      exercises: workout.exercises,
    );
  }

  void _rebuildHistoryFromCompletedWorkouts() {
    history.records
      ..clear()
      ..addAll([
        for (final workout in completedWorkouts)
          for (final exercise in workout.exercises)
            for (var index = 0; index < exercise.sets.length; index++)
              CompletedSetRecord(
                exerciseName: exercise.exerciseName,
                routineName: workout.routineName ?? 'No Routine',
                routineGroupName: workout.routineGroupName ?? 'No Group',
                setPosition: index + 1,
                kg: exercise.sets[index].kg,
                reps: exercise.sets[index].reps,
                completedAt: workout.completedAt.add(Duration(seconds: index)),
              ),
      ]);
  }
}
