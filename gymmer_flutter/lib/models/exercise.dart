/// Exercise catalog entities: what an exercise is, independent of any
/// routine or workout session.
library;

class Exercise {
  Exercise(
    this.name,
    this.muscle,
    this.equipment, [
    this.secondaryMuscles = const [],
    this.thumbnailPath,
    this.media = const [],
    this.isFavorite = false,
  ]);

  final String name;
  final String muscle;
  final String equipment;
  final List<String> secondaryMuscles;
  final String? thumbnailPath;
  final List<ExerciseMedia> media;
  bool isFavorite;

  String get muscleSummary {
    if (secondaryMuscles.isEmpty) return muscle;
    return '$muscle primary / ${secondaryMuscles.join(', ')} secondary';
  }
}

class ExerciseMedia {
  const ExerciseMedia({required this.path, required this.type});

  final String path;
  final ExerciseMediaType type;
}

enum ExerciseMediaType { image, video }
