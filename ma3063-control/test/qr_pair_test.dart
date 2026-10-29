import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/api.dart';

String payload({Map<String, dynamic> overrides = const {}}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final base = <String, dynamic>{
    'v': 1,
    'host': '192.168.10.1',
    'lan_ip': '192.168.10.1',
    'code': '0123456789abcdef0123456789abcdef',
    'exp': now + 240,
    'model': 'RG-MA3063',
    'hostname': 'MA3063',
  };
  base.addAll(overrides);
  return jsonEncode(base);
}

void main() {
  test('valid QR parses lan_ip and code', () {
    final pair = parseQrPayload(payload());
    expect(pair.ip, '192.168.10.1');
    expect(pair.code, '0123456789abcdef0123456789abcdef');
    expect(pair.hostname, 'MA3063');
  });

  test('host is used when lan_ip is empty', () {
    final pair = parseQrPayload(payload(overrides: {'lan_ip': ''}));
    expect(pair.ip, '192.168.10.1');
  });

  test('expired QR is rejected', () {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect(
      () => parseQrPayload(payload(overrides: {'exp': now - 120})),
      throwsA(isA<ApiException>()),
    );
  });

  test('wrong model is rejected', () {
    expect(
      () => parseQrPayload(payload(overrides: {'model': 'OTHER'})),
      throwsA(isA<ApiException>()),
    );
  });

  test('wrong version is rejected', () {
    expect(
      () => parseQrPayload(payload(overrides: {'v': 2})),
      throwsA(isA<ApiException>()),
    );
  });

  test('missing code is rejected', () {
    expect(
      () => parseQrPayload(payload(overrides: {'code': ''})),
      throwsA(isA<ApiException>()),
    );
  });

  test('non JSON is rejected', () {
    expect(() => parseQrPayload('not a qr'), throwsA(isA<ApiException>()));
  });
}
