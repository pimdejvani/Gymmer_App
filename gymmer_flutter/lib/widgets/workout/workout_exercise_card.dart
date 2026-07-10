/// One exercise card inside the Active Workout list, and its set rows.
/// SetRow owns the swipe-left → Delete gesture for a set; completed sets
/// render their values in the accent color.
library;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models.dart';
import '../../theme/app_theme.dart';
import '../shared_widgets.dart';

class WorkoutExerciseCard extends StatelessWidget {
  const WorkoutExerciseCard({
    super.key,
    required this.item,
    required this.onCompleteSet,
    required this.onAddSet,
    required this.onChanged,
    required this.onDeleteSet,
  });

  final WorkoutExercise item;
  final ValueChanged<WorkoutSet> onCompleteSet;
  final VoidCallback onAddSet;
  final VoidCallback onChanged;
  final ValueChanged<int> onDeleteSet;

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
          const SizedBox(height: 6),
          Text(
            item.statsLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < item.sets.length; i++)
            SetRow(
              index: i,
              set: item.sets[i],
              onChanged: onChanged,
              onComplete: () => onCompleteSet(item.sets[i]),
              onDelete: () => onDeleteSet(i),
            ),
          TextButton.icon(
            onPressed: onAddSet,
            icon: const Icon(Icons.add),
            label: const Text('Add Set'),
          ),
        ],
      ),
    );
  }
}

class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.onChanged,
    required this.onComplete,
    required this.onDelete,
  });

  final int index;
  final WorkoutSet set;
  final VoidCallback onChanged;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final valueColor = set.completed ? AppColors.accent : AppColors.textPrimary;
    return Slidable(
      key: ValueKey(set),
      groupTag: 'workout-sets',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                'Set ${index + 1}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: TextField(
                controller: set.kg,
                keyboardType: TextInputType.number,
                style: TextStyle(color: valueColor),
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  hintText: 'KG',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: set.reps,
                keyboardType: TextInputType.number,
                style: TextStyle(color: valueColor),
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  hintText: 'Reps',
                  isDense: true,
                ),
              ),
            ),
            Checkbox(
              value: set.completed,
              activeColor: AppColors.accent,
              checkColor: Colors.black,
              onChanged: (_) => onComplete(),
            ),
          ],
        ),
      ),
    );
  }
}
