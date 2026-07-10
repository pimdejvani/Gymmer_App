import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/domain/rest_timer.dart';

import 'support/test_app.dart';

void main() {
  group('RestTimerController', () {
    test('counts down one second per tick', () {
      fakeAsync((async) {
        final controller = RestTimerController();
        controller.start(60);
        expect(controller.running, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(controller.remaining.inSeconds, 57);

        controller.dispose();
      });
    });

    test('skip stops the timer without finishing', () {
      fakeAsync((async) {
        var finished = false;
        final controller = RestTimerController()
          ..onFinished = () => finished = true;
        controller.start(30);
        async.elapse(const Duration(seconds: 5));
        controller.skip();

        expect(controller.running, isFalse);
        expect(controller.remaining, Duration.zero);
        async.elapse(const Duration(seconds: 5));
        expect(finished, isFalse);

        controller.dispose();
      });
    });

    test('addSeconds floors at zero', () {
      fakeAsync((async) {
        final controller = RestTimerController();
        controller.start(30);
        controller.addSeconds(-100);
        expect(controller.remaining, Duration.zero);
        expect(controller.running, isFalse);
        controller.dispose();
      });
    });

    test('onFinished fires exactly once at zero', () {
      fakeAsync((async) {
        var count = 0;
        final controller = RestTimerController()..onFinished = () => count += 1;
        controller.start(3);
        async.elapse(const Duration(seconds: 10));
        expect(count, 1);
        expect(controller.running, isFalse);
        controller.dispose();
      });
    });
  });

  testWidgets('completing a set shows a counting rest pill; tap skips', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpGymmer(tester);

    // Start a routine that carries rest seconds on its exercises.
    await tester.tap(find.widgetWithText(FilledButton, 'Start Routine').first);
    await tester.pumpAndSettle();

    // Complete the first set (the checkbox on the set row).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    // Pill shows a mm:ss countdown.
    expect(find.text('Rest · tap to skip'), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:29'), findsOneWidget);

    // Tapping the time skips the rest → pill gone.
    await tester.tap(find.text('01:29'));
    await tester.pump();
    expect(find.text('Rest · tap to skip'), findsNothing);
  });
}
