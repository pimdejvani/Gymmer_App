/// Self-contained live elapsed-time label (h:mm:ss) for the Active Workout
/// app bar. Owns its own 1-second [Timer] so the surrounding page does not
/// rebuild every second. Cancels the timer in [dispose].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ElapsedTimeLabel extends StatefulWidget {
  const ElapsedTimeLabel({super.key, required this.startedAt});

  final DateTime startedAt;

  @override
  State<ElapsedTimeLabel> createState() => _ElapsedTimeLabelState();
}

class _ElapsedTimeLabelState extends State<ElapsedTimeLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    return Text(
      _format(elapsed),
      style: kNumericStyle.copyWith(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
    );
  }
}
