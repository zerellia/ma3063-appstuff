import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Errors from the router. The UI shows [message] only, never a stack trace.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException()
      : super('Session ended. Please log in again.');
}

class AuthException extends ApiException {
  const AuthException(String message) : super(message);
}

/// Normalise a raw stock JSON value into something the UI can use.
/// Stock is inconsistent on purpose in places the eweb already documented:
/// a list can arrive as a list, a map, or an empty object {} instead of [].
dynamic dataOf(dynamic json) {
  if (json is Map && json.containsKey('data')) return json['data'];
  return json;
}

String str(dynamic v, [String fallback = '-']) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

double? numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

List<dynamic> listOf(dynamic v) {
  if (v is List) return v;
  if (v is Map) {
    if (v.isEmpty) return const [];
    return v.values.toList();
  }
  return const [];
}

String formatDuration(dynamic secondsRaw) {
  final s = numOrNull(secondsRaw);
  if (s == null || s < 0) return '-';
  final total = s.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  if (h > 0) return '$h h $m m';
  if (m > 0) return '$m m';
  return '$sec s';
}

String formatTemp(dynamic v) {
  final n = numOrNull(v);
  if (n == null) return '-';
  final deg = n > 1000 ? n / 1000 : n;
  return '${deg.toStringAsFixed(1)} °C';
}

String signalLabel(dynamic rssiRaw) {
  final n = numOrNull(rssiRaw);
  if (n == null) return '-';
  final v = n.round();
  if (v >= -50) return '$v dBm · Strong';
  if (v >= -70) return '$v dBm · Medium';
  return '$v dBm · Weak';
}

/// Count mesh nodes from MeshGetTopo childList.
/// Stock returns {} when there are no children, not []. That empty object
/// means 1 node total (this router), never 0 and never an error.
int meshNodeCount(dynamic childList) {
  if (childList is List) return 1 + childList.length;
  if (childList is Map) return 1 + childList.length;
  return 1;
}

String authToEncryption(dynamic auth) {
  final a = str(auth, '');
  switch (a) {
    case 'open':
      return 'open';
    case 'wpapsk':
      return 'wpa-psk';
    case 'wpa2psk':
      return 'wpa2-psk';
    case 'wpapskwpa2psk':
      return 'wpa_wpa2-psk';
    case 'wpa3sae':
      return 'wpa3-sae';
    case 'wpa2pskwpa3sae':
      return 'wpa3_wpa2-sae';
    default:
      return a.isEmpty ? 'wpa_wpa2-psk' : a;
  }
}

/// A parsed v161 pairing QR payload. Home LAN only.
/// The QR carries a one use pairing code, never a password and never
/// a session token. The pairing code is exchanged for a fresh session
/// token by claimPair, exactly like a normal login token after that.
class QrPair {
  const QrPair({
    required this.ip,
    required this.code,
    required this.expiresAt,
    this.hostname,
    this.model,
  });
  final String ip;
  final String code;
  final int expiresAt;
  final String? hostname;
  final String? model;
}

/// Parse and validate a v161 QR payload. Throws ApiException with a
/// clear message for every invalid case, never a silent fallback to
/// a wrong IP. A 60 second clock skew is allowed for expiry.
QrPair parseQrPayload(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    throw const ApiException('This QR code is empty.');
  }
  dynamic json;
  try {
    json = jsonDecode(text);
  } catch (_) {
    throw const ApiException('This QR code is not a MA3063 pairing code.');
  }
  if (json is! Map) {
    throw const ApiException('This QR code is not a MA3063 pairing code.');
  }
  final version = json['v'];
  if (version != 1 && version != '1') {
    throw const ApiException('This QR code is not a MA3063 pairing code (unsupported version).');
  }
  final model = json['model'];
  if (model != null && model.toString().isNotEmpty && model.toString() != 'RG-MA3063') {
    throw const ApiException('This QR code is for a different router model.');
  }
  final code = json['code'];
  if (code == null || code.toString().isEmpty) {
    throw const ApiException('This QR code has no pairing code.');
  }
  final exp = numOrNull(json['exp']);
  if (exp == null) {
    throw const ApiException('This QR code has no expiry time.');
  }
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (exp.round() <= now - 60) {
    throw const ApiException('This pairing code has expired. Generate a fresh QR in the web panel.');
  }
  final lanIp = json['lan_ip'];
  final host = json['host'];
  final ip = (lanIp != null && lanIp.toString().isNotEmpty) ? lanIp.toString() : (host?.toString() ?? '');
  if (ip.isEmpty) {
    throw const ApiException('This QR code has no router address.');
  }
  final hostname = json['hostname'];
  return QrPair(
    ip: ip,
    code: code.toString(),
    expiresAt: exp.round(),
    hostname: hostname != null && hostname.toString().isNotEmpty ? hostname.toString() : null,
    model: model?.toString(),
  );
}

