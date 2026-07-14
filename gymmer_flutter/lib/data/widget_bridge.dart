import 'dart:convert';

import 'package:flutter/services.dart';

import '../models.dart';

/// Two-way bridge between the Flutter app and the iOS home-screen widget via the
/// App Group shared container (see the native `AppGroupIO` in AppDelegate.swift).
///
/// The app writes three JSON snapshots the widget renders:
///   * `catalog.json`  — every exercise (name / muscle / equipment) for the picker
///   * `routines.json` — routine names + groups for the Start page
///   * `session.json`  — the ACTIVE workout, the single source of truth both sides
///                       read and write (last-writer-wins, reconciled on resume).
///
/// All calls no-op off iOS (Android / desktop / tests) by swallowing the
/// missing-plugin error, so callers can fire-and-forget everywhere.
class WidgetBridge {
  static const MethodChannel _channel = MethodChannel('gymmer/widget');

  /// Default rest used when an exercise has no explicit [restSeconds].
  static const int _defaultRest = 90;

  // ---------------------------------------------------------------------------
  // Writers (app -> container)
  // ---------------------------------------------------------------------------

  /// Writes the exercise catalog the widget's picker reads. The widget derives
  /// the muscle / equipment filter chips from these entries.
  static Future<void> writeCatalog(List<Exercise> exercises) async {
    final payload = <String, Object?>{
      'updatedAt': DateTime.now().toIso8601String(),
      'exercises': [
        for (final e in exercises)
          {'name': e.name, 'muscle': e.muscle, 'equipment': e.equipment},
      ],
    };
    await _writeFile('catalog.json', jsonEncode(payload));
  }

  /// Writes the routines for the Start page — each with its FULL exercise list
  /// (sets autofilled from [history], exactly like the app builds them) so the
  /// widget can start a routine on its own and land straight on the Log page.
  static Future<void> writeRoutines(
    List<RoutineGroup> groups,
    WorkoutHistory history,
  ) async {
    final routines = <Map<String, Object?>>[];
    for (final group in groups) {
      for (final routine in group.routines) {
        final built = ActiveWorkout.fromRoutine(
          routine,
          groupName: group.name,
          history: history,
        );
        routines.add({
          'name': routine.name,
          'group': group.name,
          'exercises': [for (final ex in built.exercises) _encodeExercise(ex)],
        });
        built.dispose();
      }
    }
    final payload = <String, Object?>{
      'updatedAt': DateTime.now().toIso8601String(),
      'routines': routines,
    };
    await _writeFile('routines.json', jsonEncode(payload));
  }

  /// Writes the active session snapshot (or an empty/inactive one when there is
  /// no workout). Tagged `by: "app"` with a monotonic `rev` so the widget and
  /// the resume-reconciler can tell who wrote last.
  static Future<void> writeSession(ActiveWorkout? workout) async {
    await _writeFile('session.json', jsonEncode(encodeSession(workout)));
  }

  /// Serialises [workout] to the shared session schema. Public + pure so it can
  /// be unit-tested and reused by the resume reconciler.
  static Map<String, Object?> encodeSession(ActiveWorkout? workout) {
    final rev = DateTime.now().microsecondsSinceEpoch;
    if (workout == null) {
      return {'v': 1, 'rev': rev, 'by': 'app', 'active': false};
    }
    return {
      'v': 1,
      'rev': rev,
      'by': 'app',
      'active': true,
      'sessionName': workout.sessionName,
      'source': workout.source,
      'routineName': workout.routineName,
      'routineGroupName': workout.routineGroupName,
      'startedAt': workout.startedAt.toIso8601String(),
      'curEx': 0,
      'ui': {'page': 'log'},
      'exercises': [for (final ex in workout.exercises) _encodeExercise(ex)],
    };
  }

