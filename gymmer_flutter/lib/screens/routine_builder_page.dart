import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_picker_page.dart';
import '../widgets/shared_widgets.dart';

class RoutineBuilderPage extends StatefulWidget {
  const RoutineBuilderPage({
    super.key,
    required this.draft,
    required this.exercises,
    required this.groupNames,
    required this.initialGroupName,
  });

  final Routine draft;
  final List<Exercise> exercises;
  final List<String> groupNames;
  final String initialGroupName;

  @override
  State<RoutineBuilderPage> createState() => _RoutineBuilderPageState();
}

class RoutineBuilderResult {
  const RoutineBuilderResult({required this.routine, required this.groupName});

  final Routine routine;
  final String groupName;
}

class _RoutineBuilderPageState extends State<RoutineBuilderPage> {
  late Routine draft = widget.draft;
  late final TextEditingController nameController = TextEditingController(
    text: draft.name,
  );
  late final TextEditingController groupController = TextEditingController(
    text: widget.initialGroupName,
  );

  @override
  void dispose() {
    nameController.dispose();
    groupController.dispose();
    super.dispose();
  }

  Future<void> addExercise() async {
    final selected = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExercisePickerPage(
          exercises: widget.exercises,
          mode: PickerMode.add,
        ),
      ),
    );
    if (!mounted) return;
    if (selected == null) return;
    setState(() => draft.exercises.add(RoutineExercise(selected, 1, 60)));
  }

  void reorderExercise(int oldIndex, int newIndex) {
    setState(() {
      final item = draft.exercises.removeAt(oldIndex);
      draft.exercises.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Builder'),
        actions: [
          TextButton(
            onPressed: () {
              draft.name = nameController.text.trim().isEmpty
                  ? 'New Routine'
                  : nameController.text.trim();
              draft.note = '${draft.exercises.length} exercises ready';
              final groupName = groupController.text.trim().isEmpty
                  ? 'My Routines'
                  : groupController.text.trim();
              Navigator.of(
                context,
              ).pop(RoutineBuilderResult(routine: draft, groupName: groupName));
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Routine Name',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: groupController,
                      decoration: const InputDecoration(
                        labelText: 'Routine Folder',
                        prefixIcon: Icon(Icons.folder_open),
                      ),
                    ),
                    if (widget.groupNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final groupName in widget.groupNames)
                            ActionChip(
                              avatar: const Icon(Icons.folder_open, size: 16),
                              label: Text(groupName),
                              onPressed: () => setState(() {
                                groupController.text = groupName;
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (draft.exercises.isNotEmpty)
                      Text(
                        'Exercises',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SliverReorderableList(
              itemCount: draft.exercises.length,
              onReorderStart: (_) => HapticFeedback.mediumImpact(),
              onReorderItem: reorderExercise,
              proxyDecorator: reorderProxyDecorator,
              itemBuilder: (context, index) {
                final item = draft.exercises[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(item),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Slidable(
                      groupTag: 'builder-exercises',
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.28,
                        children: [
                          SlidableAction(
                            onPressed: (_) =>
                                setState(() => draft.exercises.remove(item)),
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_outline,
                            label: 'Remove',
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                        ],
                      ),
                      child: ExerciseEditorCard(
                        item: item,
                        onAddSet: () => setState(() => item.sets++),
                        onRemoveSet: () => setState(
                          () => item.sets = (item.sets - 1).clamp(1, 12),
                        ),
                        onTimerChanged: (seconds) =>
                            setState(() => item.restSeconds = seconds),
                      ),
                    ),
                  ),
                );
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton.icon(
                  onPressed: addExercise,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Exercise'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseEditorCard extends StatelessWidget {
  const ExerciseEditorCard({
    super.key,
    required this.item,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onTimerChanged,
  });

  final RoutineExercise item;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final ValueChanged<int?> onTimerChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.exercise.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            '${item.exercise.muscleSummary} / ${item.exercise.equipment}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StepperButton(icon: Icons.remove, onPressed: onRemoveSet),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${item.sets} sets'),
              ),
              StepperButton(icon: Icons.add, onPressed: onAddSet),
              const Spacer(),
              RestTimerButton(
                seconds: item.restSeconds,
                onChanged: onTimerChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
