/// 2D schematic body painter (front/back CustomPainter with fake-3D shading)
/// plus the canonical muscle-name list (muscleMapNames) and normalizeMuscle.
/// Geometry-only file: no app state, safe to edit shapes without touching UI.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BodySide { front, back }

class BodyMusclePainter extends CustomPainter {
  BodyMusclePainter({
    required this.side,
    required this.primary,
    required this.secondary,
  });

  final BodySide side;
  final Set<String> primary;
  final Set<String> secondary;

  static const Color primaryColor = AppColors.musclePrimary;
  static const Color secondaryColor = AppColors.muscleSecondary;
  static const Color bodyColor = Color(0xFF8D928E);
  static const Color strokeColor = Color(0xFF252927);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width < size.height / 1.55
        ? size.width
        : size.height / 1.55;
    final dx = (size.width - scale) / 2;
    final dy = (size.height - scale * 1.52) / 2;
    canvas.save();
    canvas.translate(dx, dy < 0 ? 0 : dy);
    canvas.scale(scale, scale);

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    _drawBase(canvas, stroke);
    if (side == BodySide.front) {
      _drawFrontMuscles(canvas, stroke);
      _drawFrontDetailLines(canvas);
    } else {
      _drawBackMuscles(canvas, stroke);
      _drawBackDetailLines(canvas);
    }

