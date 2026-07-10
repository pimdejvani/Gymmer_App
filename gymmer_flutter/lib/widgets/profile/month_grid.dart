/// One calendar month (Sunday-first) for the Profile calendar page. Pure
/// display: takes a precomputed day-number → short workout label map. Workout
/// days render a filled circle (white bg, black numeral) with a tiny truncated
/// label; today renders an outlined circle.
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.workoutLabels,
    this.today,
  });

  final int year;
  final int month;

  /// Day-of-month (1-based) → short workout label.
  final Map<int, String> workoutLabels;
  final DateTime? today;

  static const _weekdayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: Mon=1..Sun=7 → Sunday-first leading blanks.
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // Sun=0..Sat=6
    final cells = <Widget>[
      for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          day: day,
          label: workoutLabels[day],
          isToday:
              today != null &&
              today!.year == year &&
              today!.month == month &&
              today!.day == day,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_months[month - 1]} $year',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final header in _weekdayHeaders)
              Expanded(
                child: Center(
                  child: Text(
                    header,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.72,
          children: cells,
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, this.label, this.isToday = false});

  final int day;
  final String? label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final hasWorkout = label != null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasWorkout ? AppColors.textPrimary : Colors.transparent,
            border: isToday && !hasWorkout
                ? Border.all(color: AppColors.textPrimary)
                : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              color: hasWorkout ? AppColors.bg : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (hasWorkout)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 8,
              ),
            ),
          ),
      ],
    );
  }
}
