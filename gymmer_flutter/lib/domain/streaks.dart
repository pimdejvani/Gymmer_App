/// Pure-Dart streak math for the Profile calendar header. Weeks start Monday
/// (shares `mondayOf` with workout_aggregates).
library;

import 'workout_aggregates.dart';

DateTime _prevWeek(DateTime monday) {
  final shifted = monday.subtract(const Duration(days: 7));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

/// Consecutive Monday-start weeks (counting back from the week of [now]) that
/// contain at least one workout. The current week counts if it has a workout;
/// if it doesn't, an in-progress week doesn't break the streak — counting
/// continues from last week.
int weekStreak(List<DateTime> workoutDays, {required DateTime now}) {
  final weeks = {for (final day in workoutDays) mondayOf(day)};
  var cursor = mondayOf(now);
  if (!weeks.contains(cursor)) cursor = _prevWeek(cursor);
  var streak = 0;
  while (weeks.contains(cursor)) {
    streak++;
    cursor = _prevWeek(cursor);
  }
  return streak;
}

/// Fully-elapsed days this week (Monday up to, but not including, today) with
/// no workout. Today is excluded because it isn't over yet.
int restDaysThisWeek(List<DateTime> workoutDays, {required DateTime now}) {
  final workoutDates = {
    for (final day in workoutDays) DateTime(day.year, day.month, day.day),
  };
  final monday = mondayOf(now);
  final today = DateTime(now.year, now.month, now.day);
  var rest = 0;
  for (
    var day = monday;
    day.isBefore(today);
    day = day.add(const Duration(days: 1))
  ) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (!workoutDates.contains(normalized)) rest++;
  }
  return rest;
}
