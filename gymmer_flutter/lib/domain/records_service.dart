/// Pure-Dart personal-record + per-exercise stats, computed from the finished
/// workout list. History stays the source of truth — nothing new is persisted.
///
/// Record types per exercise: max weight, estimated 1RM, set volume, and
/// session volume.
library;

import '../models/completed_workout.dart';

/// Distinct exercise names that appear in [all], sorted alphabetically.
List<String> exercisesWithHistory(List<CompletedWorkout> all) {
  final names = <String>{
    for (final workout in all)
      for (final exercise in workout.exercises) exercise.exerciseName,
  };
  final sorted = names.toList()..sort();
  return sorted;
}

/// Number of sets in [w] that strictly beat every EARLIER (by startedAt)
/// session's best weight or best set volume for the same exercise. Multiple
/// record sets in one workout each count. Later sessions never affect an
/// earlier workout's count.
int recordsIn(CompletedWorkout w, List<CompletedWorkout> all) {
  var count = 0;
  for (final exercise in w.exercises) {
    var bestKg = double.negativeInfinity;
    var bestVolume = double.negativeInfinity;
    for (final other in all) {
      if (!other.startedAt.isBefore(w.startedAt)) continue;
      for (final oex in other.exercises) {
        if (oex.exerciseName != exercise.exerciseName) continue;
        for (final set in oex.sets) {
          if (set.kg > bestKg) bestKg = set.kg;
          final volume = set.kg * set.reps;
          if (volume > bestVolume) bestVolume = volume;
        }
      }
    }
    for (final set in exercise.sets) {
      final volume = set.kg * set.reps;
      if (set.kg > bestKg || volume > bestVolume) count++;
    }
  }
  return count;
}

class ExerciseSessionStat {
  const ExerciseSessionStat({
    required this.sessionId,
    required this.date,
    required this.kg,
    required this.reps,
    required this.best1Rm,
    required this.bestSetVolume,
    required this.sessionVolume,
    required this.totalReps,
  });

  /// Session date and its top set (highest kg).
  final int? sessionId;
  final DateTime date;
  final double kg;
  final int reps;
  final double best1Rm;
  final double bestSetVolume;
  final double sessionVolume;
  final int totalReps;
}

class ExerciseStats {
  const ExerciseStats({
    required this.exerciseName,
    required this.bestKg,
    required this.best1Rm,
    required this.bestSetVolume,
    required this.bestSetVolumeKg,
    required this.bestSetVolumeReps,
    required this.bestSessionVolume,
    required this.totalSessions,
    required this.series,
  });

  final String exerciseName;
  final double bestKg;
  final double best1Rm;
  final double bestSetVolume;
  final double bestSetVolumeKg;
  final int bestSetVolumeReps;
  final double bestSessionVolume;
  final int totalSessions;

  /// Top-set-per-session, oldest → newest.
  final List<ExerciseSessionStat> series;
}

/// Aggregates every session containing [exerciseName]. Sessions that never
/// include the exercise are ignored (an unknown exercise yields empty stats).
ExerciseStats statsFor(String exerciseName, List<CompletedWorkout> all) {
  final sessions = [
    for (final workout in all)
      if (workout.exercises.any((e) => e.exerciseName == exerciseName)) workout,
  ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  var bestKg = 0.0;
  var best1Rm = 0.0;
  var bestVolume = 0.0;
  var bestVolumeKg = 0.0;
  var bestVolumeReps = 0;
  var bestSessionVolume = 0.0;
  final series = <ExerciseSessionStat>[];
  for (final session in sessions) {
    double topKg = double.negativeInfinity;
    int topReps = 0;
    var sessionBest1Rm = 0.0;
    var sessionBestSetVolume = 0.0;
    var sessionVolume = 0.0;
    var totalReps = 0;
    for (final exercise in session.exercises) {
      if (exercise.exerciseName != exerciseName) continue;
      for (final set in exercise.sets) {
        if (set.kg > bestKg) bestKg = set.kg;
        final oneRm = set.kg * (1 + set.reps / 30);
        if (oneRm > sessionBest1Rm) sessionBest1Rm = oneRm;
        if (oneRm > best1Rm) best1Rm = oneRm;
        final volume = set.kg * set.reps;
        if (volume > sessionBestSetVolume) sessionBestSetVolume = volume;
        sessionVolume += volume;
        totalReps += set.reps;
        if (volume > bestVolume) {
          bestVolume = volume;
          bestVolumeKg = set.kg;
          bestVolumeReps = set.reps;
        }
        if (set.kg > topKg) {
          topKg = set.kg;
          topReps = set.reps;
        }
      }
    }
    if (sessionVolume > bestSessionVolume) bestSessionVolume = sessionVolume;
    if (topKg != double.negativeInfinity) {
      series.add(
        ExerciseSessionStat(
          sessionId: session.id,
          date: session.startedAt,
          kg: topKg,
          reps: topReps,
          best1Rm: sessionBest1Rm,
          bestSetVolume: sessionBestSetVolume,
          sessionVolume: sessionVolume,
          totalReps: totalReps,
        ),
      );
    }
  }

  return ExerciseStats(
    exerciseName: exerciseName,
    bestKg: bestKg,
    best1Rm: best1Rm,
    bestSetVolume: bestVolume,
    bestSetVolumeKg: bestVolumeKg,
    bestSetVolumeReps: bestVolumeReps,
    bestSessionVolume: bestSessionVolume,
    totalSessions: sessions.length,
    series: series,
  );
}
