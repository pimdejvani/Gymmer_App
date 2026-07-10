/// Active Workout page: session header, rest pill, muscle map, and the
/// exercise list with long-press reorder + swipe actions (Replace / Remove).
/// All mutations flow back through onChanged (draft autosave) and onFinish.
///
/// Display widgets live in `widgets/workout/`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../domain/rest_timer.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_picker_page.dart';
import '../widgets/muscle_map.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/workout/elapsed_time_label.dart';
import '../widgets/workout/rest_timer_pill.dart';
import '../widgets/workout/workout_exercise_card.dart';

class ActiveWorkoutPage extends StatefulWidget {
  const ActiveWorkoutPage({
    super.key,
    required this.workout,
    required this.exercises,
    required this.onChanged,
    required this.onFinish,
  });

  final ActiveWorkout workout;
  final List<Exercise> exercises;
  final ValueChanged<ActiveWorkout> onChanged;
  final Future<void> Function(ActiveWorkout workout) onFinish;

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  late final RestTimerController restTimer = RestTimerController()
    ..onFinished = _onRestFinished;
  late final TextEditingController sessionNameController =
      TextEditingController(text: widget.workout.sessionName);

  @override
  void dispose() {
    restTimer.dispose();
    sessionNameController.dispose();
    super.dispose();
  }

  void _onRestFinished() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });
    SystemSound.play(SystemSoundType.click);
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
    setState(() {
      widget.workout.exercises.add(WorkoutExercise.fromExercise(selected));
    });
    widget.onChanged(widget.workout);
  }

  void reorderExercise(int oldIndex, int newIndex) {
    setState(() {
      final item = widget.workout.exercises.removeAt(oldIndex);
      widget.workout.exercises.insert(newIndex, item);
    });
    widget.onChanged(widget.workout);
  }

  Future<void> replaceExercise(int index) async {
    final selected = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExercisePickerPage(
          exercises: widget.exercises,
          mode: PickerMode.replace,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final current = widget.workout.exercises[index];
    setState(() {
      if (_hasCompletedSets(current)) {
        widget.workout.exercises.add(WorkoutExercise.fromExercise(selected));
      } else {
        widget.workout.exercises[index] = WorkoutExercise(
          selected,
          current.restSeconds,
          current.sets,
        );
      }
    });
    widget.onChanged(widget.workout);
  }

  Future<void> deleteExercise(int index) async {
    final item = widget.workout.exercises[index];
    if (_hasCompletedSets(item)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Exercise?'),
          content: const Text(
            'Completed sets for this exercise will not be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      final item = widget.workout.exercises.removeAt(index);
      item.dispose();
    });
    widget.onChanged(widget.workout);
  }

  void deleteSet(int exerciseIndex, int setIndex) {
    setState(() {
      final set = widget.workout.exercises[exerciseIndex].sets.removeAt(
        setIndex,
      );
      set.dispose();
    });
    widget.onChanged(widget.workout);
  }

  bool _hasCompletedSets(WorkoutExercise item) {
    return item.sets.any((set) => set.completed);
  }

  Future<void> finish() async {
    await widget.onFinish(widget.workout);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text(
          'This active session will be cleared without saving history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop(true);
  }

  void _completeSet(int exerciseIndex, WorkoutSet set) {
    if (!set.completed && !set.canComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter KG and positive whole-number reps.'),
        ),
      );
      return;
    }
    setState(() {
      set.completed = !set.completed;
    });
    if (set.completed) {
      HapticFeedback.lightImpact();
      final rest = widget.workout.exercises[exerciseIndex].restSeconds;
      if (rest != null && rest > 0) {
        restTimer.start(rest);
      } else {
        restTimer.skip();
      }
    } else {
      restTimer.skip();
    }
    widget.onChanged(widget.workout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Active Workout'),
            ElapsedTimeLabel(startedAt: widget.workout.startedAt),
          ],
        ),
        leading: TextButton(
          onPressed: discard,
          child: const Text(
            'Discard',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
        leadingWidth: 92,
        actions: [
          TextButton(
            onPressed: finish,
            child: const Text(
              'Finish',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: sessionNameController,
                            decoration: const InputDecoration(
                              labelText: 'Session Name',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              widget.workout.sessionName = value.trim().isEmpty
                                  ? widget.workout.source
                                  : value;
                              widget.onChanged(widget.workout);
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.workout.source,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (widget.workout.routineGroupName != null) ...[
                            const SizedBox(height: 8),
                            Chip(
                              avatar: const Icon(Icons.folder_open, size: 16),
                              label: Text(widget.workout.routineGroupName!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    RestTimerPill(controller: restTimer),
                    if (widget.workout.exercises.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      WorkoutMuscleMapPanel(
                        exercises: widget.workout.exercises,
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverReorderableList(
              itemCount: widget.workout.exercises.length,
              onReorderStart: (_) => HapticFeedback.mediumImpact(),
              onReorderItem: reorderExercise,
              proxyDecorator: reorderProxyDecorator,
              itemBuilder: (context, index) {
                final item = widget.workout.exercises[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(item),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Slidable(
                      groupTag: 'workout-exercises',
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.5,
                        children: [
                          SlidableAction(
                            onPressed: (_) => unawaited(replaceExercise(index)),
                            backgroundColor: AppColors.surfaceHigh,
                            foregroundColor: AppColors.textPrimary,
                            icon: Icons.swap_horiz,
                            label: 'Replace',
                          ),
                          SlidableAction(
                            onPressed: (_) => unawaited(deleteExercise(index)),
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_outline,
                            label: 'Remove',
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                        ],
                      ),
                      child: WorkoutExerciseCard(
                        item: item,
                        onCompleteSet: (set) => _completeSet(index, set),
                        onAddSet: () {
                          setState(
                            () =>
                                item.sets.add(item.nextSetFromCurrentSession()),
                          );
                          widget.onChanged(widget.workout);
                        },
                        onChanged: () => widget.onChanged(widget.workout),
                        onDeleteSet: (setIndex) => deleteSet(index, setIndex),
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
