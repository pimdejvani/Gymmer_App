// Captures one PNG per muscle in `_capturedMuscles`, saved to
// `flutter_only/test_muscle/` (a folder next to `gymmer_flutter/`). Each PNG
// shows the front + back muscle map with just that muscle set as primary
// (dark red 0xFFD82020) — everything else stays the gray-shaded base body.
//
// Skipped by default: this is an image generator, not a regression test, and
// `boundary.toImage` can hang for minutes on this machine. Run only when
// regenerating the images:
//   flutter test --run-skipped test/muscle_map_capture_test.dart
//
// Each muscle is its own `testWidgets` so any hang isolates to a single row
// and cannot stall the whole batch.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/widgets/muscle_map.dart';

Directory _outputDir() => Directory('../test_muscle');

// Only these four are captured: back (Lats), chest, abs, and quads.
const _capturedMuscles = ['Lats', 'Chest', 'Abs', 'Quads'];

Widget _panel(String muscle) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 14),
        child: ColoredBox(
          color: const Color(0xFF0A0D0A),
          child: SizedBox(
            width: 420,
            height: 280,
            child: MuscleMapContent(
              title: muscle,
              primary: {normalizeMuscle(muscle)},
              secondary: const <String>{},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String muscle) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(key: key, child: _panel(muscle)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));

  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final bytes = byteData!.buffer.asUint8List();

  final dir = _outputDir();
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final safeName = muscle.replaceAll(' ', '_').toLowerCase();
  await File('${dir.path}/$safeName.png').writeAsBytes(bytes);
}

void main() {
  // PNG generator, not a regression test — skipped by default so routine
  // `flutter test` runs stay fast. Regenerate with:
  //   flutter test --run-skipped test/muscle_map_capture_test.dart
  group('muscle map capture', () {
    setUpAll(() {
      final dir = _outputDir();
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          if (entity is File && entity.path.endsWith('.png')) {
            entity.deleteSync();
          }
        }
      } else {
        dir.createSync(recursive: true);
      }
    });

    for (final muscle in _capturedMuscles) {
      testWidgets('captures $muscle', (tester) async {
        await _capture(tester, muscle);
        final safeName = muscle.replaceAll(' ', '_').toLowerCase();
        expect(File('${_outputDir().path}/$safeName.png').existsSync(), isTrue);
      });
    }
  }, skip: true);
}
