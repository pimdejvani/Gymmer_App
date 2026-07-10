import 'workout_store.dart';
import 'workout_store_memory.dart'
    if (dart.library.io) 'workout_store_sqlite.dart';

Future<WorkoutStore> openWorkoutStore() {
  return openPlatformWorkoutStore();
}
