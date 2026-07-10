/// Edit a whole completed workout session: the duration plus every exercise's
/// sets (kg/reps, add/delete), with a live session-wide set summary. UI mirrors
/// the active session. Exercises can't be added or removed here — only their
/// sets — so each exercise keeps at least one set.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../data/workout_store.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class EditSessionPage extends StatefulWidget {
  const EditSessionPage({super.key, required this.store, required this.workout});

  final WorkoutStore store;
  final CompletedWorkout workout;

  @override
  State<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends State<EditSessionPage> {
  late final List<_ExerciseDraft> _exercises = [
    for (final exercise in widget.workout.exercises)
      _ExerciseDraft(
        name: exercise.exerciseName,
        sets: [
          for (final set in exercise.sets)
            _SetDraft(kg: _formatKg(set.kg), reps: '${set.reps}'),
        ],
      ),
  ];
  late final _hours = TextEditingController(
    text: '${widget.workout.duration.inHours}',
  );
  late final _minutes = TextEditingController(
    text: '${widget.workout.duration.inMinutes.remainder(60)}',
  );
  bool _saving = false;

  @override
  void dispose() {
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  ({int sets, double volume, int reps}) get _sessionStats {
    var sets = 0;
    var volume = 0.0;
    var reps = 0;
    for (final exercise in _exercises) {
      for (final set in exercise.sets) {
        final kg = double.tryParse(set.kg.text.trim());
        final repCount = int.tryParse(set.reps.text.trim());
        if (kg == null || repCount == null) continue;
        sets++;
        reps += repCount;
        volume += kg * repCount;
      }
    }
    return (sets: sets, volume: volume, reps: reps);
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final parsedByExercise = <String, List<({double kg, int reps})>>{};
    for (final exercise in _exercises) {
      final parsed = <({double kg, int reps})>[];
      for (final set in exercise.sets) {
        final kg = double.tryParse(set.kg.text.trim());
        final reps = int.tryParse(set.reps.text.trim());
        if (kg == null || kg <= 0 || reps == null || reps <= 0) {
          _snack('Enter valid kg and reps for ${exercise.name}.');
          return;
        }
        parsed.add((kg: kg, reps: reps));
      }
      if (parsed.isEmpty) {
        _snack('${exercise.name} needs at least one set.');
        return;
      }
      parsedByExercise[exercise.name] = parsed;
    }
    final hours = int.tryParse(_hours.text.trim()) ?? 0;
    final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
    if (hours < 0 || minutes < 0 || (hours == 0 && minutes == 0)) {
      _snack('Enter a valid duration.');
      return;
    }

    setState(() => _saving = true);
    final sessionId = widget.workout.id!;
    for (final entry in parsedByExercise.entries) {
      await widget.store.updateCompletedExerciseSets(
        sessionId,
        entry.key,
        entry.value,
      );
    }
    final started = widget.workout.startedAt;
    final completed = started.add(Duration(hours: hours, minutes: minutes));
    await widget.store.updateCompletedWorkoutTimes(
      sessionId,
      started,
      completed,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  void _addSet(_ExerciseDraft exercise) {
    setState(() => exercise.sets.add(_SetDraft()));
  }

  void _removeSet(_ExerciseDraft exercise, _SetDraft set) {
    if (exercise.sets.length <= 1) {
      _snack('Each exercise needs at least one set.');
      return;
    }
    setState(() {
      exercise.sets.remove(set);
      set.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _sessionStats;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.workout.sessionName),
            Text(
              _formatDate(widget.workout.completedAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DurationCard(hours: _hours, minutes: _minutes),
            const SizedBox(height: 12),
            _SessionStatsCard(
              sets: stats.sets,
              volume: stats.volume,
              reps: stats.reps,
            ),
            const SizedBox(height: 16),
            for (final exercise in _exercises) ...[
              _ExerciseEditCard(
                exercise: exercise,
                onChanged: () => setState(() {}),
                onAddSet: () => _addSet(exercise),
                onDeleteSet: (set) => _removeSet(exercise, set),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({required this.hours, required this.minutes});

  final TextEditingController hours;
  final TextEditingController minutes;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18),
          const SizedBox(width: 8),
          const Text('Duration'),
          const Spacer(),
          SizedBox(
            width: 56,
            child: TextField(
              controller: hours,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'h'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':'),
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'm'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStatsCard extends StatelessWidget {
  const _SessionStatsCard({
    required this.sets,
    required this.volume,
    required this.reps,
  });

  final int sets;
  final double volume;
  final int reps;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('Sets', '$sets'),
          _stat('Volume', '${_formatKg(volume)} kg'),
          _stat('Reps', '$reps'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: kNumericStyle),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _ExerciseEditCard extends StatelessWidget {
  const _ExerciseEditCard({
    required this.exercise,
    required this.onChanged,
    required this.onAddSet,
    required this.onDeleteSet,
  });

  final _ExerciseDraft exercise;
  final VoidCallback onChanged;
  final VoidCallback onAddSet;
  final ValueChanged<_SetDraft> onDeleteSet;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (var i = 0; i < exercise.sets.length; i++) ...[
            _SetRow(
              index: i,
              draft: exercise.sets[i],
              onChanged: onChanged,
              onDelete: () => onDeleteSet(exercise.sets[i]),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: onAddSet,
            icon: const Icon(Icons.add),
            label: const Text('Add Set'),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _SetDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(draft),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text('Set ${index + 1}')),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: draft.kg,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(labelText: 'kg'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: draft.reps,
              onChanged: (_) => onChanged(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'reps'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft({required this.name, required this.sets});

  final String name;
  final List<_SetDraft> sets;

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _SetDraft {
  _SetDraft({String kg = '', String reps = ''})
    : kg = TextEditingController(text: kg),
      reps = TextEditingController(text: reps);

  final TextEditingController kg;
  final TextEditingController reps;

  void dispose() {
    kg.dispose();
    reps.dispose();
  }
}

String _formatKg(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

String _formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
