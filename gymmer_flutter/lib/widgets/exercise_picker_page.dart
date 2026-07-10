import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/exercise_library_page.dart'
    show ExerciseSearchField, filterAndSortExercises;
import 'shared_widgets.dart';

class ExercisePickerPage extends StatefulWidget {
  const ExercisePickerPage({
    super.key,
    required this.exercises,
    required this.mode,
  });

  final List<Exercise> exercises;
  final PickerMode mode;

  @override
  State<ExercisePickerPage> createState() => _ExercisePickerPageState();
}

class _ExercisePickerPageState extends State<ExercisePickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = filterAndSortExercises(widget.exercises, _query);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == PickerMode.add ? 'Add Exercise' : 'Replace Exercise',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: ExerciseSearchField(
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final exercise = visible[index];
                return SurfaceCard(
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.muscleSummary} / ${exercise.equipment}',
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => Navigator.of(context).pop(exercise),
                    ),
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

enum PickerMode { add, replace }
