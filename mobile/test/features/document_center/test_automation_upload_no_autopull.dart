import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/storage/local_db.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/document_center/models/ocr_upload_response.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';

/// Fake OCR endpoints returning a `queued` acknowledgement without any
/// extracted-fields payload.
class _FakeOcrEndpoints extends OcrEndpoints {
  _FakeOcrEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  /// The response body served by [processImage].
  Map<String, dynamic>? responseJson;

  /// Keys observed in the served response that look like extracted fields.
  final List<String> extractedFieldKeys = [];

  @override
  Future<Response> processImage({
    required String imagePath,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final body = responseJson ??
        {
          'document_id': 'doc-ocr-1',
          'status': 'queued',
          'idempotency_key': idempotencyKey,
        };
    // Track any field that resembles a synchronous OCR extraction result.
    for (final key in body.keys) {
      final lower = key.toLowerCase();
      if (lower.contains('result') ||
          lower.contains('extracted') ||
          lower.contains('fields') ||
          lower.contains('text') ||
          lower.contains('confidence')) {
        extractedFieldKeys.add(key);
      }
    }
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/ocr/process'),
      data: body,
      statusCode: 200,
    );
  }
}

/// In-memory [LocalDatabase] that records every write so the test can prove
/// that zero OCR data was persisted.
class _TrackingLocalDatabase implements LocalDatabase {
  final Map<String, Map<String, dynamic>> _data = {};
  final List<String> writeKeys = [];
  final List<String> writeNamespaces = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<dynamic> read(String key, {String namespace = 'default'}) async {
    return _data[namespace]?[key];
  }

  @override
  Future<void> write(String key, dynamic value, {String namespace = 'default'}) async {
    writeKeys.add(key);
    writeNamespaces.add(namespace);
    _data.putIfAbsent(namespace, () => <String, dynamic>{})[key] = value;
  }

  @override
  Future<void> delete(String key, {String namespace = 'default'}) async {
    _data[namespace]?.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix, {String namespace = 'default'}) async {
    return _data[namespace]?.keys.where((k) => k.startsWith(prefix)).toList() ?? [];
  }

  @override
  Future<void> deleteAllWithPrefix(String prefix, {String namespace = 'default'}) async {
    _data[namespace]?.removeWhere((k, _) => k.startsWith(prefix));
  }

  @override
  Future<void> cacheData(String collection, String key, Map<String, dynamic> data) async {
    writeKeys.add(key);
    _data.putIfAbsent(collection, () => <String, dynamic>{})[key] = data;
  }

