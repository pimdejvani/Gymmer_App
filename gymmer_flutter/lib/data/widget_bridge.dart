import 'dart:convert';

import 'package:flutter/services.dart';

import '../models.dart';

/// Pushes app state into the iOS App Group shared container so the home-screen
/// widget can render it. No-op on platforms without the native handler
/// (Android, desktop, tests) — every call swallows a missing-plugin error.
class WidgetBridge {
  static const MethodChannel _channel = MethodChannel('gymmer/widget');

  /// Writes the exercise catalog the widget's picker reads (name / muscle /
  /// equipment only — the widget can't show media).
  static Future<void> writeCatalog(List<Exercise> exercises) async {
    final payload = <String, Object?>{
      'updatedAt': DateTime.now().toIso8601String(),
      'exercises': [
        for (final e in exercises)
          {'name': e.name, 'muscle': e.muscle, 'equipment': e.equipment},
      ],
    };
    await _writeFile('catalog.json', jsonEncode(payload));
  }

  static Future<void> _writeFile(String name, String contents) async {
    try {
      await _channel.invokeMethod<void>('writeFile', {
        'name': name,
        'contents': contents,
      });
    } on MissingPluginException {
      // Not iOS / no widget host — ignore.
    } on PlatformException {
      // Container unavailable — ignore; the app keeps working.
    }
  }
}
