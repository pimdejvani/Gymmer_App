import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// proxyDecorator for SliverReorderableList: lifts the dragged card with a
/// slight scale + shadow. Shared by Routine Builder and Active Workout.
Widget reorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return Material(
    color: Colors.transparent,
    child: Transform.scale(
      scale: 1.03,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }
}

class RestTimerButton extends StatelessWidget {
  const RestTimerButton({
    super.key,
    required this.seconds,
    required this.onChanged,
  });

  final int? seconds;
  final ValueChanged<int?> onChanged;

  String get label {
    final value = seconds;
    if (value == null) return 'Rest Off';
    if (value < 60) return '${value}s';
    final minutes = value ~/ 60;
    final remaining = value % 60;
    return remaining == 0 ? '${minutes}m' : '${minutes}m ${remaining}s';
  }

  Future<void> openEditor(BuildContext context) async {
    final result = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RestTimerDialog(initialSeconds: seconds),
    );
    if (result != seconds) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => openEditor(context),
      icon: const Icon(Icons.timer_outlined, size: 18),
      label: Text(label),
    );
  }
}

class RestTimerDialog extends StatefulWidget {
  const RestTimerDialog({super.key, required this.initialSeconds});

  final int? initialSeconds;

  @override
  State<RestTimerDialog> createState() => _RestTimerDialogState();
}

class _RestTimerDialogState extends State<RestTimerDialog> {
  late int? seconds = widget.initialSeconds;

  void changeBy(int delta) {
    setState(() {
      seconds = ((seconds ?? 0) + delta).clamp(15, 600);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = seconds == null
        ? 'Off'
        : seconds! < 60
        ? '${seconds}s'
        : '${seconds! ~/ 60}m ${seconds! % 60 == 0 ? '' : '${seconds! % 60}s'}'
              .trim();
    return AlertDialog(
      title: const Text('Rest Timer'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            tooltip: 'Decrease 15 seconds',
            onPressed: seconds == null ? null : () => changeBy(-15),
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton.outlined(
            tooltip: 'Increase 15 seconds',
            onPressed: () => changeBy(15),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => seconds = null),
          child: const Text('Off'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.initialSeconds),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(seconds),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class StepperButton extends StatelessWidget {
  const StepperButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }
}