  @override
  Future<Map<String, dynamic>?> getCachedData(String collection, String key) async {
    final raw = _data[collection]?[key];
    return raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Future<void> cacheTransports(List<Map<String, dynamic>> transports) async {
    await clearCollection('transports');
    for (final t in transports) {
      await cacheData('transports', t['id']?.toString() ?? '', t);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedTransports() async {
    return (_data['transports']?.values.whereType<Map<String, dynamic>>().toList() ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  @override
  Future<void> cacheFleet(List<Map<String, dynamic>> trucks) async {
    await clearCollection('fleet');
    for (final t in trucks) {
      await cacheData('fleet', t['id']?.toString() ?? '', t);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedFleet() async {
    return (_data['fleet']?.values.whereType<Map<String, dynamic>>().toList() ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  @override
  Future<void> cacheDrivers(List<Map<String, dynamic>> drivers) async {
    await clearCollection('drivers');
    for (final d in drivers) {
      await cacheData('drivers', d['id']?.toString() ?? '', d);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedDrivers() async {
    return (_data['drivers']?.values.whereType<Map<String, dynamic>>().toList() ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  @override
  Future<void> cacheClients(List<Map<String, dynamic>> clients) async {
    await clearCollection('clients');
    for (final c in clients) {
      await cacheData('clients', c['id']?.toString() ?? '', c);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedClients() async {
    return (_data['clients']?.values.whereType<Map<String, dynamic>>().toList() ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  @override
  Future<void> cacheInvoices(List<Map<String, dynamic>> invoices) async {
    await clearCollection('invoices');
    for (final i in invoices) {
      await cacheData('invoices', i['id']?.toString() ?? '', i);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedInvoices() async {
    return (_data['invoices']?.values.whereType<Map<String, dynamic>>().toList() ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  @override
  Future<void> cacheTeamMembers(List<Map<String, dynamic>> members) async {
    await clearCollection('team');
    for (final m in members) {
      await cacheData('team', m['id']?.toString() ?? '', m);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedTeamMembers() async {
    return (_data['team']?.values.whereType<Map<String, dynamic>>().toList() ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  @override
  Future<void> clearCollection(String collection) async {
    _data.remove(collection);
  }

  @override
  Future<void> close() async {
    _data.clear();
  }
}

ProviderContainer _containerWith(
  _FakeOcrEndpoints endpoints,
  _TrackingLocalDatabase db,
) {
  return ProviderContainer(
    overrides: [
      ocrEndpointsProvider.overrideWithValue(endpoints),
      localDatabaseProvider.overrideWithValue(db),
    ],
  );
}

void main() {
  group('Document Center — no OCR auto-pull', () {
    test(
        'after a successful upload, an app kill/relaunch leaves ZERO OCR data '
        'in any local cache or DB (positive absence assertion)', () async {
      final endpoints = _FakeOcrEndpoints();
      final db = _TrackingLocalDatabase();

      // ── 1. Upload flow (mocked endpoint returns "queued"). ──
      final container = _containerWith(endpoints, db);
      addTearDown(container.dispose);

      final notifier = container.read(ocrUploadProvider.notifier);
      await notifier.upload(imagePath: '/fake/capture.jpg');

      expect(notifier.state.phase, OcrUploadPhase.confirmed);
      expect(notifier.state.response?.status, OcrUploadStatus.queued);

      // ── 2. Simulate app kill/relaunch: reset the whole container. ──
      container.dispose();
      final freshContainer = _containerWith(endpoints, db);
      addTearDown(freshContainer.dispose);

      // ── 3. Assert ZERO OCR result data survives the relaunch. ──
      // 3a. No in-memory upload state persisted.
      expect(freshContainer.read(ocrUploadProvider).phase, OcrUploadPhase.idle);
      expect(freshContainer.read(ocrUploadProvider).response, isNull);
      expect(freshContainer.read(ocrUploadProvider).documentId, isNull);

      // 3b. The local DB received zero writes of any kind during the flow.
      expect(db.writeKeys, isEmpty,
          reason: 'the upload flow must never persist anything locally');

      // 3c. No OCR-shaped key exists anywhere in the local DB.
      final ocrKeys = db.writeKeys
          .where((k) => k.toLowerCase().contains('ocr'))
          .toList();
      expect(ocrKeys, isEmpty,
          reason: 'no OCR result may be cached locally');

      // 3d. The served response carried no extracted-fields payload.
      expect(endpoints.extractedFieldKeys, isEmpty,
          reason: 'POST /api/v1/ocr/process must never return extracted fields');
    });

    test('OcrUploadResponse only exposes document id, status, idempotency key',
        () {
      const json = {
        'document_id': 'doc-1',
        'status': 'queued',
        'idempotency_key': 'uuid-1',
      };
      final result = OcrUploadResponse.fromJson(json);
      expect(result.documentId, 'doc-1');
      expect(result.status, OcrUploadStatus.queued);
      expect(result.idempotencyKey, 'uuid-1');
      // The enum only has queued/processing — there is no completed status
      // that could carry a synchronous result.
      expect(OcrUploadStatus.values, [OcrUploadStatus.queued, OcrUploadStatus.processing]);
    });

    test('fromJson parses processing status', () {
      final json = {
        'document_id': 'doc-2',
        'status': 'processing',
        'idempotency_key': 'uuid-2',
      };
      final result = OcrUploadResponse.fromJson(json);
      expect(result.status, OcrUploadStatus.processing);
    });
  });
}
