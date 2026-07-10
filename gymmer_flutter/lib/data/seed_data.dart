import '../models.dart';

// The anatomy layer tool renders one mask per muscleMapNames entry; seed data
// no longer needs a parseable exercise-combo style.

List<Exercise> prototypeExercises() {
  return [
    Exercise('Incline Dumbbell Press', 'Chest', 'Dumbbell', [
      'Front Delt',
      'Triceps',
    ]),
    Exercise('Chest Press', 'Chest', 'Machine', ['Front Delt', 'Triceps']),
    Exercise('Cable Lateral Raise', 'Side Delt', 'Cable', ['Traps']),
    Exercise('Overhead Press', 'Front Delt', 'Barbell', [
      'Side Delt',
      'Triceps',
    ]),
    Exercise('Face Pull', 'Rear Delt', 'Cable', ['Rhomboids', 'Traps']),
    Exercise('Lat Pulldown', 'Lats', 'Cable', ['Biceps', 'Rhomboids']),
    Exercise('Barbell Row', 'Lats', 'Barbell', [
      'Rhomboids',
      'Rear Delt',
      'Biceps',
    ]),
    Exercise('Barbell Curl', 'Biceps', 'Barbell', ['Forearms']),
    Exercise('Triceps Rope Pushdown', 'Triceps', 'Cable'),
    Exercise('Cable Crunch', 'Abs', 'Cable'),
    Exercise('Hanging Leg Raise', 'Abs', 'Bodyweight'),
    Exercise('Barbell Back Squat', 'Quads', 'Barbell', [
      'Glutes',
      'Hamstrings',
    ]),
    Exercise('Romanian Deadlift', 'Hamstrings', 'Barbell', ['Glutes', 'Lats']),
    Exercise('Hip Thrust', 'Glutes', 'Barbell', ['Hamstrings']),
    Exercise('Standing Calf Raise', 'Calves', 'Machine'),
  ];
}

List<RoutineGroup> prototypeGroups(List<Exercise> exercises) {
  Exercise byName(String name) => exercises.firstWhere((e) => e.name == name);

  return [
    RoutineGroup('Push', [
      Routine('Push A', 'Chest and shoulder focus', [
        RoutineExercise(byName('Incline Dumbbell Press'), 3, 90),
        RoutineExercise(byName('Overhead Press'), 3, 90),
        RoutineExercise(byName('Triceps Rope Pushdown'), 3, 60),
        RoutineExercise(byName('Cable Lateral Raise'), 2, 60),
      ]),
      Routine('Push B', 'Machine press variation', [
        RoutineExercise(byName('Chest Press'), 3, 90),
        RoutineExercise(byName('Cable Lateral Raise'), 2, 60),
      ]),
    ]),
    RoutineGroup('Pull', [
      Routine('Pull A', 'Back and biceps', [
        RoutineExercise(byName('Lat Pulldown'), 3, 90),
        RoutineExercise(byName('Barbell Row'), 3, 120),
        RoutineExercise(byName('Face Pull'), 3, 60),
        RoutineExercise(byName('Barbell Curl'), 3, 60),
      ]),
    ]),
    RoutineGroup('Legs', [
      Routine('Legs A', 'Quad-focused', [
        RoutineExercise(byName('Barbell Back Squat'), 4, 120),
        RoutineExercise(byName('Romanian Deadlift'), 3, 120),
        RoutineExercise(byName('Standing Calf Raise'), 3, 60),
      ]),
      Routine('Legs B', 'Glute-focused', [
        RoutineExercise(byName('Hip Thrust'), 4, 90),
        RoutineExercise(byName('Romanian Deadlift'), 3, 120),
        RoutineExercise(byName('Standing Calf Raise'), 3, 60),
      ]),
    ]),
    RoutineGroup('Core', [
      Routine('Core Finisher', 'Ab work after main lifts', [
        RoutineExercise(byName('Cable Crunch'), 3, 45),
        RoutineExercise(byName('Hanging Leg Raise'), 3, 60),
      ]),
    ]),
  ];
}

WorkoutHistory prototypeHistory(List<Exercise> exercises) {
  return WorkoutHistory.seeded(exercises);
}
