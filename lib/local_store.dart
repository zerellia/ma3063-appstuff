import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local only data. Nothing here is sent to the router, and nothing
/// here pretends to change a router setting. A device nickname or room
/// is labelled local only in the UI because the stock API does not
/// save a device rename on the router.
class LocalStore {
  static const _nickKey = 'local_nicknames';
  static const _histKey = 'local_device_history';
  static const _samplesKey = 'local_samples';
  static const _alertsKey = 'local_alerts';
  static const _cacheKey = 'local_home_cache';
  static const _cacheTimeKey = 'local_home_cache_time';

  static Future<Map<String, dynamic>> _readMap(String key) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final d = jsonDecode(raw);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }

  static Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(value));
  }

  static Future<Map<String, dynamic>> nicknames() => _readMap(_nickKey);

  static Future<void> setNickname(String mac, {String? name, String? room, String? group, bool? favourite}) async {
    final all = await nicknames();
    final key = mac.toUpperCase();
    final cur = all[key] is Map ? Map<String, dynamic>.from(all[key] as Map) : <String, dynamic>{};
    if (name != null) cur['name'] = name;
    if (room != null) cur['room'] = room;
    if (group != null) cur['group'] = group;
    if (favourite != null) cur['favourite'] = favourite;
    all[key] = cur;
    await _writeMap(_nickKey, all);
  }

  /// Record that a device was seen online now. First seen is kept,
  /// last seen and session count are updated.
  static Future<void> recordSeen(String mac, String displayName) async {
    final all = await _readMap(_histKey);
    final key = mac.toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cur = all[key] is Map ? Map<String, dynamic>.from(all[key] as Map) : <String, dynamic>{};
    cur['firstSeen'] ??= now;
    final prevLast = cur['lastSeen'];
    if (prevLast == null || now - (prevLast as num).toInt() > 10 * 60 * 1000) {
      cur['sessions'] = ((cur['sessions'] ?? 0) as num).toInt() + 1;
    }
    cur['lastSeen'] = now;
    cur['name'] = displayName;
    all[key] = cur;
    await _writeMap(_histKey, all);
  }

  static Future<Map<String, dynamic>> history() => _readMap(_histKey);

  static Future<void> addSample({double? cpu, double? mem, double? temp}) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_samplesKey);
    var list = <dynamic>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) list = d;
      } catch (_) {}
    }
    list.add({
      't': DateTime.now().millisecondsSinceEpoch,
      if (cpu != null) 'cpu': cpu,
      if (mem != null) 'mem': mem,
      if (temp != null) 'temp': temp,
    });
    if (list.length > 288) list = list.sublist(list.length - 288);
    await p.setString(_samplesKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> samples() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_samplesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final d = jsonDecode(raw);
      if (d is List) return d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {}
    return [];
  }

  static Future<void> addAlert(String text) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_alertsKey);
    var list = <dynamic>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) list = d;
      } catch (_) {}
    }
    list.insert(0, {'t': DateTime.now().millisecondsSinceEpoch, 'text': text});
    if (list.length > 50) list = list.sublist(0, 50);
    await p.setString(_alertsKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> alerts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_alertsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final d = jsonDecode(raw);
      if (d is List) return d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {}
    return [];
  }

  static Future<void> saveHomeCache(Map<String, dynamic> snapshot) async {
    final p = await SharedPreferences.getInstance();
    // Batched: both writes are issued together in one await.
    await Future.wait([
      p.setString(_cacheKey, jsonEncode(snapshot)),
      p.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  static Future<(Map<String, dynamic>?, int?)> homeCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    final t = p.getInt(_cacheTimeKey);
    if (raw == null || raw.isEmpty) return (null, null);
    try {
      final d = jsonDecode(raw);
      if (d is Map) return (Map<String, dynamic>.from(d), t);
    } catch (_) {}
    return (null, null);
  }

  static String weeklyReport(Map<String, dynamic> hist, List<Map<String, dynamic>> samples) {
    final total = hist.length;
    var newest = '';
    var newestTime = 0;
    for (final e in hist.entries) {
      final m = e.value is Map ? e.value as Map : {};
      final first = m['firstSeen'];
      if (first is num && first.toInt() > newestTime) {
        newestTime = first.toInt();
        newest = '${m['name'] ?? e.key} (${e.key})';
      }
    }
    var cpuAvg = 'no samples yet';
    if (samples.isNotEmpty) {
      final cpus = samples.map((s) => s['cpu']).whereType<num>().toList();
      if (cpus.isNotEmpty) {
        final avg = cpus.reduce((a, b) => a + b) / cpus.length;
        cpuAvg = '${avg.toStringAsFixed(1)}% average CPU';
      }
    }
    final lines = <String>[
      'Local weekly report, generated on this phone only.',
      'Devices ever seen: $total.',
      if (newest.isNotEmpty) 'Newest device: $newest.',
      'Health samples: ${samples.length} recorded while the app was open.',
      'CPU: $cpuAvg.',
      'This report is local only. It is not a router report.',
    ];
    return lines.join('\n');
  }
}
