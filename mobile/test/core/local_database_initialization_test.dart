import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:operion_mobile/core/storage/local_db.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// PathProvider fake that points at a temp directory so the real
/// [LocalDatabase] can be exercised without a platform channel.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  group('LocalDatabase (real implementation)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_db_test');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialize is idempotent (safe to call twice)', () async {
      final db = LocalDatabase();
      await db.initialize();
      await db.initialize(); // must not throw
      await db.write('k', 'v');
      expect(await db.read('k'), 'v');
      await db.close();
    });

    test('methods lazily initialize when initialize() was never called',
        () async {
      final db = LocalDatabase();
      // No explicit initialize() — the defensive guard must bootstrap the
      // database so reads/writes never throw StateError.
      await db.write('greeting', 'hello');
      expect(await db.read('greeting'), 'hello');
      await db.close();
    });

    test('does not reload a stale collection file after first load', () async {
      final db = LocalDatabase();
      await db.initialize();
      await db.write('key', 'in-memory', namespace: 'ns');

      // Simulate a stale on-disk file (e.g. written by an interleaved async
      // operation). The load-once semantics must keep serving the in-memory
      // value instead of clobbering it with the stale file.
      final file = File('${tempDir.path}/operion_cache/ns.json');
      await file.writeAsString('{"key":"stale"}');

      expect(await db.read('key', namespace: 'ns'), 'in-memory');
      await db.close();
    });

    test('persists writes across close/reopen', () async {
      final db = LocalDatabase();
      await db.initialize();
      await db.write('persisted', 'value-1', namespace: 'ns');
      await db.close();

      final reopened = LocalDatabase();
      await reopened.initialize();
      expect(await reopened.read('persisted', namespace: 'ns'), 'value-1');
      await reopened.close();
    });
  });
}