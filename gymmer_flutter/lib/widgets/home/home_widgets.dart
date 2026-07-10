/// Small stateless pieces of the home (Workout) tab: large title header,
/// quick-action buttons, empty state, and the pulsing "workout in progress"
/// resume bar shown above the bottom navigation.
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Pinned bar above the NavigationBar while a workout draft exists.
/// Tapping anywhere resumes the active workout.
class ResumeBar extends StatefulWidget {
  const ResumeBar({super.key, required this.label, required this.onResume});

  final String label;
  final VoidCallback onResume;

  @override
  State<ResumeBar> createState() => _ResumeBarState();
}

class _ResumeBarState extends State<ResumeBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: widget.onResume,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulse,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workout in progress',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Resume',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkoutHeader extends StatelessWidget {
  const WorkoutHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GYMMER', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 2),
        Text(
          _friendlyDate(DateTime.now()),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onStartEmpty,
    required this.onNewRoutine,
  });

  final VoidCallback onStartEmpty;
  final VoidCallback onNewRoutine;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onStartEmpty,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Empty'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            onPressed: onNewRoutine,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.input),
              ),
            ),
            child: Tooltip(
              message: 'New Routine',
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyHome extends StatelessWidget {
  const EmptyHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 32),
      child: Column(
        children: [
          const Icon(
            Icons.folder_open,
            size: 40,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No routines yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first routine to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _friendlyDate(DateTime value) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} ${value.day}';
}
