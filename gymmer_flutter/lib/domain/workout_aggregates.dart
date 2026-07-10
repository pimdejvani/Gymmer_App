/// Pure-Dart weekly aggregation for the Profile progress chart. No Flutter
/// imports — bucket finished workouts into Monday-start weeks by `startedAt`.
library;

import '../models/completed_workout.dart';

enum ProgressMetric { duration, volume, reps }

class WeekTotal {
  const WeekTotal({required this.weekStart, required this.value});

  /// Monday 00:00 (local) of the week this total covers.
  final DateTime weekStart;
  final double value;
}

/// Monday 00:00 of the calendar week containing [d] (weeks start Monday).
DateTime mondayOf(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
  return DateTime(monday.year, monday.month, monday.day);
}

DateTime _addWeeks(DateTime monday, int weeks) {
  final shifted = monday.add(Duration(days: 7 * weeks));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

double _metricValue(CompletedWorkout workout, ProgressMetric metric) {
  switch (metric) {
    case ProgressMetric.duration:
      return workout.duration.inMinutes.toDouble();
    case ProgressMetric.volume:
      return workout.totalVolumeKg;
    case ProgressMetric.reps:
      return workout.exercises
          .fold<int>(
            0,
            (sum, exercise) =>
                sum + exercise.sets.fold<int>(0, (a, set) => a + set.reps),
          )
          .toDouble();
  }
}

/// One [WeekTotal] per week for the last [weeks] weeks ending with the week of
/// [now]. Gaps are zero-filled; the list is oldest → newest and always has
/// length [weeks].
List<WeekTotal> weeklyTotals(
  List<CompletedWorkout> workouts,
  ProgressMetric metric, {
  required DateTime now,
  required int weeks,
}) {
  final currentMonday = mondayOf(now);
  final firstMonday = _addWeeks(currentMonday, -(weeks - 1));
  final totals = <DateTime, double>{
    for (var i = 0; i < weeks; i++) _addWeeks(firstMonday, i): 0.0,
  };
  for (final workout in workouts) {
    final monday = mondayOf(workout.startedAt);
    final existing = totals[monday];
    if (existing != null) {
      totals[monday] = existing + _metricValue(workout, metric);
    }
  }
  return [
    for (final entry in totals.entries)
      WeekTotal(weekStart: entry.key, value: entry.value),
  ];
}

/// Total workout duration in the week containing [now] (headline figure).
Duration thisWeekDuration(
  List<CompletedWorkout> workouts, {
  required DateTime now,
}) {
  final monday = mondayOf(now);
  var total = Duration.zero;
  for (final workout in workouts) {
    if (mondayOf(workout.startedAt) == monday) {
      total += workout.duration;
    }
  }
  return total;
}
