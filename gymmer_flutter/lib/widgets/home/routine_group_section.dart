/// One routine folder on the home screen: header (name + count + menu, also a
/// DragTarget so a routine dropped on it moves into this folder), the routine
/// cards inside, and a dashed drop zone when the folder is empty.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models.dart';
import '../../theme/app_theme.dart';
import 'routine_card.dart';

class RoutineGroupSection extends StatelessWidget {
  const RoutineGroupSection({
    super.key,
    required this.group,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveRoutineTo,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRenameGroup,
    required this.onMoveGroupUp,
    required this.onMoveGroupDown,
    required this.onDeleteGroup,
  });

  final RoutineGroup group;
  final bool collapsed;
  final ValueChanged<RoutineGroup> onToggleCollapsed;
  final ValueChanged<Routine> onStart;
  final ValueChanged<Routine> onEdit;
  final ValueChanged<Routine> onDelete;
  final void Function(Routine routine, RoutineGroup target, {Routine? before})
  onMoveRoutineTo;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;
  final Future<void> Function(RoutineGroup group) onRenameGroup;
  final ValueChanged<RoutineGroup> onMoveGroupUp;
  final ValueChanged<RoutineGroup> onMoveGroupDown;
  final Future<void> Function(RoutineGroup group) onDeleteGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<Routine>(
          onWillAcceptWithDetails: (details) {
            HapticFeedback.selectionClick();
            return !group.routines.contains(details.data);
          },
          onAcceptWithDetails: (details) =>
              onMoveRoutineTo(details.data, group),
          builder: (context, candidate, rejected) {
            final active = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: active
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: active ? AppColors.accent : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: collapsed ? 'Expand folder' : 'Collapse folder',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                    ),
                    onPressed: () => onToggleCollapsed(group),
                  ),
                  Icon(collapsed ? Icons.folder : Icons.folder_open, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename Folder'),
                      ),
                      PopupMenuItem(value: 'move_up', child: Text('Move Up')),
                      PopupMenuItem(
                        value: 'move_down',
                        child: Text('Move Down'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Empty Folder'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'rename') unawaited(onRenameGroup(group));
                      if (value == 'move_up') onMoveGroupUp(group);
                      if (value == 'move_down') onMoveGroupDown(group);
                      if (value == 'delete') unawaited(onDeleteGroup(group));
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        if (collapsed)
          const SizedBox.shrink()
        else if (group.routines.isEmpty)
          _EmptyFolderDropZone(
            onAccept: (routine) => onMoveRoutineTo(routine, group),
          )
        else
          for (final routine in group.routines) ...[
            RoutineCard(
              routine: routine,
              onStart: onStart,
              onEdit: onEdit,
              onDelete: onDelete,
              onDropBefore: (dragged) =>
                  onMoveRoutineTo(dragged, group, before: routine),
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _EmptyFolderDropZone extends StatelessWidget {
  const _EmptyFolderDropZone({required this.onAccept});

  final ValueChanged<Routine> onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Routine>(
      onWillAcceptWithDetails: (details) {
        HapticFeedback.selectionClick();
        return true;
      },
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.hairline,
            ),
            color: active
                ? AppColors.accent.withValues(alpha: 0.10)
                : Colors.transparent,
          ),
          child: const Center(
            child: Text(
              'Drop routines here',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );
  }
}
