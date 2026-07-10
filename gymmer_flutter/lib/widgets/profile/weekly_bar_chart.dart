/// Monochrome weekly bar chart (white bars on black, grey axis labels) for the
/// Profile progress section. No chart package — a single CustomPainter.
/// The green accent is deliberately NOT used here.
library;

import 'package:flutter/material.dart';

import '../../domain/workout_aggregates.dart';
import '../../theme/app_theme.dart';

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.weeks, this.height = 180});

  final List<WeekTotal> weeks;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _BarChartPainter(weeks)),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(this.weeks);

  final List<WeekTotal> weeks;

  static const _leftPad = 40.0;
  static const _bottomPad = 22.0;
  static const _topPad = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPad;
    final chartRight = size.width;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    if (weeks.isEmpty || chartWidth <= 0 || chartHeight <= 0) return;

    final maxValue = weeks.fold<double>(0, (m, w) => w.value > m ? w.value : m);
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue;

    final axisPaint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    // Baseline (0) and top (max) gridlines.
    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartLeft, chartTop),
      Offset(chartRight, chartTop),
      axisPaint,
    );

    _drawText(
      canvas,
      '0',
      Offset(chartLeft - 6, chartBottom),
      alignRight: true,
    );
    _drawText(
      canvas,
      _formatMax(maxValue),
      Offset(chartLeft - 6, chartTop),
      alignRight: true,
      alignTop: true,
    );

    // Bars.
    final slot = chartWidth / weeks.length;
    final barWidth = slot * 0.6;
    final barPaint = Paint()..color = AppColors.textPrimary;
    for (var i = 0; i < weeks.length; i++) {
      final value = weeks[i].value;
      final barHeight = value <= 0 ? 0.0 : (value / scaleMax) * chartHeight;
      final left = chartLeft + slot * i + (slot - barWidth) / 2;
      final rect = Rect.fromLTWH(
        left,
        chartBottom - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        barPaint,
      );
    }

    // Sparse x-axis labels (~4).
    final labelStep = (weeks.length / 4).ceil().clamp(1, weeks.length);
    for (var i = 0; i < weeks.length; i += labelStep) {
      final centerX = chartLeft + slot * i + slot / 2;
      _drawText(
        canvas,
        _formatWeek(weeks[i].weekStart),
        Offset(centerX, chartBottom + 4),
        center: true,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
    bool center = false,
    bool alignTop = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = offset.dx;
    var dy = offset.dy;
    if (alignRight) dx -= tp.width;
    if (center) dx -= tp.width / 2;
    if (!alignTop && (alignRight)) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  String _formatMax(double v) {
    if (v <= 0) return '0';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.round().toString();
  }

  static const _months = [
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

  String _formatWeek(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) =>
      oldDelegate.weeks != weeks;
}