/// The connector layer for the app. It talks directly to the router, no
/// cloud, no intermediate server. It mirrors the proven eweb api.js:
/// POST /login with md5(password + username + time), then SessionID cookie
/// sent manually on every call, because the stock Set-Cookie domain does
/// not work for a native app.
class RouterApi {
  RouterApi(String rawIp) : base = _normalize(rawIp);
  final String base;
  String? token;
  int sessionMaxAge = 300;

  static String _normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s';
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Accept': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      h['Cookie'] = 'SessionID=$token';
    }
    return h;
  }

  Future<dynamic> login(String username, String password) async {
    final timeSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hash = md5.convert(utf8.encode(password + username + '$timeSec')).toString();
    final uri = Uri.parse('$base/login');
    http.Response res;
    try {
      res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({
                'method': 'login',
                'params': {'un': username, 'pw': hash, 'time': timeSec}
              }))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApiException('Cannot reach the router at $base. Check the IP and that you are on the same network or VPN.');
    }
    if (res.statusCode == 401) {
      throw const AuthException('Username or password does not match.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Login failed (HTTP ${res.statusCode}).');
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const ApiException('Router returned an unexpected login response.');
    }
    if (json is Map) {
      final code = json['code'];
      final data = json['data'];
      if ((code == 0 || code == '0') && data is Map && data['token'] != null) {
        token = data['token'].toString();
        final t = numOrNull(data['sessionTimeoutMax']);
        if (t != null && t > 0) sessionMaxAge = t.round();
        return data;
      }
      final msg = json['msg'];
      if (msg != null && msg.toString().isNotEmpty && msg.toString() != 'Unauthorized') {
        throw AuthException(msg.toString());
      }
    }
    throw const AuthException('Username or password does not match.');
  }

  /// Exchange a v161 one use pairing code for a fresh session token.
  /// This call is intentionally unauthenticated: the pairing code is
  /// the proof, and v161 consumes it on first use. After success the
  /// token is used exactly like a normal login token.
  Future<dynamic> claimPair(String pairingCode) async {
    final uri = Uri.parse('$base/api/maapp.lua?action=claim&code=${Uri.encodeComponent(pairingCode)}');
    http.Response res;
    try {
      res = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApiException('Cannot reach the router at $base. Check that you are on the same home LAN.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const ApiException('Pairing code was rejected. Generate a fresh QR in the web panel, or log in manually.');
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const ApiException('Router returned an unexpected pairing response.');
    }
    if (json is Map) {
      final code = json['code'];
      final dataToken = json['token'];
      if ((code == 0 || code == '0') && dataToken != null && dataToken.toString().isNotEmpty) {
        token = dataToken.toString();
        final t = numOrNull(json['sessionTimeoutMax']);
        if (t != null && t > 0) sessionMaxAge = t.round();
        return json;
      }
    }
    throw const ApiException('Pairing code was rejected or expired. Generate a fresh QR in the web panel, or log in manually.');
  }

  Future<dynamic> get(String path) async {
    if (token == null) throw const SessionExpiredException();
    http.Response res;
    try {
      res = await http.get(Uri.parse('$base$path'), headers: _headers).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApiException('Cannot reach the router at $base.');
    }
    return _handle(res, isPost: false);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    if (token == null) throw const SessionExpiredException();
    http.Response res;
    try {
      res = await http
          .post(Uri.parse('$base$path'),
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw ApiException('Cannot reach the router at $base.');
    }
    return _handle(res, isPost: true);
  }

  dynamic _handle(http.Response res, {required bool isPost}) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      token = null;
      throw const SessionExpiredException();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Router request failed (HTTP ${res.statusCode}).');
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      return {'raw': res.body};
    }
    if (json is Map) {
      final code = json['code'];
      final msg = json['msg'];
      if (code == 401 || code == -401 || msg == 'Unauthorized' || msg == 'AuthRequired') {
        token = null;
        throw const SessionExpiredException();
      }
      // Same rule as eweb api.js: a POST that the backend rejects must
      // never be reported as success. GETs are not checked this way,
      // because many stock read endpoints return partial data without code.
      if (isPost && json.containsKey('code') && code != 0 && code != '0') {
        throw ApiException(msg != null && msg.toString().isNotEmpty ? msg.toString() : 'Router rejected this change.');
      }
    }
    return json;
  }
}
