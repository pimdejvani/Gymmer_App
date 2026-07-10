/// Profile → Calendar: a streak-chips header over a vertical list of month
/// grids from the earliest workout month to the current month (newest at the
/// bottom; auto-scrolls to the bottom on open).
library;

import 'package:flutter/material.dart';

import '../../domain/streaks.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/month_grid.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.workouts, required this.now});

  final List<CompletedWorkout> workouts;
  final DateTime now;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<(int year, int month)> _months() {
    final now = widget.now;
    var earliest = DateTime(now.year, now.month);
    for (final workout in widget.workouts) {
      final started = DateTime(workout.startedAt.year, workout.startedAt.month);
      if (started.isBefore(earliest)) earliest = started;
    }
    final months = <(int, int)>[];
    var cursor = earliest;
    final end = DateTime(now.year, now.month);
    while (!cursor.isAfter(end)) {
      months.add((cursor.year, cursor.month));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  Map<int, String> _labelsFor(int year, int month) {
    final labels = <int, String>{};
    for (final workout in widget.workouts) {
      final started = workout.startedAt;
      if (started.year == year && started.month == month) {
        labels[started.day] = workout.routineName ?? workout.sessionName;
      }
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final workoutDays = [for (final w in widget.workouts) w.startedAt];
    final streak = weekStreak(workoutDays, now: widget.now);
    final restDays = restDaysThisWeek(workoutDays, now: widget.now);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Chip(text: '🔥 $streak week streak'),
                const SizedBox(width: 12),
                _Chip(text: '🌙 $restDays rest days'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final (year, month) in _months())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: MonthGrid(
                      year: year,
                      month: month,
                      workoutLabels: _labelsFor(year, month),
                      today: widget.now,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
