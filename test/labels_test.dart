import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/labels.dart';

void main() {
  test('TxPower round-trips every known code and never shows a number', () {
    for (final p in [TxPower.automatic, TxPower.throughWall, TxPower.balanced, TxPower.eco]) {
      expect(TxPower.fromCode(p.code), p);
      expect(p.label, isNot(contains('(0)')));
      expect(p.label, isNot(contains('(1)')));
      expect(p.label, isNot(contains('(2)')));
    }
    expect(TxPower.fromCode('0'), TxPower.throughWall);
    expect(TxPower.fromCode('1'), TxPower.balanced);
    expect(TxPower.fromCode('2'), TxPower.eco);
    expect(TxPower.fromCode('auto'), TxPower.automatic);
    expect(TxPower.fromCode('zzz').label, 'Custom setting');
  });

  test('WanType round-trips dhcp, pppoe and static', () {
    expect(WanType.fromCode('dhcp'), WanType.dhcp);
    expect(WanType.fromCode('pppoe'), WanType.pppoe);
    expect(WanType.fromCode('static'), WanType.static);
    expect(WanType.fromCode('dhcp').label, 'Automatic (DHCP)');
    expect(WanType.fromCode('zzz'), WanType.custom);
    expect(WanType.fromCode('zzz').label, 'Custom setting');
  });

  test('Ipv6Mode round-trips 0, 1 and 2', () {
    expect(Ipv6Mode.fromCode('0'), Ipv6Mode.v4Only);
    expect(Ipv6Mode.fromCode('1'), Ipv6Mode.v6Only);
    expect(Ipv6Mode.fromCode('2'), Ipv6Mode.dual);
    expect(Ipv6Mode.fromCode('9').label, 'Custom setting');
    expect(Ipv6Mode.fromCode('').label, 'Custom setting');
  });

  test('MeshMode round-trips controller, agent and unknown', () {
    expect(MeshMode.fromCode('controller'), MeshMode.controller);
    expect(MeshMode.fromCode('agent'), MeshMode.agent);
    expect(MeshMode.fromCode('unknown'), MeshMode.unknown);
    expect(MeshMode.fromCode('zzz').label, 'Custom setting');
  });

  test('LedMode round-trips restore, close and sched', () {
    expect(LedMode.fromCode('restore'), LedMode.normal);
    expect(LedMode.fromCode('close'), LedMode.off);
    expect(LedMode.fromCode('sched'), LedMode.schedule);
    expect(LedMode.fromCode('zzz').label, 'Custom setting');
  });

  test('Encryption round-trips every stock code', () {
    expect(Encryption.fromCode('open').label, 'Open');
    expect(Encryption.fromCode('wpa2-psk').label, 'WPA2');
    expect(Encryption.fromCode('wpa3_wpa2-sae').label, 'WPA2/WPA3');
    expect(Encryption.fromCode('wpa3-sae').label, 'WPA3');
    expect(Encryption.fromCode('wpa-psk').label, 'WPA');
    expect(Encryption.fromCode('wpa_wpa2-psk').label, 'WPA/WPA2');
    expect(Encryption.fromCode('zzz').label, 'Custom setting');
  });

  test('BehaviorTarget round-trips REJECT and ACCEPT', () {
    expect(BehaviorTarget.fromCode('REJECT').label, 'Blocked');
    expect(BehaviorTarget.fromCode('ACCEPT').label, 'Allowed');
    expect(BehaviorTarget.fromCode('zzz').label, 'Not set');
  });

  test('Weekday summary covers every day, weekdays and weekends', () {
    expect(Weekday.summary(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']), 'Every day');
    expect(Weekday.summary(['mon', 'tue', 'wed', 'thu', 'fri']), 'Weekdays only');
    expect(Weekday.summary(['sat', 'sun']), 'Weekends only');
    expect(Weekday.summary(['mon', 'wed']), 'Mon, Wed');
    expect(Weekday.fromCode('fri')?.short, 'Fri');
    expect(Weekday.fromCode('zzz'), isNull);
  });

  test('Bandwidth labels never show raw codes', () {
    expect(bandwidthLabel('auto', is5g: false), 'Automatic');
    expect(bandwidthLabel('auto_160', is5g: true), contains('MHz'));
    expect(bandwidthLabel('20_40', is5g: false), contains('MHz'));
    expect(bandwidthLabel('80', is5g: true), contains('MHz'));
    expect(bandwidthLabel('zzz', is5g: true), 'Custom setting');
  });

  test('Channel labels carry frequency where known', () {
    expect(channelLabel('auto', is5g: true), 'Automatic');
    expect(channelLabel('149', is5g: true), contains('5.745'));
    expect(channelLabel('1', is5g: false), contains('2.412'));
    expect(channelLabel('52', is5g: true), contains('DFS'));
  });

  test('Date formatting never returns a Dart timestamp', () {
    final d = DateTime(2026, 10, 29, 11, 2);
    expect(formatDisplayDateTime(d), '29 Oct 2026, 11:02');
    expect(formatDisplayDateTime(d), isNot(contains('.000')));
    expect(formatDisplayTime(const TimeOfDay(hour: 3, minute: 5)), '03:05');
  });

  test('Firmware size formats in MB', () {
    expect(formatFirmwareSize('12.5'), contains('MB'));
    expect(formatFirmwareSize(''), 'Free space: unknown');
  });
}