  /// Serialises one workout exercise (name/muscle/equipment + rest + its sets)
  /// to the shared schema. Shared by [encodeSession] and [writeRoutines].
  static Map<String, Object?> _encodeExercise(WorkoutExercise ex) {
    return {
      'name': ex.exercise.name,
      'muscle': ex.exercise.muscle,
      'equipment': ex.exercise.equipment,
      'rest': ex.restSeconds ?? _defaultRest,
      'curSet': 0,
      'sets': [
        for (final set in ex.sets)
          {
            'kg': set.kg.text.trim(),
            'reps': set.reps.text.trim(),
            'prev': set.previousLabel,
            'done': set.completed,
          },
      ],
    };
  }

  // ---------------------------------------------------------------------------
  // Reader (container -> app), used on resume to pull widget-made edits.
  // ---------------------------------------------------------------------------

  /// Reads back `session.json`. Returns the decoded map, or null when the file
  /// is missing / unreadable / not on iOS.
  static Future<Map<String, Object?>?> readSession() async {
    final raw = await _readFile('session.json');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?>
          ? decoded
          : Map<String, Object?>.from(decoded as Map);
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds an [ActiveWorkout] from a decoded [session] map (as written by the
  /// widget) only when the session is still active. Returns null otherwise.
  static ActiveWorkout? sessionToWorkout(
    Map<String, Object?>? session,
    List<Exercise> catalog,
  ) {
    if (session == null || session['active'] != true) return null;
    return buildWorkoutFromSession(session, catalog);
  }

  /// Rebuilds an [ActiveWorkout] from [session] REGARDLESS of the active flag —
  /// used to recover a widget-finished session for history. Exercises are
  /// matched against [catalog] by name to recover media / secondary muscles;
  /// unknown names fall back to a minimal [Exercise]. Returns null when there
  /// are no exercises to build from.
  static ActiveWorkout? buildWorkoutFromSession(
    Map<String, Object?> session,
    List<Exercise> catalog,
  ) {
    final byName = {for (final e in catalog) e.name: e};
    final rawExercises = (session['exercises'] as List?) ?? const [];
    final exercises = <WorkoutExercise>[];
    for (final rawEx in rawExercises) {
      final map = Map<String, Object?>.from(rawEx as Map);
      final name = map['name'] as String? ?? '';
      final exercise =
          byName[name] ??
          Exercise(
            name,
            map['muscle'] as String? ?? '',
            map['equipment'] as String? ?? '',
          );
      final restRaw = map['rest'];
      final rest = restRaw is num ? restRaw.toInt() : null;
      final rawSets = (map['sets'] as List?) ?? const [];
      final sets = <WorkoutSet>[];
      for (final rawSet in rawSets) {
        final setMap = Map<String, Object?>.from(rawSet as Map);
        final set = WorkoutSet(
          kgText: (setMap['kg'] as String?)?.trim() ?? '',
          repsText: (setMap['reps'] as String?)?.trim() ?? '',
          previousLabel: setMap['prev'] as String?,
        );
        set.completed = setMap['done'] == true;
        sets.add(set);
      }
      exercises.add(
        WorkoutExercise(exercise, rest, sets.isEmpty ? [WorkoutSet()] : sets),
      );
    }
    return ActiveWorkout(
      sessionName: session['sessionName'] as String? ?? 'Workout',
      source: session['source'] as String? ?? 'No Routine',
      routineName: session['routineName'] as String?,
      routineGroupName: session['routineGroupName'] as String?,
      startedAt: DateTime.tryParse(session['startedAt'] as String? ?? ''),
      exercises: exercises,
    );
  }

  // ---------------------------------------------------------------------------
  // Native plumbing
  // ---------------------------------------------------------------------------

  static Future<void> _writeFile(String name, String contents) async {
    try {
      await _channel.invokeMethod<void>('writeFile', {
        'name': name,
        'contents': contents,
      });
    } on MissingPluginException {
      // Not iOS / no widget host — ignore.
    } on PlatformException {
      // Container unavailable — ignore; the app keeps working.
    }
  }

  static Future<String?> _readFile(String name) async {
    try {
      return await _channel.invokeMethod<String>('readFile', {'name': name});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
