/// Accent-tinted full-width pill showing the live rest countdown after a set
/// is completed on the Active Workout page. Listens to a [RestTimerController]
/// and hides itself when the timer is not running.
///
/// Layout: `[−15]  mm:ss  [+15]`; tapping the time skips (dismisses) the rest.
/// The rest pill is one of the allowed green-accent signals.
library;

import 'package:flutter/material.dart';

import '../../domain/rest_timer.dart';
import '../../theme/app_theme.dart';

class RestTimerPill extends StatelessWidget {
  const RestTimerPill({super.key, required this.controller});

  final RestTimerController controller;

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.running) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepButton(
                  tooltip: 'Rest −15 seconds',
                  icon: Icons.remove,
                  onPressed: () => controller.addSeconds(-15),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.skip,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _format(controller.remaining),
                          textAlign: TextAlign.center,
                          style: kNumericStyle.copyWith(
                            color: AppColors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Rest · tap to skip',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _StepButton(
                  tooltip: 'Rest +15 seconds',
                  icon: Icons.add,
                  onPressed: () => controller.addSeconds(15),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: AppColors.accent),
    );
  }
}
