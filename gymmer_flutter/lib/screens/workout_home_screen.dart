/// App shell + home (Workout) tab state. Owns the WorkoutStore lifecycle,
/// bottom navigation (Workout / Library), resume bar, and every routine /
/// folder mutation (start, move, delete, rename) which it persists through
/// the store.
///
/// Pure display widgets live in `widgets/home/`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/widget_bridge.dart';
import '../data/workout_store.dart';
import '../data/workout_store_factory.dart';
import '../domain/finish_workout_service.dart';
import '../domain/records_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/home/home_widgets.dart';
import '../widgets/home/routine_group_section.dart';
import 'active_workout_page.dart';
import 'exercise_library_page.dart';
import 'profile/profile_tab.dart';
import 'routine_builder_page.dart';

class GymmerHome extends StatefulWidget {
  const GymmerHome({super.key, this.store});

  final WorkoutStore? store;

  @override
  State<GymmerHome> createState() => _GymmerHomeState();
}

class _GymmerHomeState extends State<GymmerHome> with WidgetsBindingObserver {
  List<Exercise> exercises = [];
  WorkoutHistory history = WorkoutHistory([]);
  List<RoutineGroup> groups = [];
  WorkoutStore? store;
  bool ownsStore = false;
  bool loading = true;
  Object? loadError;
  ActiveWorkout? activeWorkout;

  /// Highest `rev` we've written to / read from the widget's session.json, so
  /// resume-reconciliation only rebuilds when the WIDGET wrote something newer.
  int _lastWidgetRev = 0;

  int _tabIndex = 0;
  final Set<String> _collapsedGroups = {};

