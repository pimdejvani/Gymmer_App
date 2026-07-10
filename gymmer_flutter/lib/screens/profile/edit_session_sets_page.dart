/// Edit one exercise's recorded sets inside a completed workout session.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../data/workout_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class EditSessionSetsPage extends StatefulWidget {
  const EditSessionSetsPage({
    super.key,
    required this.store,
    required this.sessionId,
    required this.exerciseName,
    required this.sessionDate,
    required this.initialSets,
  });

  final WorkoutStore store;
  final int sessionId;
  final String exerciseName;
  final DateTime sessionDate;
  final List<({double kg, int reps})> initialSets;

  @override
  State<EditSessionSetsPage> createState() => _EditSessionSetsPageState();
}

class _EditSessionSetsPageState extends State<EditSessionSetsPage> {
  late final List<_SetDraft> _sets = [
    for (final set in widget.initialSets)
      _SetDraft(kg: _formatKg(set.kg), reps: '${set.reps}'),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final set in _sets) {
      set.dispose();
    }
    super.dispose();
  }

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

  Future<void> _save() async {
    final parsed = <({double kg, int reps})>[];
    for (final set in _sets) {
      final kg = double.tryParse(set.kg.text.trim());
      final reps = int.tryParse(set.reps.text.trim());
      if (kg == null || kg <= 0 || reps == null || reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid kg and reps.')),
        );
        return;
      }
      parsed.add((kg: kg, reps: reps));
    }
    setState(() => _saving = true);
    await widget.store.updateCompletedExerciseSets(
      widget.sessionId,
      widget.exerciseName,
      parsed,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  void _addSet() {
    setState(() => _sets.add(_SetDraft()));
  }

  void _removeSet(_SetDraft set) {
    setState(() {
      _sets.remove(set);
      set.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exerciseName),
            Text(
              _formatDate(widget.sessionDate),
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
            for (var i = 0; i < _sets.length; i++) ...[
              _SetRow(
                index: i,
                draft: _sets[i],
                onDelete: () => _removeSet(_sets[i]),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add),
              label: const Text('Add Set'),
            ),
          ],
        ),
      ),
    );
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

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.draft,
    required this.onDelete,
  });

  final int index;
  final _SetDraft draft;
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
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 54, child: Text('Set ${index + 1}')),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: draft.kg,
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
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'reps'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatKg(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
