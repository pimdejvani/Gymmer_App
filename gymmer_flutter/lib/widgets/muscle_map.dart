/// Muscle-map panels for whole-session cards that render the schematic body
/// painter with primary/secondary highlights.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'body_muscle_painter.dart';

export 'body_muscle_painter.dart';

class WorkoutMuscleMapPanel extends StatelessWidget {
  const WorkoutMuscleMapPanel({
    super.key,
    required this.exercises,
    this.compact = false,
  });

  final List<WorkoutExercise> exercises;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = <String>{};
    final secondary = <String>{};
    for (final item in exercises) {
      primary.add(normalizeMuscle(item.exercise.muscle));
      secondary.addAll(item.exercise.secondaryMuscles.map(normalizeMuscle));
    }
    secondary.removeAll(primary);

    return MuscleMapContent(
      title: 'Workout Muscle Map',
      primary: primary,
      secondary: secondary,
      compact: compact,
      footer: _WorkoutMuscleSummary(primary: primary, secondary: secondary),
    );
  }
}

class MuscleMapContent extends StatelessWidget {
  const MuscleMapContent({
    super.key,
    required this.title,
    required this.primary,
    required this.secondary,
    this.compact = false,
    this.footer,
  });

  final String title;
  final Set<String> primary;
  final Set<String> secondary;
  final bool compact;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.accessibility_new, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const _LegendDot(
                color: AppColors.musclePrimary,
                label: 'Primary',
              ),
              const SizedBox(width: 10),
              const _LegendDot(
                color: AppColors.muscleSecondary,
                label: 'Second',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: compact ? 150 : 180,
            child: Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: BodyMusclePainter(
                        side: BodySide.front,
                        primary: primary,
                        secondary: secondary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: BodyMusclePainter(
                        side: BodySide.back,
                        primary: primary,
                        secondary: secondary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

class _WorkoutMuscleSummary extends StatelessWidget {
  const _WorkoutMuscleSummary({required this.primary, required this.secondary});

  final Set<String> primary;
  final Set<String> secondary;

  @override
  Widget build(BuildContext context) {
    final labels = [..._displayMuscles(primary), ..._displayMuscles(secondary)];
    if (labels.isEmpty) {
      return const Text(
        'Add exercises to see workout muscle coverage.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Chip(visualDensity: VisualDensity.compact, label: Text(label)),
      ],
    );
  }
}

List<String> _displayMuscles(Set<String> normalizedMuscles) {
  return [
    for (final muscle in muscleMapNames)
      if (normalizedMuscles.contains(normalizeMuscle(muscle))) muscle,
  ];
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
