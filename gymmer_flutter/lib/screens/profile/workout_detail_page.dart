/// Full detail of one finished workout: the shared stat row on top, then every
/// exercise with each set rendered as `kg × reps`. The app-bar Edit button opens
/// the whole-session editor (duration + every exercise's sets) — this edits the
/// logged session, not the routine template.
library;

import 'package:flutter/material.dart';

import '../../data/workout_store.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/workout_feed_card.dart';
import '../../widgets/shared_widgets.dart';
import 'edit_session_page.dart';

class WorkoutDetailPage extends StatefulWidget {
  const WorkoutDetailPage({
    super.key,
    required this.store,
    required this.workout,
    this.records = 0,
  });

  final WorkoutStore store;
  final CompletedWorkout workout;
  final int records;

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  late CompletedWorkout _workout = widget.workout;

  String _setLine(({double kg, int reps}) set) {
    final kg = set.kg == set.kg.roundToDouble()
        ? set.kg.toStringAsFixed(0)
        : set.kg.toString();
    return '$kg kg × ${set.reps}';
  }

  Future<void> _editSession() async {
    final sessionId = _workout.id;
    if (sessionId == null) return; // session not persisted (web/memory fallback)
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditSessionPage(store: widget.store, workout: _workout),
      ),
    );
    if (changed != true) return;
    final all = await widget.store.loadCompletedWorkouts();
    if (!mounted) return;
    final updated = all.where((w) => w.id == sessionId);
    setState(() {
      if (updated.isNotEmpty) _workout = updated.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _workout.id != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_workout.sessionName),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit session',
              onPressed: _editSession,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            formatRelativeDate(_workout.completedAt),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: WorkoutStatsRow(workout: _workout, records: widget.records),
          ),
          const SizedBox(height: 16),
          for (final exercise in _workout.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exerciseName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < exercise.sets.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                'Set ${i + 1}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(_setLine(exercise.sets[i]), style: kNumericStyle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
