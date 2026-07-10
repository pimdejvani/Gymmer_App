/// Anatomy panel on the Create/Edit Exercise page. Shows front/back anatomy
/// stills from the 3D model, with per-muscle diff overlays.
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'body_muscle_painter.dart';

const _layersDir = 'assets/muscle_layers';

String _u(String muscle) => muscle.trim().replaceAll(' ', '_');

class ExerciseAnatomyPanel extends StatelessWidget {
  const ExerciseAnatomyPanel({
    super.key,
    required this.exercise,
    this.height = 240,
  });

  final Exercise exercise;
  final double height;

  @override
  Widget build(BuildContext context) {
    final primary = _canonicalMuscles({exercise.muscle});
    final secondary = _canonicalMuscles(exercise.secondaryMuscles.toSet())
      ..removeAll(primary);
    return Container(
      padding: const EdgeInsets.all(16),
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
                  'Anatomy',
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
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: Row(
              children: [
                Expanded(
                  child: _LayeredView(
                    view: 'front',
                    primary: primary,
                    secondary: secondary,
                    label: 'Front',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LayeredView(
                    view: 'back',
                    primary: primary,
                    secondary: secondary,
                    label: 'Back',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Primary target: ${exercise.muscle}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayeredView extends StatelessWidget {
  const _LayeredView({
    required this.view,
    required this.primary,
    required this.secondary,
    required this.label,
  });

  final String view;
  final Set<String> primary;
  final Set<String> secondary;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: AppColors.bg,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    '$_layersDir/base_$view.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _AnatomyPlaceholder(),
                  ),
                  for (final muscle in secondary)
                    _SecondaryImage(muscle: muscle, view: view),
                  for (final muscle in primary)
                    _PrimaryImage(muscle: muscle, view: view),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryImage extends StatelessWidget {
  const _PrimaryImage({required this.muscle, required this.view});

  final String muscle;
  final String view;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '$_layersDir/${_u(muscle)}_$view.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

class _SecondaryImage extends StatelessWidget {
  const _SecondaryImage({required this.muscle, required this.view});

  final String muscle;
  final String view;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '$_layersDir/${_u(muscle)}_${view}_secondary.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
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

class _AnatomyPlaceholder extends StatelessWidget {
  const _AnatomyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.accessibility_new, color: AppColors.textSecondary),
    );
  }
}

Set<String> _canonicalMuscles(Set<String> names) {
  final normalized = names.map(normalizeMuscle).toSet();
  return {
    for (final muscle in muscleMapNames)
      if (normalized.contains(normalizeMuscle(muscle))) muscle,
  };
}
