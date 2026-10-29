import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/labels.dart';

void main() {
  test('Router date: milliseconds input gives 2026, never 58796', () {
    final dt = DateTime(2026, 10, 29, 17, 6);
    final ms = dt.millisecondsSinceEpoch;
    final out = routerTimestamp(ms);
    expect(out.year, 2026);
    expect(out.month, 10);
    expect(out.day, 29);
    expect(formatDisplayDateTime(out), contains('2026'));
  });

  test('Router date: seconds input also gives 2026, never 58796', () {
    final dt = DateTime(2026, 10, 29, 17, 6);
    final seconds = dt.millisecondsSinceEpoch ~/ 1000;
    final out = routerTimestamp(seconds);
    expect(out.year, 2026);
    expect(out.month, 10);
    expect(out.day, 29);
  });

  test('Firmware size has no duplicate words', () {
    expect(formatFirmwareSize(null), 'unknown');
    expect(formatFirmwareSize('bad'), 'unknown');
    expect(formatFirmwareSize(2097152), '2.0 MB');
    expect(formatFirmwareSize(2097152), isNot(contains('Free space')));
    expect(formatFirmwareSize(2097152), isNot(contains('Free size')));
  });

  test('WAN fallback uses wanget IP when network/info IP is missing', () {
    expect(
      resolveWanInfo('PPPoE · -', 'PPPoE', '172.16.100.119'),
      'PPPoE · 172.16.100.119',
    );
    expect(
      resolveWanInfo('-', 'PPPoE', '172.16.100.119'),
      'PPPoE · 172.16.100.119',
    );
  });

  test('WAN keeps the primary value and shows Not connected when both are empty', () {
    expect(
      resolveWanInfo('PPPoE · 172.16.100.119', 'PPPoE', '10.0.0.1'),
      'PPPoE · 172.16.100.119',
    );
    expect(resolveWanInfo('PPPoE · -', 'PPPoE', ''), 'Not connected');
    expect(resolveWanInfo('-', '', ''), 'Not connected');
  });

  test('DNS shows Not set when both values are missing', () {
    expect(normalizeDnsDisplay('- · -'), 'Not set');
    expect(normalizeDnsDisplay('-'), 'Not set');
    expect(normalizeDnsDisplay('1.1.1.1 · 1.0.0.1'), '1.1.1.1 · 1.0.0.1');
  });
}