  final ScrollController _homeScrollController = ScrollController();
  Timer? _autoScrollTimer;
  double _autoScrollDir = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadStore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoScroll();
    _homeScrollController.dispose();
    activeWorkout?.dispose();
    if (ownsStore) {
      unawaited(store?.close());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Keep the widget's static snapshots fresh (routines/exercises may have
      // changed) and pull back any edits the widget made while backgrounded.
      unawaited(WidgetBridge.writeCatalog(exercises, history));
      unawaited(WidgetBridge.writeRoutines(groups, history));
      unawaited(_reconcileWidgetSession());
    }
  }

  Future<void> _loadStore() async {
    try {
      final openedStore = widget.store ?? await openWorkoutStore();
      final state = await openedStore.load();
      if (!mounted) {
        if (widget.store == null) await openedStore.close();
        return;
      }
      setState(() {
        store = openedStore;
        ownsStore = widget.store == null;
        exercises = state.exercises;
        groups = state.groups;
        history = state.history;
        activeWorkout = state.activeWorkout;
        loading = false;
      });
      unawaited(WidgetBridge.writeCatalog(state.exercises, state.history));
      unawaited(WidgetBridge.writeRoutines(state.groups, state.history));
      _pushSessionToWidget(state.activeWorkout);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = error;
        loading = false;
      });
    }
  }

  Future<void> _reloadFromStore() async {
    final currentStore = store;
    if (currentStore == null) return;
    final state = await currentStore.load();
    if (!mounted) return;
    setState(() {
      exercises = state.exercises;
      groups = state.groups;
      history = state.history;
      activeWorkout = state.activeWorkout;
    });
    unawaited(WidgetBridge.writeCatalog(state.exercises, state.history));
    unawaited(WidgetBridge.writeRoutines(state.groups, state.history));
    _pushSessionToWidget(state.activeWorkout);
  }

  void _saveActiveWorkoutDraft(ActiveWorkout workout) {
    final currentStore = store;
    if (currentStore == null) return;
    unawaited(currentStore.saveActiveWorkout(workout));
    _pushSessionToWidget(workout);
  }

  /// Writes [workout] (or an inactive marker) to the widget's session.json and
  /// remembers the `rev` so our own writes don't trigger a resume-rebuild.
  void _pushSessionToWidget(ActiveWorkout? workout) {
    final snapshot = WidgetBridge.encodeSession(workout);
    _lastWidgetRev = snapshot['rev'] as int? ?? _lastWidgetRev;
    unawaited(WidgetBridge.writeSession(workout));
  }

  /// On resume, pull back session.json. If the WIDGET wrote a newer revision
  /// (its App Intents mutated the session while we were backgrounded), rebuild
  /// the in-app workout from it and persist to SQLite so both stay in sync.
  Future<void> _reconcileWidgetSession() async {
    final currentStore = store;
    if (currentStore == null) return;
    final session = await WidgetBridge.readSession();
    if (session == null) return;
    if (session['by'] != 'widget') return;
    final rev = session['rev'];
    if (rev is! int || rev <= _lastWidgetRev) return;
    _lastWidgetRev = rev;

    if (session['active'] != true) {
      // Widget finished or discarded the session while we were away.
      if (session['outcome'] == 'finish') {
        final finished = WidgetBridge.buildWorkoutFromSession(
          session,
          exercises,
        );
        if (finished != null) {
          await currentStore.finishWorkout(finished);
          finished.dispose();
        }
      }
      await currentStore.clearActiveWorkout();
      if (!mounted) return;
      activeWorkout?.dispose();
      setState(() => activeWorkout = null);
      return;
    }

    final rebuilt = WidgetBridge.sessionToWorkout(session, exercises);
    if (rebuilt == null) return;
    await currentStore.saveActiveWorkout(rebuilt);
    if (!mounted) {
      rebuilt.dispose();
      return;
    }
    final previous = activeWorkout;
    setState(() => activeWorkout = rebuilt);
    previous?.dispose();
  }

  Future<void> startEmptyWorkout() async {
    setState(() {
      activeWorkout ??= ActiveWorkout.noRoutine();
    });
    _saveActiveWorkoutDraft(activeWorkout!);
    _openActiveWorkout();
  }

  Future<void> startRoutine(Routine routine) async {
    final group = groupForRoutine(routine);
    setState(() {
      activeWorkout ??= ActiveWorkout.fromRoutine(
        routine,
        groupName: group.name,
        history: history,
      );
    });
    _saveActiveWorkoutDraft(activeWorkout!);
    _openActiveWorkout();
  }

  RoutineGroup groupForRoutine(Routine routine) {
    return groups.firstWhere(
      (group) => group.routines.contains(routine),
      orElse: () => groups.first,
    );
  }

  /// Moves [routine] into [targetGroup]. When [before] is given the routine is
  /// inserted just above it (drop-on-card reorder); otherwise it is appended
  /// (drop-on-folder-header). Persists the full ordering via [saveRoutineOrder].
  void moveRoutineTo(
    Routine routine,
    RoutineGroup targetGroup, {
    Routine? before,
  }) {
    if (identical(before, routine)) return;
    setState(() {
      final sourceGroup = groupForRoutine(routine);
      sourceGroup.routines.remove(routine);
      if (before != null) {
        final index = targetGroup.routines.indexOf(before);
        targetGroup.routines.insert(
          index < 0 ? targetGroup.routines.length : index,
          routine,
        );
      } else {
        targetGroup.routines.add(routine);
      }
    });
    unawaited(store?.saveRoutineOrder(groups));
  }

  Future<void> deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: Text('“${routine.name}” will be removed from this folder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => groupForRoutine(routine).routines.remove(routine));
    unawaited(store?.deleteRoutine(routine));
  }

  void moveRoutineGroup(RoutineGroup group, int direction) {
    setState(() {
      final from = groups.indexOf(group);
      final to = from + direction;
      if (from < 0 || to < 0 || to >= groups.length) return;
      final item = groups.removeAt(from);
      groups.insert(to, item);
    });
    unawaited(store?.saveRoutineOrder(groups));
  }

  Future<void> renameRoutineGroup(RoutineGroup group) async {
    final controller = TextEditingController(text: group.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted ||
        newName == null ||
        newName.isEmpty ||
        newName == group.name) {
      return;
    }
    if (groups.any((item) => item != group && item.name == newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder name already exists.')),
      );
      return;
    }
    final originalName = group.name;
    setState(() => group.name = newName);
    await store?.renameRoutineGroup(originalName, newName);
    await _reloadFromStore();
  }

  Future<void> deleteRoutineGroup(RoutineGroup group) async {
    if (group.routines.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only empty folders can be deleted.')),
      );
      return;
    }
    setState(() => groups.remove(group));
    await store?.deleteRoutineGroup(group.name);
    await _reloadFromStore();
  }

  Future<void> _openActiveWorkout() async {
    final workout = activeWorkout;
    if (workout == null) return;
    var finishedRecords = 0;
    final finished = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutPage(
          workout: workout,
          exercises: exercises,
          onChanged: _saveActiveWorkoutDraft,
          onFinish: (finishedWorkout) async {
            // Count PRs against the sessions that already exist (all earlier).
            final built = buildCompletedWorkout(
              finishedWorkout,
              completedAt: DateTime.now(),
            );
            final existing = await store?.loadCompletedWorkouts() ?? const [];
            finishedRecords = recordsIn(built, existing);
            await store?.finishWorkout(finishedWorkout);
            await _reloadFromStore();
          },
        ),
      ),
    );
    if (!mounted) return;
    if (finished == true) {
      await store?.clearActiveWorkout();
      activeWorkout?.dispose();
      setState(() => activeWorkout = null);
      _pushSessionToWidget(null);
      await _reloadFromStore();
      if (finishedRecords > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🏅 $finishedRecords new record${finishedRecords == 1 ? '' : 's'}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openRoutineBuilder({Routine? routine}) async {
    final draft =
        routine?.copy() ?? Routine('New Routine', 'No exercises yet', []);
    final currentGroup = routine == null
        ? (groups.isEmpty ? 'My Routines' : groups.first.name)
        : groupForRoutine(routine).name;
    final result = await Navigator.of(context).push<RoutineBuilderResult>(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderPage(
          draft: draft,
          exercises: exercises,
          groupNames: groups.map((group) => group.name).toList(),
          initialGroupName: currentGroup,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    final saved = result.routine;
    final originalName = routine?.name;
    setState(() {
      final originalGroup = routine == null ? null : groupForRoutine(routine);
      originalGroup?.routines.removeWhere((item) => item.name == originalName);
      final targetGroup = groups.firstWhere(
        (group) => group.name == result.groupName,
        orElse: () {
          final created = RoutineGroup(result.groupName, []);
          groups.add(created);
          return created;
        },
      );
      final index = targetGroup.routines.indexWhere(
        (item) => item.name == originalName || item.name == saved.name,
      );
      if (index >= 0) {
        targetGroup.routines[index] = saved;
      } else {
        targetGroup.routines.add(saved);
      }
    });
    await store?.saveRoutine(
      saved,
      groupName: result.groupName,
      originalName: routine?.name,
    );
    await _reloadFromStore();
  }

  void _onSelectTab(int index) {
    setState(() => _tabIndex = index);
    if (index == 0) unawaited(_reloadFromStore());
  }

  // ---- Drag auto-scroll near viewport edges -------------------------------

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_homeScrollController.hasClients) return;
    final media = MediaQuery.of(context);
    final dy = details.globalPosition.dy;
    const edge = 96.0;
    final topEdge = media.padding.top + edge;
    final bottomEdge = media.size.height - edge;
    if (dy < topEdge) {
      _autoScrollDir = -1;
      _startAutoScroll();
    } else if (dy > bottomEdge) {
      _autoScrollDir = 1;
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_homeScrollController.hasClients) return;
      final position = _homeScrollController.position;
      final next = (position.pixels + _autoScrollDir * 14).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) {
        _stopAutoScroll();
        return;
      }
      position.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final error = loadError;
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not open local workout data: $error'),
          ),
        ),
      );
    }
    return Scaffold(
      body: switch (_tabIndex) {
        0 => SafeArea(bottom: false, child: _buildWorkoutTab()),
        1 => ExerciseLibraryPage(
          exercises: exercises,
          onSaveExercise: (exercise, {originalName}) async {
            await store?.saveExercise(exercise, originalName: originalName);
          },
          onToggleFavorite: (exercise, value) async {
            await store?.setExerciseFavorite(exercise.name, value);
          },
        ),
        _ => ProfileTab(
          store: store!,
          loadCompletedWorkouts: () async =>
              await store?.loadCompletedWorkouts() ?? const [],
          loadMeasurements: () async =>
              await store?.loadMeasurements() ?? const [],
          saveMeasurement: (entry) async => await store?.saveMeasurement(entry),
          deleteMeasurement: (date) async =>
              await store?.deleteMeasurement(date),
        ),
      },
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (activeWorkout != null)
          ResumeBar(
            label: activeWorkout!.sessionName,
            onResume: _openActiveWorkout,
          ),
        NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _onSelectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Workout',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkoutTab() {
    return SlidableAutoCloseBehavior(
      child: CustomScrollView(
        controller: _homeScrollController,
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: WorkoutHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: QuickActions(
                onStartEmpty: startEmptyWorkout,
                onNewRoutine: () => _openRoutineBuilder(),
              ),
            ),
          ),
          if (groups.isEmpty)
            const SliverToBoxAdapter(child: EmptyHome())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              sliver: SliverList.separated(
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 22),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return RoutineGroupSection(
                    group: group,
                    collapsed: _collapsedGroups.contains(group.name),
                    onToggleCollapsed: (group) {
                      setState(() {
                        if (!_collapsedGroups.remove(group.name)) {
                          _collapsedGroups.add(group.name);
                        }
                      });
                    },
                    onStart: startRoutine,
                    onEdit: (routine) => _openRoutineBuilder(routine: routine),
                    onDelete: deleteRoutine,
                    onMoveRoutineTo: moveRoutineTo,
                    onDragUpdate: _handleDragUpdate,
                    onDragEnd: _stopAutoScroll,
                    onRenameGroup: renameRoutineGroup,
                    onMoveGroupUp: (group) => moveRoutineGroup(group, -1),
                    onMoveGroupDown: (group) => moveRoutineGroup(group, 1),
                    onDeleteGroup: deleteRoutineGroup,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
