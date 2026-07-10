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

String _slug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'item' : slug;
}
