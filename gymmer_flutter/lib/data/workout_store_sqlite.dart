import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/finish_workout_service.dart';
import '../models.dart';
import 'seed_data.dart';
import 'workout_store.dart';

Future<WorkoutStore> openPlatformWorkoutStore() async {
  return GymmerSqliteStore.openAppDatabase();
}

class GymmerSqliteStore implements WorkoutStore {
  GymmerSqliteStore._(this._db);

  factory GymmerSqliteStore.memory() {
    final store = GymmerSqliteStore._(sqlite3.openInMemory());
    store._configure();
    store._migrate();
    return store;
  }

  /// Opens (or creates) a SQLite file at [path]. Intended for tests that need
  /// real file-backed persistence and for reopening the same file across a
  /// simulated app restart.
  factory GymmerSqliteStore.openPath(String path) {
    final store = GymmerSqliteStore._(sqlite3.open(path));
    store._configure();
    store._migrate();
    return store;
  }

  /// Opens a fresh SQLite file inside a new temp directory. The caller is
  /// responsible for cleaning the returned [tempDir] after the store is
  /// closed. Use this in tests instead of [memory] when file-backed behavior
  /// matters (persistence across close/reopen, real filesystem I/O).
  static Future<({GymmerSqliteStore store, Directory tempDir, String path})>
  openTempFile({String label = 'gymmer.sqlite'}) async {
    final tempDir = await Directory.systemTemp.createTemp('gymmer_test_');
    final path = p.join(tempDir.path, label);
    final store = GymmerSqliteStore.openPath(path);
    return (store: store, tempDir: tempDir, path: path);
  }

