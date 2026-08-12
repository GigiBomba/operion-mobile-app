import 'package:operion_mobile/core/storage/local_db.dart';

/// In-memory [LocalDatabase] fake for dual-mode / offline tests.
///
/// Mirrors the in-memory collection semantics of the real implementation
/// (collections of JSON-encoded maps) without touching `path_provider`.
class FakeLocalDatabase implements LocalDatabase {
  final _data = <String, Map<String, String>>{};

  void seedCollection(String collection, List<Map<String, dynamic>> items) {
    _data.putIfAbsent(collection, () => <String, String>{});
    for (final item in items) {
      _data[collection]![item['id'].toString()] = _encode(item);
    }
  }

  List<Map<String, dynamic>> storedCollection(String collection) {
    final entries = _data[collection];
    if (entries == null) return [];
    return entries.values.map(_decode).toList();
  }

  static String _encode(Map<String, dynamic> map) => _jsonEncode(map);

  static Map<String, dynamic> _decode(String raw) =>
      _jsonDecode(raw) as Map<String, dynamic>;

  // Kept minimal to avoid dart:convert imports in every test file.
  static String _jsonEncode(Map<String, dynamic> map) {
    final parts = <String>[];
    map.forEach((k, v) {
      final value = switch (v) {
        null => 'null',
        String s => '"${s.replaceAll('"', '\\"')}"',
        bool b => b.toString(),
        int i => i.toString(),
        double d => d.toString(),
        List l => '[${l.join(',')}]',
        _ => '"$v"',
      };
      parts.add('"$k":$value');
    });
    return '{${parts.join(',')}}';
  }

  static dynamic _jsonDecode(String raw) {
    // Parses the small subset produced by _jsonEncode.
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      final map = <String, dynamic>{};
      if (inner.isNotEmpty) {
        for (final pair in inner.split(',')) {
          final idx = pair.indexOf(':');
          final key = pair.substring(1, idx - 1).replaceAll('\\"', '"');
          final rawValue = pair.substring(idx + 1);
          map[key] = _decodeScalar(rawValue);
        }
      }
      return map;
    }
    return _decodeScalar(trimmed);
  }

  static dynamic _decodeScalar(String raw) {
    if (raw == 'null') return null;
    if (raw.startsWith('"')) return raw.substring(1, raw.length - 1).replaceAll('\\"', '"');
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    final i = int.tryParse(raw);
    if (i != null) return i;
    final d = double.tryParse(raw);
    if (d != null) return d;
    return raw;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cacheData(
    String collection,
    String key,
    Map<String, dynamic> data,
  ) async {
    _data.putIfAbsent(collection, () => <String, String>{})[key] = _encode(data);
  }

  @override
  Future<void> cacheTransports(List<Map<String, dynamic>> transports) async {
    await clearCollection('transports');
    for (final t in transports) {
      await cacheData('transports', t['id'].toString(), t);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedTransports() async {
    return storedCollection('transports');
  }

  @override
  Future<void> cacheFleet(List<Map<String, dynamic>> trucks) async {
    await clearCollection('fleet');
    for (final t in trucks) {
      await cacheData('fleet', t['id'].toString(), t);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedFleet() async {
    return storedCollection('fleet');
  }

  @override
  Future<void> cacheDrivers(List<Map<String, dynamic>> drivers) async {
    await clearCollection('drivers');
    for (final d in drivers) {
      await cacheData('drivers', d['id'].toString(), d);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedDrivers() async {
    return storedCollection('drivers');
  }

  @override
  Future<void> cacheClients(List<Map<String, dynamic>> clients) async {
    await clearCollection('clients');
    for (final c in clients) {
      await cacheData('clients', c['id'].toString(), c);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedClients() async {
    return storedCollection('clients');
  }

  @override
  Future<void> cacheInvoices(List<Map<String, dynamic>> invoices) async {
    await clearCollection('invoices');
    for (final i in invoices) {
      await cacheData('invoices', i['id'].toString(), i);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedInvoices() async {
    return storedCollection('invoices');
  }

  @override
  Future<void> cacheTeamMembers(List<Map<String, dynamic>> members) async {
    await clearCollection('team');
    for (final m in members) {
      await cacheData('team', m['id'].toString(), m);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedTeamMembers() async {
    return storedCollection('team');
  }

  @override
  Future<Map<String, dynamic>?> getCachedData(
    String collection,
    String key,
  ) async {
    final raw = _data[collection]?[key];
    return raw == null ? null : _decode(raw);
  }

  @override
  Future<void> clearCollection(String collection) async {
    _data.remove(collection);
  }

  @override
  Future<void> close() async {
    _data.clear();
  }

  @override
  Future<void> delete(String key, {String namespace = 'default'}) async {
    _data[namespace]?.remove(key);
  }

  @override
  Future<void> deleteAllWithPrefix(
    String prefix, {
    String namespace = 'default',
  }) async {
    _data[namespace]?.removeWhere((k, _) => k.startsWith(prefix));
  }

  @override
  Future<List<String>> keysWithPrefix(
    String prefix, {
    String namespace = 'default',
  }) async {
    return _data[namespace]?.keys.where((k) => k.startsWith(prefix)).toList() ?? [];
  }

  @override
  Future<dynamic> read(String key, {String namespace = 'default'}) async {
    final raw = _data[namespace]?[key];
    return raw == null ? null : _decode(raw);
  }

  @override
  Future<void> write(
    String key,
    dynamic value, {
    String namespace = 'default',
  }) async {
    _data.putIfAbsent(namespace, () => <String, String>{})[key] = _encode(value as Map<String, dynamic>);
  }
}
