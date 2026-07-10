import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/domain/streaks.dart';

void main() {
  // Week of 2026-07-08 (Wednesday) starts Monday 2026-07-06.
  final now = DateTime(2026, 7, 8);

  test('four consecutive weeks → 4', () {
    final days = [
      DateTime(2026, 7, 6),
      DateTime(2026, 6, 29),
      DateTime(2026, 6, 22),
      DateTime(2026, 6, 15),
    ];
    expect(weekStreak(days, now: now), 4);
  });

  test('a gap week resets the streak', () {
    final days = [
      DateTime(2026, 7, 6),
      DateTime(2026, 6, 29),
      // gap: no workout in the week of 2026-06-22
      DateTime(2026, 6, 15),
    ];
    expect(weekStreak(days, now: now), 2);
  });

  test('empty history → 0', () {
    expect(weekStreak([], now: now), 0);
  });

  test('workout today only → 1', () {
    expect(weekStreak([now], now: now), 1);
  });

  test('current week empty but last 3 weeks filled → 3', () {
    final days = [
      DateTime(2026, 6, 29),
      DateTime(2026, 6, 22),
      DateTime(2026, 6, 15),
    ];
    expect(weekStreak(days, now: now), 3);
  });

  test('restDaysThisWeek: Thursday with workouts Mon+Wed → 1', () {
    final thursday = DateTime(2026, 7, 9);
    final days = [DateTime(2026, 7, 6), DateTime(2026, 7, 8)];
    expect(restDaysThisWeek(days, now: thursday), 1);
  });
}
