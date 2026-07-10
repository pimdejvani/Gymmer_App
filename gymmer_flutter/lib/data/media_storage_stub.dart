Future<String> copyExerciseMedia(
  String sourcePath, {
  required String exerciseName,
  required String kind,
}) async {
  return sourcePath;
}

Future<String?> resolveMediaPath(String storedPath) async {
  return storedPath.trim().isEmpty ? null : storedPath;
}
