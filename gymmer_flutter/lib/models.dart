/// Barrel for all domain models. Import this from screens/data code;
/// the actual entities live in `models/` split by concern:
///
/// - `models/exercise.dart` — Exercise, ExerciseMedia
/// - `models/routine.dart`  — RoutineGroup, Routine, RoutineExercise
/// - `models/workout.dart`  — ActiveWorkout, WorkoutExercise, WorkoutSet
/// - `models/history.dart`  — WorkoutHistory, CompletedSetRecord
library;

export 'models/completed_workout.dart';
export 'models/exercise.dart';
export 'models/history.dart';
export 'models/measurement.dart';
export 'models/routine.dart';
export 'models/workout.dart';
