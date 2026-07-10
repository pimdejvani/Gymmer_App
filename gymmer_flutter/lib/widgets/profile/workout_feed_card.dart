/// A single finished-workout card in the Profile feed: session name, relative
/// date, a `Time | Volume | Sets` stat row, the first three exercises, and a
/// "See N more exercises" line. Tapping opens the detail page.
library;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme/app_theme.dart';
import '../shared_widgets.dart';

class WorkoutFeedCard extends StatelessWidget {
  const WorkoutFeedCard({
    super.key,
    required this.workout,
    this.onTap,
    this.records = 0,
  });

  final CompletedWorkout workout;
  final VoidCallback? onTap;
  final int records;

  @override
  Widget build(BuildContext context) {
    final exercises = workout.exercises;
    final shown = exercises.take(3).toList();
    final remaining = exercises.length - shown.length;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.sessionName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              formatRelativeDate(workout.completedAt),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            WorkoutStatsRow(workout: workout, records: records),
            const SizedBox(height: 12),
            for (final exercise in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${exercise.sets.length} sets ${exercise.exerciseName}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'See $remaining more exercises',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The `Time | Volume | (Records|Sets)` stat row shared by the feed card and
/// detail page. The third cell shows 🏅 Records when [records] > 0, otherwise
/// falls back to Sets.
class WorkoutStatsRow extends StatelessWidget {
  const WorkoutStatsRow({super.key, required this.workout, this.records = 0});

  final CompletedWorkout workout;
  final int records;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCell(label: 'Time', value: formatDuration(workout.duration)),
        _StatCell(
          label: 'Volume',
          value: formatVolumeKg(workout.totalVolumeKg),
        ),
        if (records > 0)
          _StatCell(label: 'Records', value: '🏅 $records')
        else
          _StatCell(label: 'Sets', value: '${workout.totalSets}'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: kNumericStyle.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}

/// `1h 22min` / `22min` / `0min`.
String formatDuration(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}min';
  return '${hours}h ${minutes}min';
}

/// `4,908 kg` (thousands-grouped, rounded).
String formatVolumeKg(double kg) {
  final rounded = kg.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer kg';
}

/// `Today` / `Yesterday` / `N days ago` / `DD Mon YYYY`.
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final ref = DateTime(today.year, today.month, today.day);
  final diff = ref.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return '$diff days ago';
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