    canvas.restore();
  }

  void _drawBase(Canvas canvas, Paint stroke) {
    final partRects = <Rect>[
      const Rect.fromLTWH(0.41, 0.02, 0.18, 0.18),
      const Rect.fromLTWH(0.35, 0.19, 0.30, 0.42),
      const Rect.fromLTWH(0.29, 0.20, 0.12, 0.22),
      const Rect.fromLTWH(0.59, 0.20, 0.12, 0.22),
      const Rect.fromLTWH(0.23, 0.40, 0.10, 0.28),
      const Rect.fromLTWH(0.67, 0.40, 0.10, 0.28),
      const Rect.fromLTWH(0.34, 0.61, 0.13, 0.43),
      const Rect.fromLTWH(0.53, 0.61, 0.13, 0.43),
      const Rect.fromLTWH(0.34, 1.02, 0.12, 0.42),
      const Rect.fromLTWH(0.54, 1.02, 0.12, 0.42),
      const Rect.fromLTWH(0.31, 1.42, 0.16, 0.08),
      const Rect.fromLTWH(0.53, 1.42, 0.16, 0.08),
    ];
    final parts = <Path>[
      _ovalPath(partRects[0]),
      _roundedPath(partRects[1], 0.12),
      _roundedPath(partRects[2], 0.08),
      _roundedPath(partRects[3], 0.08),
      _roundedPath(partRects[4], 0.05),
      _roundedPath(partRects[5], 0.05),
      _roundedPath(partRects[6], 0.08),
      _roundedPath(partRects[7], 0.08),
      _roundedPath(partRects[8], 0.07),
      _roundedPath(partRects[9], 0.07),
      _roundedPath(partRects[10], 0.04),
      _roundedPath(partRects[11], 0.04),
    ];
    for (var i = 0; i < parts.length; i++) {
      canvas.drawPath(parts[i], _volumePaint(partRects[i], bodyColor));
      canvas.drawPath(parts[i], stroke);
    }

    canvas.drawLine(const Offset(0.50, 0.19), const Offset(0.50, 1.40), stroke);
  }

  Paint _volumePaint(Rect rect, Color base) {
    final highlight = Color.alphaBlend(const Color(0xCCFFFFFF), base);
    final mid = Color.alphaBlend(const Color(0x33FFFFFF), base);
    final shadow = Color.alphaBlend(const Color(0xBB000000), base);
    final deepShadow = Color.alphaBlend(const Color(0xDD000000), base);
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [deepShadow, shadow, mid, highlight, mid, shadow, deepShadow],
        stops: const [0.0, 0.15, 0.32, 0.5, 0.68, 0.85, 1.0],
      ).createShader(rect);
  }

  Paint _musclePaint(Rect rect, Color base) {
    final highlight = Color.alphaBlend(const Color(0xDDFFFFFF), base);
    final mid = Color.alphaBlend(const Color(0x44FFFFFF), base);
    final shadow = Color.alphaBlend(const Color(0xAA000000), base);
    return Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.55),
        radius: 1.1,
        colors: [highlight, mid, base, shadow],
        stops: const [0.0, 0.25, 0.6, 1.0],
      ).createShader(rect);
  }

  void _drawFrontMuscles(Canvas canvas, Paint stroke) {
    _muscle(canvas, stroke, 'chest', [
      _roundedPath(const Rect.fromLTWH(0.35, 0.22, 0.15, 0.16), 0.04),
      _roundedPath(const Rect.fromLTWH(0.50, 0.22, 0.15, 0.16), 0.04),
    ]);
    _muscle(canvas, stroke, 'front delt', [
      _ovalPath(const Rect.fromLTWH(0.28, 0.22, 0.11, 0.12)),
      _ovalPath(const Rect.fromLTWH(0.61, 0.22, 0.11, 0.12)),
    ]);
    _muscle(canvas, stroke, 'side delt', [
      _ovalPath(const Rect.fromLTWH(0.27, 0.24, 0.10, 0.13)),
      _ovalPath(const Rect.fromLTWH(0.63, 0.24, 0.10, 0.13)),
    ]);
    _muscle(canvas, stroke, 'biceps', [
      _roundedPath(const Rect.fromLTWH(0.25, 0.38, 0.08, 0.20), 0.04),
      _roundedPath(const Rect.fromLTWH(0.67, 0.38, 0.08, 0.20), 0.04),
    ]);
    _muscle(canvas, stroke, 'forearms', [
      _roundedPath(const Rect.fromLTWH(0.22, 0.56, 0.08, 0.20), 0.04),
      _roundedPath(const Rect.fromLTWH(0.70, 0.56, 0.08, 0.20), 0.04),
    ]);
    _muscle(canvas, stroke, 'abs', [
      _roundedPath(const Rect.fromLTWH(0.41, 0.39, 0.18, 0.22), 0.04),
    ]);
    _muscle(canvas, stroke, 'quads', [
      _roundedPath(const Rect.fromLTWH(0.35, 0.70, 0.10, 0.32), 0.05),
      _roundedPath(const Rect.fromLTWH(0.55, 0.70, 0.10, 0.32), 0.05),
    ]);
  }

  void _drawBackMuscles(Canvas canvas, Paint stroke) {
    _muscle(canvas, stroke, 'traps', [
      _polygonPath([
        const Offset(0.43, 0.18),
        const Offset(0.57, 0.18),
        const Offset(0.62, 0.34),
        const Offset(0.50, 0.30),
        const Offset(0.38, 0.34),
      ]),
    ]);
    _muscle(canvas, stroke, 'rear delt', [
      _ovalPath(const Rect.fromLTWH(0.28, 0.24, 0.11, 0.13)),
      _ovalPath(const Rect.fromLTWH(0.61, 0.24, 0.11, 0.13)),
    ]);
    _muscle(canvas, stroke, 'rhomboids', [
      _polygonPath([
        const Offset(0.42, 0.30),
        const Offset(0.58, 0.30),
        const Offset(0.55, 0.43),
        const Offset(0.45, 0.43),
      ]),
    ]);
    _muscle(canvas, stroke, 'lats', [
      _polygonPath([
        const Offset(0.35, 0.34),
        const Offset(0.47, 0.42),
        const Offset(0.43, 0.62),
        const Offset(0.33, 0.52),
      ]),
      _polygonPath([
        const Offset(0.65, 0.34),
        const Offset(0.53, 0.42),
        const Offset(0.57, 0.62),
        const Offset(0.67, 0.52),
      ]),
    ]);
    _muscle(canvas, stroke, 'triceps', [
      _roundedPath(const Rect.fromLTWH(0.25, 0.38, 0.08, 0.20), 0.04),
      _roundedPath(const Rect.fromLTWH(0.67, 0.38, 0.08, 0.20), 0.04),
    ]);
    _muscle(canvas, stroke, 'forearms', [
      _roundedPath(const Rect.fromLTWH(0.22, 0.56, 0.08, 0.20), 0.04),
      _roundedPath(const Rect.fromLTWH(0.70, 0.56, 0.08, 0.20), 0.04),
    ]);
    _muscle(canvas, stroke, 'glutes', [
      _roundedPath(const Rect.fromLTWH(0.36, 0.62, 0.13, 0.16), 0.06),
      _roundedPath(const Rect.fromLTWH(0.51, 0.62, 0.13, 0.16), 0.06),
    ]);
    _muscle(canvas, stroke, 'hamstrings', [
      _roundedPath(const Rect.fromLTWH(0.35, 0.80, 0.10, 0.25), 0.05),
      _roundedPath(const Rect.fromLTWH(0.55, 0.80, 0.10, 0.25), 0.05),
    ]);
    _muscle(canvas, stroke, 'calves', [
      _roundedPath(const Rect.fromLTWH(0.35, 1.10, 0.09, 0.22), 0.05),
      _roundedPath(const Rect.fromLTWH(0.56, 1.10, 0.09, 0.22), 0.05),
    ]);
  }

  void _drawFrontDetailLines(Canvas canvas) {
    final detail = _detailPaint();
    final paths = [
      _linePath([
        const Offset(0.36, 0.30),
        const Offset(0.50, 0.34),
        const Offset(0.64, 0.30),
      ]),
      _linePath([const Offset(0.41, 0.40), const Offset(0.59, 0.40)]),
      _linePath([const Offset(0.42, 0.46), const Offset(0.58, 0.46)]),
      _linePath([const Offset(0.42, 0.52), const Offset(0.58, 0.52)]),
      _linePath([const Offset(0.31, 0.27), const Offset(0.38, 0.34)]),
      _linePath([const Offset(0.69, 0.27), const Offset(0.62, 0.34)]),
      _linePath([const Offset(0.28, 0.40), const Offset(0.31, 0.56)]),
      _linePath([const Offset(0.72, 0.40), const Offset(0.69, 0.56)]),
      _linePath([const Offset(0.39, 0.72), const Offset(0.39, 0.98)]),
      _linePath([const Offset(0.61, 0.72), const Offset(0.61, 0.98)]),
      _linePath([const Offset(0.36, 0.88), const Offset(0.46, 0.84)]),
      _linePath([const Offset(0.64, 0.88), const Offset(0.54, 0.84)]),
      _linePath([const Offset(0.39, 1.12), const Offset(0.38, 1.30)]),
      _linePath([const Offset(0.61, 1.12), const Offset(0.62, 1.30)]),
    ];
    for (final path in paths) {
      canvas.drawPath(path, detail);
    }
  }

  void _drawBackDetailLines(Canvas canvas) {
    final detail = _detailPaint();
    final paths = [
      _linePath([
        const Offset(0.40, 0.22),
        const Offset(0.50, 0.31),
        const Offset(0.60, 0.22),
      ]),
      _linePath([
        const Offset(0.39, 0.34),
        const Offset(0.50, 0.40),
        const Offset(0.61, 0.34),
      ]),
      _linePath([const Offset(0.35, 0.43), const Offset(0.45, 0.57)]),
      _linePath([const Offset(0.65, 0.43), const Offset(0.55, 0.57)]),
      _linePath([const Offset(0.29, 0.39), const Offset(0.29, 0.57)]),
      _linePath([const Offset(0.71, 0.39), const Offset(0.71, 0.57)]),
      _linePath([const Offset(0.39, 0.69), const Offset(0.47, 0.76)]),
      _linePath([const Offset(0.61, 0.69), const Offset(0.53, 0.76)]),
      _linePath([const Offset(0.39, 0.84), const Offset(0.41, 1.02)]),
      _linePath([const Offset(0.61, 0.84), const Offset(0.59, 1.02)]),
      _linePath([const Offset(0.39, 1.12), const Offset(0.37, 1.30)]),
      _linePath([const Offset(0.61, 1.12), const Offset(0.63, 1.30)]),
    ];
    for (final path in paths) {
      canvas.drawPath(path, detail);
    }
  }

  void _muscle(Canvas canvas, Paint stroke, String name, List<Path> paths) {
    final normalized = normalizeMuscle(name);
    final color = primary.contains(normalized)
        ? primaryColor
        : secondary.contains(normalized)
        ? secondaryColor
        : null;
    if (color == null) return;
    for (final path in paths) {
      canvas.drawPath(path, _musclePaint(path.getBounds(), color));
      canvas.drawPath(path, stroke);
    }
  }

  Path _roundedPath(Rect rect, double radius) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  Path _ovalPath(Rect rect) => Path()..addOval(rect);

  Path _polygonPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _linePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  Paint _detailPaint() {
    return Paint()
      ..color = const Color(0xFF3A403C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.01
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
  }

  @override
  bool shouldRepaint(covariant BodyMusclePainter oldDelegate) {
    return oldDelegate.side != side ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

String normalizeMuscle(String muscle) {
  return muscle.trim().toLowerCase();
}

const muscleMapNames = [
  'Chest',
  'Front Delt',
  'Side Delt',
  'Rear Delt',
  'Biceps',
  'Triceps',
  'Forearms',
  'Traps',
  'Rhomboids',
  'Lats',
  'Abs',
  'Quads',
  'Glutes',
  'Hamstrings',
  'Calves',
];
