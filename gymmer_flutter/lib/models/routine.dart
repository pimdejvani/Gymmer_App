/// Routine planning entities: reusable workout plans organized in folders
/// (RoutineGroup). A routine defines exercises, order, set counts, and rest
/// timers — never planned weights/reps (those come from history at runtime).
library;

import 'exercise.dart';

class RoutineGroup {
  RoutineGroup(this.name, this.routines);

  String name;
  final List<Routine> routines;
}

class Routine {
  Routine(this.name, this.note, this.exercises);

  String name;
  String note;
  final List<RoutineExercise> exercises;

  Routine copy() {
    return Routine(
      name,
      note,
      exercises
          .map(
            (item) =>
                RoutineExercise(item.exercise, item.sets, item.restSeconds),
          )
          .toList(),
    );
  }
}

class RoutineExercise {
  RoutineExercise(this.exercise, this.sets, this.restSeconds);

  final Exercise exercise;
  int sets;
  int? restSeconds;
}
