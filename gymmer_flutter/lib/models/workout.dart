/// Live workout-session entities: the one active workout, its exercises and
/// sets (backed by TextEditingControllers while the user types), and the
/// session-name timestamp format.
library;

import 'package:flutter/material.dart';

import 'exercise.dart';
import 'history.dart';
import 'routine.dart';

class ActiveWorkout {
  ActiveWorkout({
    required this.sessionName,
    required this.source,
    required this.exercises,
    required this.routineName,
    required this.routineGroupName,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  factory ActiveWorkout.noRoutine() {
    return ActiveWorkout(
      sessionName: 'No Routine ${formatSessionTimestamp(DateTime.now())}',
      source: 'No Routine',
      exercises: [],
      routineName: null,
      routineGroupName: null,
    );
  }

  factory ActiveWorkout.fromRoutine(
    Routine routine, {
    required String groupName,
    required WorkoutHistory history,
  }) {
    return ActiveWorkout(
      sessionName: '${routine.name} ${formatSessionTimestamp(DateTime.now())}',
      source: routine.name,
      routineName: routine.name,
      routineGroupName: groupName,
      exercises: routine.exercises
          .map(
            (routineExercise) => WorkoutExercise.fromRoutine(
              routineExercise,
              routineName: routine.name,
              history: history,
            ),
          )
          .toList(),
    );
  }

  String sessionName;
  final String source;
  final String? routineName;
  final String? routineGroupName;
  final DateTime startedAt;
  final List<WorkoutExercise> exercises;

  void dispose() {
    for (final exercise in exercises) {
      exercise.dispose();
    }
  }
}

class WorkoutExercise {
  WorkoutExercise(this.exercise, this.restSeconds, this.sets);

  factory WorkoutExercise.fromRoutine(
    RoutineExercise source, {
    required String routineName,
    required WorkoutHistory history,
  }) {
    return WorkoutExercise(
      source.exercise,
      source.restSeconds,
      List.generate(source.sets, (index) {
        final previous = history.previousFor(
          exerciseName: source.exercise.name,
          routineName: routineName,
          setPosition: index + 1,
        );
        return WorkoutSet.fromPrevious(previous);
      }),
    );
  }

  factory WorkoutExercise.fromExercise(Exercise exercise) {
    return WorkoutExercise(exercise, null, [WorkoutSet()]);
  }

  final Exercise exercise;
  int? restSeconds;
  final List<WorkoutSet> sets;

  WorkoutSet nextSetFromCurrentSession() {
    for (final set in sets.reversed) {
      if (set.completed && set.canComplete) {
        return WorkoutSet(
          kgText: set.kg.text.trim(),
          repsText: set.reps.text.trim(),
          previousLabel: '${set.kg.text.trim()}kg x ${set.reps.text.trim()}',
        );
      }
    }
    return WorkoutSet();
  }

  String get statsLabel {
    final previous = sets.where((set) => set.previousLabel != null).toList();
    if (previous.isEmpty) return 'No previous values yet';
    final first = previous.first.previousLabel!;
    return 'Previous $first / Autofilled from routine history';
  }

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class WorkoutSet {
  WorkoutSet({String? kgText, String? repsText, this.previousLabel})
    : kg = TextEditingController(text: kgText ?? ''),
      reps = TextEditingController(text: repsText ?? '');

  factory WorkoutSet.fromPrevious(CompletedSetRecord? previous) {
    if (previous == null) return WorkoutSet();
    return WorkoutSet(
      kgText: previous.kgText,
      repsText: previous.reps.toString(),
      previousLabel: '${previous.kgText}kg x ${previous.reps}',
    );
  }

  final TextEditingController kg;
  final TextEditingController reps;
  final String? previousLabel;
  bool completed = false;

  bool get canComplete {
    final kgValue = double.tryParse(kg.text.trim());
    final repsValue = int.tryParse(reps.text.trim());
    return kgValue != null &&
        kgValue >= 0 &&
        repsValue != null &&
        repsValue > 0;
  }

  void dispose() {
    kg.dispose();
    reps.dispose();
  }
}

String formatSessionTimestamp(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '${value.day} ${months[value.month - 1]} $hour $period';
}
