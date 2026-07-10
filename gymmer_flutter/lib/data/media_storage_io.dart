import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> copyExerciseMedia(
  String sourcePath, {
  required String exerciseName,
  required String kind,
}) async {
  if (sourcePath.trim().isEmpty || !p.isAbsolute(sourcePath)) {
    return sourcePath;
  }
  final source = File(sourcePath);
  if (!await source.exists()) return sourcePath;

  final documents = await getApplicationDocumentsDirectory();
  final exerciseSlug = _slug(exerciseName);
  final fileName = p.basename(sourcePath);
  final relativeParts = [
    'exercise_media',
    exerciseSlug,
    '${DateTime.now().millisecondsSinceEpoch}_${_slug(kind)}_$fileName',
  ];
  final target = File(p.joinAll([documents.path, ...relativeParts]));
  await target.parent.create(recursive: true);
  await source.copy(target.path);
  return relativeParts.join('/');
}

/// Resolves a stored media path to an absolute file path on disk, or null if
/// the file is missing. Freshly-picked absolute paths are used as-is; app-owned
/// relative paths (as returned by [copyExerciseMedia]) are joined onto the
/// documents directory.
Future<String?> resolveMediaPath(String storedPath) async {
  if (storedPath.trim().isEmpty) return null;
  if (p.isAbsolute(storedPath)) {
    return await File(storedPath).exists() ? storedPath : null;
  }
  final documents = await getApplicationDocumentsDirectory();
  final absolute = p.join(documents.path, storedPath);
  return await File(absolute).exists() ? absolute : null;
}

String _slug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'item' : slug;
}
