/// Library tab: scrollable exercise catalog with a search field and per-row
/// favorite star. Tapping a row (or the + button) opens CreateExercisePage;
/// saving flows back through onSaveExercise to the store owned by the home
/// shell. Toggling a star flows back through onToggleFavorite the same way.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_anatomy_panel.dart';
import '../widgets/exercise_media.dart';
import '../widgets/shared_widgets.dart';
import 'create_exercise_page.dart';

/// Filters [exercises] by a case-insensitive name-contains [query] (empty =
/// all) and sorts favorites to the top while preserving the original order
/// within each group. Shared by the library and the exercise picker.
List<Exercise> filterAndSortExercises(List<Exercise> exercises, String query) {
  final trimmed = query.trim().toLowerCase();
  final filtered = trimmed.isEmpty
      ? List<Exercise>.from(exercises)
      : exercises.where((e) => e.name.toLowerCase().contains(trimmed)).toList();
  // Stable partition: favorites keep their relative order, then the rest.
  final favorites = filtered.where((e) => e.isFavorite).toList();
  final others = filtered.where((e) => !e.isFavorite).toList();
  return [...favorites, ...others];
}

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({
    super.key,
    required this.exercises,
    required this.onSaveExercise,
    required this.onToggleFavorite,
  });

  final List<Exercise> exercises;
  final Future<void> Function(Exercise exercise, {String? originalName})
  onSaveExercise;
  final Future<void> Function(Exercise exercise, bool value) onToggleFavorite;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  String _query = '';
  String? _expandedName;

  Future<void> addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const CreateExercisePage()),
    );
    if (!mounted || exercise == null) return;
    await widget.onSaveExercise(exercise);
    setState(() {
      if (!widget.exercises.any((item) => item.name == exercise.name)) {
        widget.exercises.add(exercise);
      }
    });
  }

  Future<void> editExercise(Exercise original) async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => CreateExercisePage(exercise: original)),
    );
    if (!mounted || exercise == null) return;
    await widget.onSaveExercise(exercise, originalName: original.name);
    setState(() {
      final index = widget.exercises.indexOf(original);
      if (index >= 0) {
        // Preserve the favorite flag across an edit.
        exercise.isFavorite = original.isFavorite;
        widget.exercises[index] = exercise;
      }
    });
  }

  Future<void> toggleFavorite(Exercise exercise) async {
    final next = !exercise.isFavorite;
    setState(() => exercise.isFavorite = next);
    await widget.onToggleFavorite(exercise, next);
  }

  @override
  Widget build(BuildContext context) {
    final visible = filterAndSortExercises(widget.exercises, _query);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Add Exercise',
            onPressed: addExercise,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ExerciseSearchField(
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final exercise = visible[index];
                final expanded = _expandedName == exercise.name;
                return SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: exercise.thumbnailPath == null
                              ? Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    exercise.name.characters.first,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                )
                              : ExerciseMediaThumb(
                                  key: ValueKey(exercise.thumbnailPath),
                                  path: exercise.thumbnailPath!,
                                  isVideo: false,
                                  openOnTap: false,
                                ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            [
                              '${exercise.muscleSummary} / ${exercise.equipment}',
                              if (exercise.media.isNotEmpty)
                                '${exercise.media.length} media item${exercise.media.length == 1 ? '' : 's'}',
                            ].join('\n'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: expanded
                                    ? 'Hide anatomy'
                                    : 'Show anatomy',
                                onPressed: () => setState(
                                  () => _expandedName = expanded
                                      ? null
                                      : exercise.name,
                                ),
                                icon: Icon(
                                  Icons.accessibility_new,
                                  color: expanded
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                              ),
                              IconButton(
                                tooltip: exercise.isFavorite
                                    ? 'Unfavorite'
                                    : 'Favorite',
                                onPressed: () => toggleFavorite(exercise),
                                icon: Icon(
                                  exercise.isFavorite
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: exercise.isFavorite
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textTertiary,
                              ),
                            ],
                          ),
                          onTap: () => editExercise(exercise),
                        ),
                      ),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: ExerciseAnatomyPanel(
                            exercise: exercise,
                            height: 200,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned search field used by the library and the exercise picker.
class ExerciseSearchField extends StatelessWidget {
  const ExerciseSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Search exercises',
        prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
      ),
    );
  }
}
