import 'package:flutter_test/flutter_test.dart';
import 'package:gymmer_flutter/data/workout_store_sqlite.dart';
import 'package:gymmer_flutter/main.dart';

/// Opens a file-backed SQLite store in a fresh temp directory and registers
/// close + directory cleanup on test tear-down. Prefer this over
/// [GymmerSqliteStore.memory] so tests exercise real filesystem I/O.
///
/// Seeds the demo catalog so tests have data to act on; the shipping app opens
/// blank (see `openAppDatabase`, which never seeds).
Future<GymmerSqliteStore> openTestStore() async {
  final opened = await GymmerSqliteStore.openTempFile();
  opened.store.seedPrototypeData();
  addTearDown(() async {
    await opened.store.close();
    if (opened.tempDir.existsSync()) {
      await opened.tempDir.delete(recursive: true);
    }
  });
  return opened.store;
}

/// Pumps the full app on the in-memory SQLite store and settles.
///
/// Widget tests use the in-memory store on purpose: file-based
/// `openTempFile` performs real `Directory.systemTemp.createTemp` I/O,
/// which interacts badly with `pumpAndSettle`'s fake-async zone and hangs
/// the test until timeout. File-backed persistence is covered by the
/// dedicated SQLite-only tests (they don't pump widgets).
Future<GymmerSqliteStore> pumpGymmer(WidgetTester tester) async {
  final store = GymmerSqliteStore.memory();
  store.seedPrototypeData();
  addTearDown(store.close);
  await tester.pumpWidget(GymmerApp(store: store));
  await tester.pumpAndSettle();
  return store;
}
