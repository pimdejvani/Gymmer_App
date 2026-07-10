/// One routine card on the home screen. Owns the card's gestures:
/// - long-press drag (LongPressDraggable) to move/reorder — the card is also
///   a DragTarget so dropping another routine on it inserts before it
/// - swipe left (Slidable) to reveal Delete
/// - tap to edit, Start Routine button to begin a session
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models.dart';
import '../../theme/app_theme.dart';

class RoutineCard extends StatefulWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
    required this.onDropBefore,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Routine routine;
  final ValueChanged<Routine> onStart;
  final ValueChanged<Routine> onEdit;
  final ValueChanged<Routine> onDelete;

  /// Another routine was dropped onto this card — insert it before this one.
  final ValueChanged<Routine> onDropBefore;

  /// Forwarded to the home screen for edge auto-scroll while dragging.
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard> {
  bool _expanded = false;

  Routine get routine => widget.routine;
  ValueChanged<Routine> get onStart => widget.onStart;
  ValueChanged<Routine> get onEdit => widget.onEdit;
  ValueChanged<Routine> get onDelete => widget.onDelete;
  ValueChanged<Routine> get onDropBefore => widget.onDropBefore;
  ValueChanged<DragUpdateDetails> get onDragUpdate => widget.onDragUpdate;
  VoidCallback get onDragEnd => widget.onDragEnd;

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 32;
    final card = _cardBody(context);
    return DragTarget<Routine>(
      onWillAcceptWithDetails: (details) => !identical(details.data, routine),
      onAcceptWithDetails: (details) => onDropBefore(details.data),
      builder: (context, candidate, rejected) {
        final showLine = candidate.isNotEmpty;
        return Column(
          children: [
            // Accent insertion indicator while another card hovers above.
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: showLine ? 3 : 0,
              margin: EdgeInsets.only(bottom: showLine ? 8 : 0),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            LongPressDraggable<Routine>(
              data: routine,
              onDragStarted: HapticFeedback.mediumImpact,
              onDragUpdate: onDragUpdate,
              onDragEnd: (_) => onDragEnd(),
              onDraggableCanceled: (_, _) => onDragEnd(),
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: cardWidth,
                  child: Transform.scale(
                    scale: 1.03,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _cardBody(context, raised: true, interactive: false),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: card),
              child: Slidable(
                key: ValueKey(routine),
                groupTag: 'home-routines',
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.28,
                  children: [
                    SlidableAction(
                      onPressed: (_) => onDelete(routine),
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                  ],
                ),
                child: card,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cardBody(BuildContext context, {bool raised = false, bool interactive = true}) {
    final expanded = interactive && _expanded;
    return Material(
      color: raised ? AppColors.surfaceHigh : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => onEdit(routine),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      routine.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                routine.note,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Tap the exercise-count chip to expand a per-exercise detail list.
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: interactive
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.format_list_numbered,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text('${routine.exercises.length} exercises'),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: () => onStart(routine),
                    child: const Text('Start Routine'),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 8),
                if (routine.exercises.isEmpty)
                  const Text(
                    'No exercises in this routine.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (final item in routine.exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.exercise.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.sets} ${item.sets == 1 ? 'set' : 'sets'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
