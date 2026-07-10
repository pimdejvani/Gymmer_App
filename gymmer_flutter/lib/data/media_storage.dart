import 'media_storage_stub.dart' if (dart.library.io) 'media_storage_io.dart';

Future<String> copyExerciseMediaIntoAppStorage(
  String sourcePath, {
  required String exerciseName,
  required String kind,
}) {
  return copyExerciseMedia(sourcePath, exerciseName: exerciseName, kind: kind);
}

/// Resolves a stored media path (see [copyExerciseMediaIntoAppStorage]) to an
/// absolute file path for display, or null if the file no longer exists.
Future<String?> resolveExerciseMediaPath(String storedPath) {
  return resolveMediaPath(storedPath);
}
