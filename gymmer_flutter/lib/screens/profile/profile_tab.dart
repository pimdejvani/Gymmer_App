/// Profile tab: a "Workouts" count header over a feed of finished workouts.
/// Data is pulled lazily from the store when the tab opens.
library;

import 'package:flutter/material.dart';

import '../../data/workout_store.dart';
import '../../domain/records_service.dart';
import '../../domain/workout_aggregates.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/dashboard_grid.dart';
import '../../widgets/profile/weekly_bar_chart.dart';
import '../../widgets/profile/workout_feed_card.dart';
import 'calendar_page.dart';
import 'about_page.dart';
import 'exercise_stats_page.dart';
import 'measurements_page.dart';
import 'workout_detail_page.dart';

/// Range options for the weekly chart → number of weeks.
const _rangeWeeks = <String, int>{
  'Last 3 months': 12,
  'Last 6 months': 26,
  'Last year': 52,
};

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.store,
    required this.loadCompletedWorkouts,
    required this.loadMeasurements,
    required this.saveMeasurement,
    required this.deleteMeasurement,
  });

  final WorkoutStore store;
  final Future<List<CompletedWorkout>> Function() loadCompletedWorkouts;
  final Future<List<MeasurementEntry>> Function() loadMeasurements;
  final Future<void> Function(MeasurementEntry entry) saveMeasurement;
  final Future<void> Function(DateTime date) deleteMeasurement;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<List<CompletedWorkout>> _future;
  ProgressMetric _metric = ProgressMetric.duration;
  String _range = 'Last 3 months';

  @override
  void initState() {
    super.initState();
    _future = widget.loadCompletedWorkouts();
  }

  String _formatHeadline(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m this week';
    return '${hours}h ${minutes}m this week';
  }

  Widget _buildProgressSection(List<CompletedWorkout> workouts) {
    final now = DateTime.now();
    final weeks = weeklyTotals(
      workouts,
      _metric,
      now: now,
      weeks: _rangeWeeks[_range]!,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _formatHeadline(thisWeekDuration(workouts, now: now)),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            DropdownButton<String>(
              value: _range,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.surfaceHigh,
              items: [
                for (final key in _rangeWeeks.keys)
                  DropdownMenuItem(value: key, child: Text(key)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _range = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        WeeklyBarChart(weeks: weeks),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final metric in ProgressMetric.values)
              ChoiceChip(
                label: Text(_metricLabel(metric)),
                selected: _metric == metric,
                onSelected: (_) => setState(() => _metric = metric),
              ),
          ],
        ),
      ],
    );
  }

  String _metricLabel(ProgressMetric metric) {
    switch (metric) {
      case ProgressMetric.duration:
        return 'Duration';
      case ProgressMetric.volume:
        return 'Volume';
      case ProgressMetric.reps:
        return 'Reps';
    }
  }

  void _reloadFeed() {
    setState(() {
      _future = widget.loadCompletedWorkouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<List<CompletedWorkout>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final workouts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProgressSection(workouts),
              const SizedBox(height: 20),
              DashboardGrid(
                entries: [
                  DashboardEntry(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CalendarPage(
                          workouts: workouts,
                          now: DateTime.now(),
                        ),
                      ),
                    ),
                  ),
                  DashboardEntry(
                    icon: Icons.straighten,
                    label: 'Measures',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MeasurementsPage(
                          load: widget.loadMeasurements,
                          save: widget.saveMeasurement,
                          delete: widget.deleteMeasurement,
                        ),
                      ),
                    ),
                  ),
                  DashboardEntry(
                    icon: Icons.fitness_center_outlined,
                    label: 'Exercises',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseStatsPage(
                            store: widget.store,
                            workouts: workouts,
                          ),
                        ),
                      );
                      if (mounted) _reloadFeed();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '${workouts.length}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Text(
                'Workouts',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final workout in workouts)
                Builder(
                  builder: (context) {
                    final records = recordsIn(workout, workouts);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WorkoutFeedCard(
                        workout: workout,
                        records: records,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WorkoutDetailPage(
                                store: widget.store,
                                workout: workout,
                                records: records,
                              ),
                            ),
                          );
                          if (mounted) _reloadFeed();
                        },
                      ),
                    );
                  },
                ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
                child: const Text('About GYMMER'),
              ),
            ],
          );
        },
      ),
    );
  }
}
