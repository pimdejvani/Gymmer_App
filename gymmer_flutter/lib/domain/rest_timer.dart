/// Live rest-timer state for the Active Workout page. One [Timer.periodic]
/// drives a 1-second countdown; the controller is a [ChangeNotifier] so the
/// rest pill can rebuild without rebuilding the whole page.
///
/// The timer MUST be cancelled in [dispose] and whenever it stops (skip /
/// natural finish) — a leaked periodic timer fails widget tests with
/// "A Timer is still pending".
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class RestTimerController extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _running = false;

  /// Fired exactly once when the countdown reaches zero on its own (or is
  /// driven to zero via [addSeconds]). Not fired on [skip].
  VoidCallback? onFinished;

  Duration get remaining => Duration(seconds: _remainingSeconds);
  bool get running => _running;

  /// Starts (or restarts) the countdown for [seconds]. Non-positive values
  /// leave the timer stopped.
  void start(int seconds) {
    _timer?.cancel();
    _remainingSeconds = seconds < 0 ? 0 : seconds;
    if (_remainingSeconds == 0) {
      _running = false;
      notifyListeners();
      return;
    }
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  /// Adds [delta] seconds (may be negative); floors at 0. Reaching 0 finishes.
  void addSeconds(int delta) {
    if (!_running) return;
    _remainingSeconds += delta;
    if (_remainingSeconds <= 0) {
      _finish();
      return;
    }
    notifyListeners();
  }

  /// Stops the countdown without firing [onFinished] (user dismissed it).
  void skip() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 0;
    _running = false;
    notifyListeners();
  }

  void _tick() {
    _remainingSeconds -= 1;
    if (_remainingSeconds <= 0) {
      _finish();
      return;
    }
    notifyListeners();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    final wasRunning = _running;
    _running = false;
    _remainingSeconds = 0;
    notifyListeners();
    if (wasRunning) onFinished?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
