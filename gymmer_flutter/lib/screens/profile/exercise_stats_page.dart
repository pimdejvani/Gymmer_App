/// Profile → Exercises: a searchable list of exercises that appear in history
/// → per-exercise stats (personal records, selectable trend chart), and the
/// session history list.
library;

import 'package:flutter/material.dart';

import '../../data/workout_store.dart';
import '../../domain/records_service.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/trend_line_chart.dart';
import '../../widgets/shared_widgets.dart';
import '../exercise_library_page.dart' show ExerciseSearchField;
import 'edit_session_sets_page.dart';

class ExerciseStatsPage extends StatefulWidget {
  const ExerciseStatsPage({
    super.key,
    required this.store,
    required this.workouts,
  });

  final WorkoutStore store;
  final List<CompletedWorkout> workouts;

  @override
  State<ExerciseStatsPage> createState() => _ExerciseStatsPageState();
}

class _ExerciseStatsPageState extends State<ExerciseStatsPage> {
  String _query = '';
  late List<CompletedWorkout> _workouts;

  @override
  void initState() {
    super.initState();
    _workouts = widget.workouts;
  }

  Future<void> _reload() async {
    final workouts = await widget.store.loadCompletedWorkouts();
    if (mounted) setState(() => _workouts = workouts);
  }

  @override
  Widget build(BuildContext context) {
    final names = exercisesWithHistory(_workouts);
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? names
        : names.where((n) => n.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
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
                final name = visible[index];
                return SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _ExerciseStatsDetail(
                              store: widget.store,
                              exerciseName: name,
                              workouts: _workouts,
                            ),
                          ),
                        );
                        await _reload();
                      },
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

enum _TrendMetric {
  heaviestWeight('Heaviest Weight', 'kg'),
  oneRm('1RM', 'kg'),
  setVolume('Set Volume', 'kg'),
  sessionVolume('Session Volume', 'kg'),
  totalReps('Total Reps', 'reps');

  const _TrendMetric(this.label, this.unit);

  final String label;
  final String unit;

  double value(ExerciseSessionStat stat) {
    return switch (this) {
      _TrendMetric.heaviestWeight => stat.kg,
      _TrendMetric.oneRm => stat.best1Rm,
      _TrendMetric.setVolume => stat.bestSetVolume,
      _TrendMetric.sessionVolume => stat.sessionVolume,
      _TrendMetric.totalReps => stat.totalReps.toDouble(),
    };
  }
}

class _ExerciseStatsDetail extends StatefulWidget {
  const _ExerciseStatsDetail({
    required this.store,
    required this.exerciseName,
    required this.workouts,
  });

  final WorkoutStore store;
  final String exerciseName;
  final List<CompletedWorkout> workouts;

  @override
  State<_ExerciseStatsDetail> createState() => _ExerciseStatsDetailState();
}

class _ExerciseStatsDetailState extends State<_ExerciseStatsDetail> {
  _TrendMetric _metric = _TrendMetric.heaviestWeight;
  late List<CompletedWorkout> _workouts;
  late ExerciseStats _stats;

  @override
  void initState() {
    super.initState();
    _workouts = widget.workouts;
    _stats = statsFor(widget.exerciseName, _workouts);
  }

  String _kg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  String _kg2(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _date(DateTime d) {
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

  Future<void> _editSession(ExerciseSessionStat point) async {
    final sessionId = point.sessionId;
    if (sessionId == null) return;
    final workout = _workouts.where((item) => item.id == sessionId);
    if (workout.isEmpty) return;
    final exercise = workout.first.exercises.where(
      (item) => item.exerciseName == _stats.exerciseName,
    );
    if (exercise.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditSessionSetsPage(
          store: widget.store,
          sessionId: sessionId,
          exerciseName: _stats.exerciseName,
          sessionDate: point.date,
          initialSets: exercise.first.sets,
        ),
      ),
    );
    if (changed != true) return;
    final workouts = await widget.store.loadCompletedWorkouts();
    if (!mounted) return;
    setState(() {
      _workouts = workouts;
      _stats = statsFor(widget.exerciseName, _workouts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final points = [
      for (final point in stats.series)
        TrendPoint(date: point.date, value: _metric.value(point)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(stats.exerciseName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TrendLineChart(points: points, unit: _metric.unit),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final metric in _TrendMetric.values) ...[
                  ChoiceChip(
                    label: Text(metric.label),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Records',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _RecordRow(
                  label: 'Heaviest Weight',
                  value: '${_kg(stats.bestKg)}kg',
                ),
                _RecordRow(
                  label: 'Best 1RM',
                  value: '${_kg2(stats.best1Rm)}kg',
                ),
                _RecordRow(
                  label: 'Best Set Volume',
                  value:
                      '${_kg(stats.bestSetVolumeKg)}kg × ${stats.bestSetVolumeReps}',
                ),
                _RecordRow(
                  label: 'Best Session Volume',
                  value: '${_kg(stats.bestSessionVolume)}kg',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final point in stats.series.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _date(point.date),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_kg(point.kg)} kg × ${point.reps}',
                          style: kNumericStyle,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                    onTap: () => _editSession(point),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: kNumericStyle),
        ],
      ),
    );
  }
}
