/// Dot/line trend chart with min/max grid labels. Used by exercise stats and
/// measurement trends. No chart package: a single CustomPainter.
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    required this.unit,
    this.height = 180,
  });

  final List<TrendPoint> points;
  final String unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = points.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    return Semantics(
      label: '$unit trend, max ${_format(max)}',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TrendLinePainter(points, unit)),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter(this.points, this.unit);

  final List<TrendPoint> points;
  final String unit;

  static const _leftPad = 58.0;
  static const _rightPad = 8.0;
  static const _bottomPad = 24.0;
  static const _topPad = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    if (points.isEmpty || chartWidth <= 0 || chartHeight <= 0) return;

    var minValue = points.first.value;
    var maxValue = points.first.value;
    for (final point in points) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
    }
    final sameValue = minValue == maxValue;

    final axisPaint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    void drawGrid(double y, String label) {
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), axisPaint);
      _drawText(canvas, label, Offset(chartLeft - 6, y), alignRight: true);
    }

    drawGrid(chartTop, '${_format(maxValue)} $unit');
    if (!sameValue) drawGrid(chartBottom, '${_format(minValue)} $unit');

    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * (i / (points.length - 1));
      final ratio = sameValue
          ? 0.5
          : (points[i].value - minValue) / (maxValue - minValue);
      final y = chartBottom - ratio * chartHeight;
      offsets.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = AppColors.accent;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, dotPaint);
    }

    _drawText(
      canvas,
      _formatDate(points.first.date),
      Offset(chartLeft, chartBottom + 6),
    );
    _drawText(
      canvas,
      _formatDate(points.last.date),
      Offset(chartRight, chartBottom + 6),
      alignRight: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? offset.dx - tp.width : offset.dx;
    tp.paint(canvas, Offset(dx, offset.dy - tp.height / 2));
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

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.unit != unit;
}

String _format(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}