  static Future<GymmerSqliteStore> openAppDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'gymmer.sqlite'));
    final store = GymmerSqliteStore._(sqlite3.open(file.path));
    store._configure();
    store._migrate();
    return store;
  }

  final Database _db;

  void _configure() {
    _db.execute('PRAGMA foreign_keys = ON');
  }

  void _migrate() {
    final version =
        _db.select('PRAGMA user_version').first['user_version'] as int;
    if (version == 0) {
      _transaction(() {
        _db.execute(_schemaV1);
        _db.execute('PRAGMA user_version = 1');
      });
    }
    if (version < 2) {
      _transaction(() {
        _db.execute(
          'ALTER TABLE exercises ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        );
        _db.execute('PRAGMA user_version = 2');
      });
    }
    if (version < 3) {
      _transaction(() {
        _db.execute(_measurementsTableDdl());
        _db.execute('PRAGMA user_version = 3');
      });
    }
  }

  static String _measurementsTableDdl() {
    final columns = [
      for (final field in measurementFields) '  ${field.column} REAL',
    ].join(',\n');
    return '''
CREATE TABLE measurement_entries (
  date_ms INTEGER PRIMARY KEY,
  photo_path TEXT,
$columns
)''';
  }

  @override
  Future<WorkoutStoreState> load() async {
    _seedPrototypeDataIfEmpty();
    final exercises = _loadExercises();
    return WorkoutStoreState(
      exercises: exercises,
      groups: _loadGroups(exercises),
      history: WorkoutHistory(_loadHistoryRecords()),
      activeWorkout: _loadActiveWorkout(exercises),
    );
  }

  @override
  Future<void> saveExercise(Exercise exercise, {String? originalName}) async {
    _transaction(() => _upsertExercise(exercise, originalName: originalName));
  }

  @override
  Future<void> setExerciseFavorite(String name, bool value) async {
    _execute('UPDATE exercises SET is_favorite = ? WHERE name = ?', [
      value ? 1 : 0,
      name,
    ]);
  }

  @override
  Future<void> saveRoutine(
    Routine routine, {
    required String groupName,
    String? originalName,
  }) async {
    _transaction(() {
      final groupId = _ensureRoutineGroup(groupName);
      final routineId = _routineIdByName(originalName ?? routine.name);
      if (routineId == null) {
        final nextOrder = _nextSortOrder('routines', 'group_id = ?', [groupId]);
        _execute(
          'INSERT INTO routines (group_id, name, note, sort_order) VALUES (?, ?, ?, ?)',
          [groupId, routine.name, routine.note, nextOrder],
        );
        _replaceRoutineExercises(_db.lastInsertRowId, routine);
      } else {
        _execute(
          'UPDATE routines SET group_id = ?, name = ?, note = ? WHERE id = ?',
          [groupId, routine.name, routine.note, routineId],
        );
        _replaceRoutineExercises(routineId, routine);
      }
    });
  }

  @override
  Future<void> saveRoutineOrder(List<RoutineGroup> groups) async {
    _transaction(() {
      for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        final group = groups[groupIndex];
        final groupId = _ensureRoutineGroup(group.name);
        _execute('UPDATE routine_groups SET sort_order = ? WHERE id = ?', [
          groupIndex,
          groupId,
        ]);
        for (
          var routineIndex = 0;
          routineIndex < group.routines.length;
          routineIndex++
        ) {
          final routineId = _routineIdByName(group.routines[routineIndex].name);
          if (routineId == null) continue;
          _execute(
            'UPDATE routines SET group_id = ?, sort_order = ? WHERE id = ?',
            [groupId, routineIndex, routineId],
          );
        }
      }
    });
  }

  @override
  Future<void> renameRoutineGroup(String originalName, String newName) async {
    _transaction(() {
      final groupId = _routineGroupIdByName(originalName);
      if (groupId == null) return;
      _execute('UPDATE routine_groups SET name = ? WHERE id = ?', [
        newName,
        groupId,
      ]);
    });
  }

  @override
  Future<void> deleteRoutineGroup(String groupName) async {
    _transaction(() {
      final groupId = _routineGroupIdByName(groupName);
      if (groupId == null) return;
      final routineCount =
          _db.select(
                'SELECT COUNT(*) AS count FROM routines WHERE group_id = ?',
                [groupId],
              ).first['count']
              as int;
      if (routineCount == 0) {
        _execute('DELETE FROM routine_groups WHERE id = ?', [groupId]);
      }
    });
  }

  @override
  Future<void> deleteRoutine(Routine routine) async {
    _transaction(() {
      final routineId = _routineIdByName(routine.name);
      if (routineId != null) {
        _execute('DELETE FROM routines WHERE id = ?', [routineId]);
      }
    });
  }

  @override
  Future<void> saveActiveWorkout(ActiveWorkout workout) async {
    _transaction(() {
      _clearActiveWorkoutUnsafe();
      final routineId = workout.routineName == null
          ? null
          : _routineIdByName(workout.routineName!);
      _execute(
        '''
        INSERT INTO active_workout_sessions (
          singleton_id, session_name, source, routine_id, routine_name_fallback,
          routine_group_name_fallback, started_at_ms
        ) VALUES (1, ?, ?, ?, ?, ?, ?)
        ''',
        [
          workout.sessionName,
          workout.source,
          routineId,
          workout.routineName,
          workout.routineGroupName,
          _ms(workout.startedAt),
        ],
      );
      for (
        var exerciseIndex = 0;
        exerciseIndex < workout.exercises.length;
        exerciseIndex++
      ) {
        final item = workout.exercises[exerciseIndex];
        final exerciseId = _upsertExercise(item.exercise);
        _execute(
          '''
          INSERT INTO active_workout_exercises (
            session_id, exercise_id, sort_order, rest_seconds
          ) VALUES (1, ?, ?, ?)
          ''',
          [exerciseId, exerciseIndex, item.restSeconds],
        );
        final activeExerciseId = _db.lastInsertRowId;
        for (var setIndex = 0; setIndex < item.sets.length; setIndex++) {
          final set = item.sets[setIndex];
          _execute(
            '''
            INSERT INTO active_workout_sets (
              active_exercise_id, set_position, kg_text, reps_text, completed,
              previous_label
            ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [
              activeExerciseId,
              setIndex + 1,
              set.kg.text.trim(),
              set.reps.text.trim(),
              set.completed ? 1 : 0,
              set.previousLabel,
            ],
          );
        }
      }
    });
  }

  @override
  Future<void> clearActiveWorkout() async {
    _transaction(_clearActiveWorkoutUnsafe);
  }

  @override
  Future<void> finishWorkout(ActiveWorkout workout) async {
    _transaction(() {
      // Which sets qualify to be recorded is decided by the shared
      // finish-workout rule in domain/finish_workout_service.dart, not
      // re-derived here, so this store can never disagree with the
      // in-memory store about what counts as "completed".
      final completed = completedSetEntriesForFinish(workout);
      if (completed.isNotEmpty) {
        final routineId = workout.routineName == null
            ? null
            : _routineIdByName(workout.routineName!);
        _execute(
          '''
          INSERT INTO completed_workout_sessions (
            session_name, source, routine_id, routine_name_fallback,
            routine_group_name_fallback, started_at_ms, completed_at_ms
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            workout.sessionName,
            workout.source,
            routineId,
            workout.routineName,
            workout.routineGroupName,
            _ms(workout.startedAt),
            _ms(DateTime.now()),
          ],
        );
        final sessionId = _db.lastInsertRowId;
        final exerciseRowIds = <WorkoutExercise, int>{};
        for (final record in completed) {
          final completedExerciseId = exerciseRowIds.putIfAbsent(
            record.exercise,
            () {
              final exerciseId = _upsertExercise(record.exercise.exercise);
              _execute(
                '''
              INSERT INTO completed_workout_exercises (
                session_id, exercise_id, sort_order, rest_seconds
              ) VALUES (?, ?, ?, ?)
              ''',
                [
                  sessionId,
                  exerciseId,
                  workout.exercises.indexOf(record.exercise),
                  record.exercise.restSeconds,
                ],
              );
              return _db.lastInsertRowId;
            },
          );
          _execute(
            '''
            INSERT INTO completed_workout_sets (
              completed_exercise_id, set_position, kg, reps, completed_at_ms
            ) VALUES (?, ?, ?, ?, ?)
            ''',
            [
              completedExerciseId,
              record.position,
              record.kg,
              record.reps,
              _ms(DateTime.now()),
            ],
          );
        }
        _rebuildSnapshotsUnsafe();
      }
      _clearActiveWorkoutUnsafe();
    });
  }

  @override
  Future<List<CompletedWorkout>> loadCompletedWorkouts() async {
    final sessions = _db.select('''
      SELECT s.id, s.session_name, r.name AS routine_name,
        s.routine_name_fallback, g.name AS group_name,
        s.routine_group_name_fallback, s.started_at_ms, s.completed_at_ms
      FROM completed_workout_sessions s
      LEFT JOIN routines r ON r.id = s.routine_id
      LEFT JOIN routine_groups g ON g.id = r.group_id
      ORDER BY s.completed_at_ms DESC, s.id DESC
      ''');
    return [
      for (final session in sessions)
        CompletedWorkout(
          id: session['id'] as int,
          sessionName: session['session_name'] as String,
          routineName:
              session['routine_name'] as String? ??
              session['routine_name_fallback'] as String?,
          routineGroupName:
              session['group_name'] as String? ??
              session['routine_group_name_fallback'] as String?,
          startedAt: _date(session['started_at_ms'] as int),
          completedAt: _date(session['completed_at_ms'] as int),
          exercises: [
            for (final exerciseRow in _db.select(
              '''
              SELECT ce.id, e.name AS exercise_name
              FROM completed_workout_exercises ce
              JOIN exercises e ON e.id = ce.exercise_id
              WHERE ce.session_id = ?
              ORDER BY ce.sort_order, ce.id
              ''',
              [session['id']],
            ))
              CompletedWorkoutExercise(
                exerciseName: exerciseRow['exercise_name'] as String,
                sets: [
                  for (final setRow in _db.select(
                    '''
                    SELECT kg, reps FROM completed_workout_sets
                    WHERE completed_exercise_id = ?
                    ORDER BY set_position, id
                    ''',
                    [exerciseRow['id']],
                  ))
                    (kg: setRow['kg'] as double, reps: setRow['reps'] as int),
                ],
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> updateCompletedExerciseSets(
    int sessionId,
    String exerciseName,
    List<({double kg, int reps})> sets,
  ) async {
    _transaction(() {
      final rows = _db.select(
        '''
        SELECT ce.id AS completed_exercise_id, s.completed_at_ms
        FROM completed_workout_exercises ce
        JOIN exercises e ON e.id = ce.exercise_id
        JOIN completed_workout_sessions s ON s.id = ce.session_id
        WHERE ce.session_id = ? AND e.name = ?
        LIMIT 1
        ''',
        [sessionId, exerciseName],
      );
      if (rows.isEmpty) return;
      final completedExerciseId = rows.first['completed_exercise_id'] as int;
      final sessionCompletedAtMs = rows.first['completed_at_ms'] as int;
      final existingCompletedAtByPosition = <int, int>{
        for (final row in _db.select(
          '''
          SELECT set_position, completed_at_ms
          FROM completed_workout_sets
          WHERE completed_exercise_id = ?
          ''',
          [completedExerciseId],
        ))
          row['set_position'] as int: row['completed_at_ms'] as int,
      };

      _execute(
        'DELETE FROM completed_workout_sets WHERE completed_exercise_id = ?',
        [completedExerciseId],
      );
      if (sets.isEmpty) {
        _execute('DELETE FROM completed_workout_exercises WHERE id = ?', [
          completedExerciseId,
        ]);
      } else {
        for (var index = 0; index < sets.length; index++) {
          final position = index + 1;
          final set = sets[index];
          _execute(
            '''
            INSERT INTO completed_workout_sets (
              completed_exercise_id, set_position, kg, reps, completed_at_ms
            ) VALUES (?, ?, ?, ?, ?)
            ''',
            [
              completedExerciseId,
              position,
              set.kg,
              set.reps,
              existingCompletedAtByPosition[position] ?? sessionCompletedAtMs,
            ],
          );
        }
      }
      _rebuildSnapshotsUnsafe();
    });
  }

  @override
  Future<void> updateCompletedWorkoutTimes(
    int sessionId,
    DateTime startedAt,
    DateTime completedAt,
  ) async {
    // Session times only affect the displayed duration/date; the per-set
    // completed_at_ms that drive Previous/Best snapshots are untouched.
    _execute(
      'UPDATE completed_workout_sessions '
      'SET started_at_ms = ?, completed_at_ms = ? WHERE id = ?',
      [_ms(startedAt), _ms(completedAt), sessionId],
    );
  }

  @override
  Future<List<MeasurementEntry>> loadMeasurements() async {
    final rows = _db.select(
      'SELECT * FROM measurement_entries ORDER BY date_ms DESC',
    );
    return [
      for (final row in rows)
        MeasurementEntry.fromColumns(
          _date(row['date_ms'] as int),
          row['photo_path'] as String?,
          {
            for (final field in measurementFields)
              field.column: row[field.column] as double?,
          },
        ),
    ];
  }

  @override
  Future<void> saveMeasurement(MeasurementEntry entry) async {
    final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
    final columns = [
      'date_ms',
      'photo_path',
      for (final field in measurementFields) field.column,
    ];
    final placeholders = List.filled(columns.length, '?').join(', ');
    _execute(
      'INSERT OR REPLACE INTO measurement_entries (${columns.join(', ')}) '
      'VALUES ($placeholders)',
      [
        _ms(date),
        entry.photoPath,
        for (final field in measurementFields) field.get(entry),
      ],
    );
  }

  @override
  Future<void> deleteMeasurement(DateTime date) async {
    final key = DateTime(date.year, date.month, date.day);
    _execute('DELETE FROM measurement_entries WHERE date_ms = ?', [_ms(key)]);
  }

  @override
  Future<void> close() async {
    _db.close();
  }

  int previousSnapshotCount() {
    return _count('previous_set_snapshots');
  }

  int bestSnapshotCount() {
    return _count('exercise_best_set_snapshots');
  }

  /// Returns the persisted Previous snapshot row for a given
  /// exercise + routine + set position, or null if none exists.
  ///
  /// Exposed for the DB audit tests so they can distinguish a value that came
  /// from the snapshot cache from a value that only lived in the in-memory
  /// session.
  ({double kg, int reps})? previousSnapshotForTesting({
    required String exerciseName,
    required String routineName,
    required int setPosition,
  }) {
    final rows = _db.select(
      '''
      SELECT p.kg, p.reps
      FROM previous_set_snapshots p
      JOIN exercises e ON e.id = p.exercise_id
      JOIN routines r ON r.id = p.routine_id
      WHERE e.name = ? AND r.name = ? AND p.set_position = ?
      ''',
      [exerciseName, routineName, setPosition],
    );
    if (rows.isEmpty) return null;
    return (kg: rows.first['kg'] as double, reps: rows.first['reps'] as int);
  }

  /// Returns all best-set snapshot rows (max weight + max volume, per source
  /// scope) for an exercise. Exposed for the DB audit tests.
  List<
    ({
      String sourceType,
      int? routineId,
      String kind,
      double kg,
      int reps,
      double volume,
    })
  >
  bestSnapshotsForTesting({required String exerciseName}) {
    return [
      for (final row in _db.select(
        '''
        SELECT b.routine_source_type, b.routine_id, b.best_kind, b.kg, b.reps,
          b.volume
        FROM exercise_best_set_snapshots b
        JOIN exercises e ON e.id = b.exercise_id
        WHERE e.name = ?
        ORDER BY b.routine_source_type, b.routine_id, b.best_kind
        ''',
        [exerciseName],
      ))
        (
          sourceType: row['routine_source_type'] as String,
          routineId: row['routine_id'] as int?,
          kind: row['best_kind'] as String,
          kg: row['kg'] as double,
          reps: row['reps'] as int,
          volume: row['volume'] as double,
        ),
    ];
  }

  void _seedPrototypeDataIfEmpty() {
    if (_count('exercises') > 0 || _count('routine_groups') > 0) return;
    _transaction(() {
      final exercises = prototypeExercises();
      for (final exercise in exercises) {
        _upsertExercise(exercise);
      }
      for (
        var groupIndex = 0;
        groupIndex < prototypeGroups(exercises).length;
        groupIndex++
      ) {
        final group = prototypeGroups(exercises)[groupIndex];
        final groupId = _ensureRoutineGroup(group.name, sortOrder: groupIndex);
        for (
          var routineIndex = 0;
          routineIndex < group.routines.length;
          routineIndex++
        ) {
          final routine = group.routines[routineIndex];
          _execute(
            'INSERT INTO routines (group_id, name, note, sort_order) VALUES (?, ?, ?, ?)',
            [groupId, routine.name, routine.note, routineIndex],
          );
          _replaceRoutineExercises(_db.lastInsertRowId, routine);
        }
      }
      _insertHistoryRecords(prototypeHistory(exercises).records);
      _rebuildSnapshotsUnsafe();
    });
  }

  List<Exercise> _loadExercises() {
    final rows = _db.select('''
      SELECT e.id, e.name, e.icon_path, e.is_favorite,
             m.name AS muscle, q.name AS equipment
      FROM exercises e
      JOIN muscles m ON m.id = e.primary_muscle_id
      JOIN equipment q ON q.id = e.equipment_id
      ORDER BY e.name
      ''');
    return [
      for (final row in rows)
        Exercise(
          row['name'] as String,
          row['muscle'] as String,
          row['equipment'] as String,
          _secondaryMuscles(row['id'] as int),
          row['icon_path'] as String?,
          _exerciseMedia(row['id'] as int),
          (row['is_favorite'] as int) != 0,
        ),
    ];
  }

  List<RoutineGroup> _loadGroups(List<Exercise> exercises) {
    final byName = {for (final exercise in exercises) exercise.name: exercise};
    final groupRows = _db.select(
      'SELECT id, name FROM routine_groups ORDER BY sort_order, id',
    );
    return [
      for (final groupRow in groupRows)
        RoutineGroup(groupRow['name'] as String, [
          for (final routineRow in _db.select(
            'SELECT id, name, note FROM routines WHERE group_id = ? ORDER BY sort_order, id',
            [groupRow['id']],
          ))
            Routine(
              routineRow['name'] as String,
              routineRow['note'] as String,
              _loadRoutineExercises(routineRow['id'] as int, byName),
            ),
        ]),
    ];
  }

  List<RoutineExercise> _loadRoutineExercises(
    int routineId,
    Map<String, Exercise> byName,
  ) {
    final rows = _db.select(
      '''
      SELECT re.id, re.rest_seconds, e.name AS exercise_name
      FROM routine_exercises re
      JOIN exercises e ON e.id = re.exercise_id
      WHERE re.routine_id = ?
      ORDER BY re.sort_order, re.id
      ''',
      [routineId],
    );
    return [
      for (final row in rows)
        RoutineExercise(
          byName[row['exercise_name']]!,
          _db.select(
                'SELECT COUNT(*) AS count FROM routine_sets WHERE routine_exercise_id = ?',
                [row['id']],
              ).first['count']
              as int,
          row['rest_seconds'] as int?,
        ),
    ];
  }

  List<CompletedSetRecord> _loadHistoryRecords() {
    final rows = _db.select('''
      SELECT e.name AS exercise_name, r.name AS routine_name,
        s.routine_name_fallback, g.name AS group_name,
        s.routine_group_name_fallback, cs.set_position, cs.kg, cs.reps,
        cs.completed_at_ms
      FROM completed_workout_sets cs
      JOIN completed_workout_exercises ce ON ce.id = cs.completed_exercise_id
      JOIN completed_workout_sessions s ON s.id = ce.session_id
      JOIN exercises e ON e.id = ce.exercise_id
      LEFT JOIN routines r ON r.id = s.routine_id
      LEFT JOIN routine_groups g ON g.id = r.group_id
      ORDER BY cs.completed_at_ms
      ''');
    return [
      for (final row in rows)
        CompletedSetRecord(
          exerciseName: row['exercise_name'] as String,
          routineName:
              row['routine_name'] as String? ??
              row['routine_name_fallback'] as String? ??
              'No Routine',
          routineGroupName:
              row['group_name'] as String? ??
              row['routine_group_name_fallback'] as String? ??
              'No Group',
          setPosition: row['set_position'] as int,
          kg: row['kg'] as double,
          reps: row['reps'] as int,
          completedAt: _date(row['completed_at_ms'] as int),
        ),
    ];
  }

  ActiveWorkout? _loadActiveWorkout(List<Exercise> exercises) {
    final sessionRows = _db.select(
      'SELECT * FROM active_workout_sessions LIMIT 1',
    );
    if (sessionRows.isEmpty) return null;
    final session = sessionRows.first;
    final byName = {for (final exercise in exercises) exercise.name: exercise};
    final workoutExercises = <WorkoutExercise>[];
    final exerciseRows = _db.select('''
      SELECT ae.id, ae.rest_seconds, e.name AS exercise_name
      FROM active_workout_exercises ae
      JOIN exercises e ON e.id = ae.exercise_id
      WHERE ae.session_id = 1
      ORDER BY ae.sort_order, ae.id
      ''');
    for (final row in exerciseRows) {
      final sets = [
        for (final setRow in _db.select(
          '''
          SELECT set_position, kg_text, reps_text, completed, previous_label
          FROM active_workout_sets
          WHERE active_exercise_id = ?
          ORDER BY set_position
          ''',
          [row['id']],
        ))
          WorkoutSet(
            kgText: setRow['kg_text'] as String?,
            repsText: setRow['reps_text'] as String?,
            previousLabel: setRow['previous_label'] as String?,
          )..completed = (setRow['completed'] as int) == 1,
      ];
      workoutExercises.add(
        WorkoutExercise(
          byName[row['exercise_name']]!,
          row['rest_seconds'] as int?,
          sets,
        ),
      );
    }
    return ActiveWorkout(
      sessionName: session['session_name'] as String,
      source: session['source'] as String,
      exercises: workoutExercises,
      routineName: session['routine_name_fallback'] as String?,
      routineGroupName: session['routine_group_name_fallback'] as String?,
      startedAt: _date(session['started_at_ms'] as int),
    );
  }

  int _upsertExercise(Exercise exercise, {String? originalName}) {
    final existing = _db.select('SELECT id FROM exercises WHERE name = ?', [
      originalName ?? exercise.name,
    ]);
    final muscleId = _ensureMuscle(exercise.muscle);
    final equipmentId = _ensureEquipment(exercise.equipment);
    final exerciseId = existing.isEmpty ? null : existing.first['id'] as int;
    if (exerciseId == null) {
      _execute(
        '''
        INSERT INTO exercises (
          name, primary_muscle_id, equipment_id, icon_path
        ) VALUES (?, ?, ?, ?)
        ''',
        [exercise.name, muscleId, equipmentId, exercise.thumbnailPath],
      );
      final createdId = _db.lastInsertRowId;
      _replaceSecondaryMuscles(createdId, exercise.secondaryMuscles);
      _replaceExerciseMedia(createdId, exercise.media);
      return createdId;
    }
    _execute(
      '''
      UPDATE exercises
      SET name = ?, primary_muscle_id = ?, equipment_id = ?, icon_path = ?
      WHERE id = ?
      ''',
      [
        exercise.name,
        muscleId,
        equipmentId,
        exercise.thumbnailPath,
        exerciseId,
      ],
    );
    _replaceSecondaryMuscles(exerciseId, exercise.secondaryMuscles);
    _replaceExerciseMedia(exerciseId, exercise.media);
    return exerciseId;
  }

  int _ensureMuscle(String name) {
    return _ensureNamedRow('muscles', name);
  }

  int _ensureEquipment(String name) {
    return _ensureNamedRow('equipment', name);
  }

  int _ensureRoutineGroup(String name, {int? sortOrder}) {
    final rows = _db.select('SELECT id FROM routine_groups WHERE name = ?', [
      name,
    ]);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    _execute('INSERT INTO routine_groups (name, sort_order) VALUES (?, ?)', [
      name,
      sortOrder ?? _nextSortOrder('routine_groups'),
    ]);
    return _db.lastInsertRowId;
  }

  int _ensureNamedRow(String table, String name) {
    final rows = _db.select('SELECT id FROM $table WHERE name = ?', [name]);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    _execute('INSERT INTO $table (name) VALUES (?)', [name]);
    return _db.lastInsertRowId;
  }

  void _replaceSecondaryMuscles(int exerciseId, List<String> muscles) {
    _execute('DELETE FROM exercise_secondary_muscles WHERE exercise_id = ?', [
      exerciseId,
    ]);
    for (final muscle in muscles) {
      _execute(
        'INSERT INTO exercise_secondary_muscles (exercise_id, muscle_id) VALUES (?, ?)',
        [exerciseId, _ensureMuscle(muscle)],
      );
    }
  }

  void _replaceExerciseMedia(int exerciseId, List<ExerciseMedia> media) {
    _execute('DELETE FROM exercise_media WHERE exercise_id = ?', [exerciseId]);
    for (var index = 0; index < media.length; index++) {
      final item = media[index];
      _execute(
        '''
        INSERT INTO exercise_media (
          exercise_id, relative_path, media_type, sort_order
        ) VALUES (?, ?, ?, ?)
        ''',
        [exerciseId, item.path, item.type.name, index],
      );
    }
  }

  List<ExerciseMedia> _exerciseMedia(int exerciseId) {
    return [
      for (final row in _db.select(
        '''
        SELECT relative_path, media_type
        FROM exercise_media
        WHERE exercise_id = ?
        ORDER BY sort_order, id
        ''',
        [exerciseId],
      ))
        ExerciseMedia(
          path: row['relative_path'] as String,
          type: row['media_type'] == ExerciseMediaType.video.name
              ? ExerciseMediaType.video
              : ExerciseMediaType.image,
        ),
    ];
  }

  void _replaceRoutineExercises(int routineId, Routine routine) {
    _execute('DELETE FROM routine_exercises WHERE routine_id = ?', [routineId]);
    for (var index = 0; index < routine.exercises.length; index++) {
      final item = routine.exercises[index];
      _execute(
        '''
        INSERT INTO routine_exercises (
          routine_id, exercise_id, sort_order, rest_seconds
        ) VALUES (?, ?, ?, ?)
        ''',
        [routineId, _upsertExercise(item.exercise), index, item.restSeconds],
      );
      final routineExerciseId = _db.lastInsertRowId;
      for (var setPosition = 1; setPosition <= item.sets; setPosition++) {
        _execute(
          'INSERT INTO routine_sets (routine_exercise_id, set_position) VALUES (?, ?)',
          [routineExerciseId, setPosition],
        );
      }
    }
  }

  void _insertHistoryRecords(List<CompletedSetRecord> records) {
    for (final record in records) {
      final exerciseId = _exerciseIdByName(record.exerciseName);
      final routineId = _routineIdByName(record.routineName);
      if (exerciseId == null) continue;
      _execute(
        '''
        INSERT INTO completed_workout_sessions (
          session_name, source, routine_id, routine_name_fallback,
          routine_group_name_fallback, started_at_ms, completed_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          '${record.routineName} ${formatSessionTimestamp(record.completedAt)}',
          record.routineName,
          routineId,
          record.routineName,
          record.routineGroupName,
          _ms(record.completedAt),
          _ms(record.completedAt),
        ],
      );
      final sessionId = _db.lastInsertRowId;
      _execute(
        '''
        INSERT INTO completed_workout_exercises (
          session_id, exercise_id, sort_order, rest_seconds
        ) VALUES (?, ?, 0, NULL)
        ''',
        [sessionId, exerciseId],
      );
      _execute(
        '''
        INSERT INTO completed_workout_sets (
          completed_exercise_id, set_position, kg, reps, completed_at_ms
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        [
          _db.lastInsertRowId,
          record.setPosition,
          record.kg,
          record.reps,
          _ms(record.completedAt),
        ],
      );
    }
  }

  void _rebuildSnapshotsUnsafe() {
    _execute('DELETE FROM previous_set_snapshots');
    _execute('DELETE FROM exercise_best_set_snapshots');
    _execute('''
      INSERT INTO previous_set_snapshots (
        exercise_id, routine_id, set_position, completed_set_id, kg, reps,
        completed_at_ms
      )
      SELECT exercise_id, routine_id, set_position, completed_set_id, kg, reps,
        completed_at_ms
      FROM (
        SELECT ce.exercise_id, s.routine_id, cs.set_position,
          cs.id AS completed_set_id, cs.kg, cs.reps, cs.completed_at_ms,
          ROW_NUMBER() OVER (
            PARTITION BY ce.exercise_id, s.routine_id, cs.set_position
            ORDER BY cs.completed_at_ms DESC, cs.id DESC
          ) AS rank
        FROM completed_workout_sets cs
        JOIN completed_workout_exercises ce ON ce.id = cs.completed_exercise_id
        JOIN completed_workout_sessions s ON s.id = ce.session_id
        WHERE s.routine_id IS NOT NULL
      )
      WHERE rank = 1
      ''');
    _insertBestSnapshots('all', null, null);
    for (final row in _db.select(
      'SELECT DISTINCT routine_id FROM completed_workout_sessions WHERE routine_id IS NOT NULL',
    )) {
      _insertBestSnapshots(
        'routine',
        row['routine_id'] as int,
        row['routine_id'] as int,
      );
    }
    _insertBestSnapshots('no_routine', null, -1);
  }

  void _insertBestSnapshots(
    String sourceType,
    int? routineId,
    int? filterRoutineId,
  ) {
    const baseQuery = '''
      SELECT ce.exercise_id, cs.id AS completed_set_id, cs.kg, cs.reps,
        (cs.kg * cs.reps) AS volume, cs.completed_at_ms,
        ROW_NUMBER() OVER (
          PARTITION BY ce.exercise_id
          ORDER BY cs.kg * cs.reps DESC, cs.kg DESC, cs.reps DESC, cs.id DESC
        ) AS volume_rank,
        ROW_NUMBER() OVER (
          PARTITION BY ce.exercise_id
          ORDER BY cs.kg DESC, cs.reps DESC, cs.id DESC
        ) AS weight_rank
      FROM completed_workout_sets cs
      JOIN completed_workout_exercises ce ON ce.id = cs.completed_exercise_id
      JOIN completed_workout_sessions s ON s.id = ce.session_id
    ''';
    final where = filterRoutineId == null
        ? ''
        : filterRoutineId == -1
        ? 'WHERE s.routine_id IS NULL'
        : 'WHERE s.routine_id = ?';
    final args = filterRoutineId == null || filterRoutineId == -1
        ? const <Object?>[]
        : <Object?>[filterRoutineId];
    for (final kind in ['volume', 'weight']) {
      _execute(
        '''
        INSERT INTO exercise_best_set_snapshots (
          exercise_id, routine_source_type, routine_id, best_kind,
          completed_set_id, kg, reps, volume, completed_at_ms
        )
        SELECT exercise_id, ?, ?, ?, completed_set_id, kg, reps, volume,
          completed_at_ms
        FROM ($baseQuery $where)
        WHERE ${kind}_rank = 1
        ''',
        [sourceType, routineId, kind, ...args],
      );
    }
  }

  void _clearActiveWorkoutUnsafe() {
    _execute('DELETE FROM active_workout_sessions');
  }

  List<String> _secondaryMuscles(int exerciseId) {
    return [
      for (final row in _db.select(
        '''
        SELECT m.name
        FROM exercise_secondary_muscles esm
        JOIN muscles m ON m.id = esm.muscle_id
        WHERE esm.exercise_id = ?
        ORDER BY esm.id
        ''',
        [exerciseId],
      ))
        row['name'] as String,
    ];
  }

  int? _exerciseIdByName(String name) {
    final rows = _db.select('SELECT id FROM exercises WHERE name = ?', [name]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  int? _routineIdByName(String name) {
    final rows = _db.select('SELECT id FROM routines WHERE name = ?', [name]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  int? _routineGroupIdByName(String name) {
    final rows = _db.select('SELECT id FROM routine_groups WHERE name = ?', [
      name,
    ]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  int _nextSortOrder(
    String table, [
    String? where,
    List<Object?> args = const [],
  ]) {
    final clause = where == null ? '' : ' WHERE $where';
    final row = _db
        .select(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM $table$clause',
          args,
        )
        .first;
    return row['next_order'] as int;
  }

  int _count(String table) {
    return _db.select('SELECT COUNT(*) AS count FROM $table').first['count']
        as int;
  }

  void _execute(String sql, [List<Object?> parameters = const []]) {
    final statement = _db.prepare(sql);
    try {
      statement.execute(parameters);
    } finally {
      statement.close();
    }
  }

  void _transaction(void Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  int _ms(DateTime value) {
    return value.millisecondsSinceEpoch;
  }

  DateTime _date(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}

const _schemaV1 = '''
CREATE TABLE muscles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE equipment (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  primary_muscle_id INTEGER NOT NULL REFERENCES muscles(id),
  equipment_id INTEGER NOT NULL REFERENCES equipment(id),
  icon_path TEXT
);

CREATE TABLE exercise_secondary_muscles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  muscle_id INTEGER NOT NULL REFERENCES muscles(id),
  UNIQUE(exercise_id, muscle_id)
);

CREATE TABLE exercise_media (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  relative_path TEXT NOT NULL,
  media_type TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE routine_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE routines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL REFERENCES routine_groups(id),
  name TEXT NOT NULL UNIQUE,
  note TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE routine_exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  routine_id INTEGER NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id),
  sort_order INTEGER NOT NULL DEFAULT 0,
  rest_seconds INTEGER
);

CREATE TABLE routine_sets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  routine_exercise_id INTEGER NOT NULL REFERENCES routine_exercises(id) ON DELETE CASCADE,
  set_position INTEGER NOT NULL
);

CREATE TABLE active_workout_sessions (
  singleton_id INTEGER PRIMARY KEY CHECK(singleton_id = 1),
  session_name TEXT NOT NULL,
  source TEXT NOT NULL,
  routine_id INTEGER REFERENCES routines(id) ON DELETE SET NULL,
  routine_name_fallback TEXT,
  routine_group_name_fallback TEXT,
  started_at_ms INTEGER NOT NULL
);

CREATE TABLE active_workout_exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL REFERENCES active_workout_sessions(singleton_id) ON DELETE CASCADE,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id),
  sort_order INTEGER NOT NULL DEFAULT 0,
  rest_seconds INTEGER
);

CREATE TABLE active_workout_sets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  active_exercise_id INTEGER NOT NULL REFERENCES active_workout_exercises(id) ON DELETE CASCADE,
  set_position INTEGER NOT NULL,
  kg_text TEXT,
  reps_text TEXT,
  completed INTEGER NOT NULL DEFAULT 0,
  previous_label TEXT
);

CREATE TABLE completed_workout_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_name TEXT NOT NULL,
  source TEXT NOT NULL,
  routine_id INTEGER REFERENCES routines(id) ON DELETE SET NULL,
  routine_name_fallback TEXT,
  routine_group_name_fallback TEXT,
  started_at_ms INTEGER NOT NULL,
  completed_at_ms INTEGER NOT NULL
);

CREATE TABLE completed_workout_exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL REFERENCES completed_workout_sessions(id) ON DELETE CASCADE,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id),
  sort_order INTEGER NOT NULL DEFAULT 0,
  rest_seconds INTEGER
);

CREATE TABLE completed_workout_sets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  completed_exercise_id INTEGER NOT NULL REFERENCES completed_workout_exercises(id) ON DELETE CASCADE,
  set_position INTEGER NOT NULL,
  kg REAL NOT NULL,
  reps INTEGER NOT NULL,
  completed_at_ms INTEGER NOT NULL
);

CREATE TABLE previous_set_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  routine_id INTEGER NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  set_position INTEGER NOT NULL,
  completed_set_id INTEGER NOT NULL REFERENCES completed_workout_sets(id) ON DELETE CASCADE,
  kg REAL NOT NULL,
  reps INTEGER NOT NULL,
  completed_at_ms INTEGER NOT NULL,
  UNIQUE(exercise_id, routine_id, set_position)
);

CREATE TABLE exercise_best_set_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  routine_source_type TEXT NOT NULL,
  routine_id INTEGER REFERENCES routines(id) ON DELETE CASCADE,
  best_kind TEXT NOT NULL,
  completed_set_id INTEGER NOT NULL REFERENCES completed_workout_sets(id) ON DELETE CASCADE,
  kg REAL NOT NULL,
  reps INTEGER NOT NULL,
  volume REAL NOT NULL,
  completed_at_ms INTEGER NOT NULL,
  UNIQUE(exercise_id, routine_source_type, routine_id, best_kind)
);

CREATE INDEX idx_completed_sets_previous
  ON completed_workout_sets(completed_exercise_id, set_position, completed_at_ms);
CREATE INDEX idx_completed_sessions_routine
  ON completed_workout_sessions(routine_id, completed_at_ms);
CREATE INDEX idx_best_snapshots_source
  ON exercise_best_set_snapshots(exercise_id, routine_source_type, routine_id, best_kind);
''';
