import 'package:flutter/material.dart';

/// One label layer for every closed stock setting.
///
/// The UI only reads label and description. The API only reads code.
/// An unknown code never appears on screen as a number: it becomes
/// Custom setting or Not set, and picking a known option overwrites it.

enum TxPower {
  automatic('auto', 'Automatic', 'Let the router choose the strongest safe level.'),
  throughWall('0', 'Through-wall', 'Strongest signal and widest coverage.'),
  balanced('1', 'Balanced', 'A balance of coverage and power use.'),
  eco('2', 'Eco', 'Lowest power use and shortest range.'),
  custom('', 'Custom setting', 'Tap to choose a standard option.');

  const TxPower(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
  static TxPower fromCode(dynamic v) {
    final s = v?.toString() ?? '';
    for (final e in TxPower.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

enum WanType {
  dhcp('dhcp', 'Automatic (DHCP)', 'Address is assigned automatically.'),
  pppoe('pppoe', 'PPPoE', 'ISP username and password.'),
  static('static', 'Static IP', 'Address is set manually.'),
  custom('', 'Custom setting', 'Tap to choose a standard option.');

  const WanType(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
  static WanType fromCode(dynamic v) {
    final s = (v?.toString() ?? '').toLowerCase();
    for (final e in WanType.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

String wanProtoLabel(dynamic proto) {
  final t = WanType.fromCode(proto);
  return t == WanType.custom ? 'Not set' : t.label;
}

enum Ipv6Mode {
  v4Only('0', 'IPv4 only', 'IPv6 is off.'),
  v6Only('1', 'IPv6 only', 'Single stack IPv6.'),
  dual('2', 'IPv4 and IPv6', 'Dual stack, both families.'),
  custom('', 'Custom setting', 'Tap to choose a standard option.');

  const Ipv6Mode(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
  static Ipv6Mode fromCode(dynamic v) {
    final s = v?.toString() ?? '';
    for (final e in Ipv6Mode.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

enum MeshMode {
  controller('controller', 'Main router', 'This router controls the mesh.'),
  agent('agent', 'Mesh child', 'This node follows another router.'),
  unknown('unknown', 'Not in mesh', 'This router is not in a mesh.'),
  custom('', 'Custom setting', 'Tap to choose a standard option.');

  const MeshMode(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
  static MeshMode fromCode(dynamic v) {
    final s = v?.toString() ?? '';
    for (final e in MeshMode.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

enum LedMode {
  normal('restore', 'Normal', 'LEDs follow the normal behaviour.'),
  off('close', 'LED off', 'LEDs stay off.'),
  schedule('sched', 'Schedule', 'LEDs follow the schedules below.'),
  custom('', 'Custom setting', 'Tap to choose a standard option.');

  const LedMode(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
  static LedMode fromCode(dynamic v) {
    final s = v?.toString() ?? '';
    for (final e in LedMode.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

enum Encryption {
  open('open', 'Open', false),
  wpa2('wpa2-psk', 'WPA2', false),
  wpa2Wpa3('wpa3_wpa2-sae', 'WPA2/WPA3', false),
  wpa3('wpa3-sae', 'WPA3', false),
  wpa('wpa-psk', 'WPA', true),
  wpaWpa2('wpa_wpa2-psk', 'WPA/WPA2', true),
  custom('', 'Custom setting', false);

  const Encryption(this.code, this.label, this.legacy);
  final String code;
  final String label;
  final bool legacy;
  static Encryption fromCode(dynamic v) {
    final s = (v?.toString() ?? '').toLowerCase();
    for (final e in Encryption.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

enum BehaviorTarget {
  block('REJECT', 'Blocked'),
  allow('ACCEPT', 'Allowed'),
  custom('', 'Not set');

  const BehaviorTarget(this.code, this.label);
  final String code;
  final String label;
  static BehaviorTarget fromCode(dynamic v) {
    final s = v?.toString() ?? '';
    for (final e in BehaviorTarget.values) {
      if (e != custom && e.code == s) return e;
    }
    return custom;
  }
}

enum Weekday {
  mon('mon', 'Mon', 'Monday'),
  tue('tue', 'Tue', 'Tuesday'),
  wed('wed', 'Wed', 'Wednesday'),
  thu('thu', 'Thu', 'Thursday'),
  fri('fri', 'Fri', 'Friday'),
  sat('sat', 'Sat', 'Saturday'),
  sun('sun', 'Sun', 'Sunday');

  const Weekday(this.code, this.short, this.full);
  final String code;
  final String short;
  final String full;
  static Weekday? fromCode(String code) {
    for (final e in Weekday.values) {
      if (e.code == code) return e;
    }
    return null;
  }

  static String summary(List<String> codes) {
    if (codes.isEmpty) return 'No days';
    final days = codes.map(fromCode).whereType<Weekday>().toList();
    if (days.length == 7) return 'Every day';
    final weekdayOnly = days.length == 5 && days.every((d) => d.index < 5);
    if (weekdayOnly) return 'Weekdays only';
    final weekendOnly = days.length == 2 && days.every((d) => d.index >= 5);
    if (weekendOnly) return 'Weekends only';
    return days.map((d) => d.short).join(', ');
  }
}

const List<(String, String)> timezoneOptions = [
  ('GMT+7:00', 'Western Indonesia Time (WIB)'),
  ('GMT+8:00', 'Central Indonesia Time (WITA)'),
  ('GMT+9:00', 'Eastern Indonesia Time (WIT)'),
  ('GMT+0:00', 'UTC'),
];

String timezoneLabel(String code) {
  for (final t in timezoneOptions) {
    if (t.$1 == code) return t.$2;
  }
  return code.isEmpty ? 'Not set' : 'Custom setting';
}

const List<(String, String)> ipv6PrefixOptions = [
  ('', 'Keep current'),
  ('48', '/48'),
  ('56', '/56'),
  ('60', '/60'),
  ('64', '/64'),
  ('128', '/128'),
];

const List<(String, String)> ipv6DnsOptions = [
  ('', 'Keep current'),
  ('2606:4700:4700::1111', 'Cloudflare 2606:4700:4700::1111'),
  ('2606:4700:4700::1001', 'Cloudflare 2606:4700:4700::1001'),
  ('2001:4860:4860::8888', 'Google 2001:4860:4860::8888'),
  ('2001:4860:4860::8844', 'Google 2001:4860:4860::8844'),
  ('2620:fe::fe', 'Quad9 2620:fe::fe'),
  ('2620:fe::9', 'Quad9 2620:fe::9'),
];

const List<(String, String)> ipv6LeaseOptions = [
  ('', 'Keep current'),
  ('3600', '1 hour'),
  ('43200', '12 hours'),
  ('86400', '1 day'),
  ('604800', '1 week'),
];

const List<(String, String)> ipv6DhcpOptions = [
  ('', 'Keep current'),
  ('0', 'Off'),
  ('1', 'On'),
];

String bandwidthLabel(String code, {required bool is5g}) {
  switch (code) {
    case 'auto':
      return is5g ? 'Automatic up to 80 MHz' : 'Automatic';
    case 'auto_160':
      return 'Automatic up to 160 MHz';
    case '20_40':
      return '20 / 40 MHz automatic';
    case '20':
      return '20 MHz';
    case '40':
      return '40 MHz';
    case '80':
      return '80 MHz';
    case '160':
      return '160 MHz';
    default:
      return 'Custom setting';
  }
}

const Map<String, String> _freq24 = {
  '1': '2.412 GHz',
  '2': '2.417 GHz',
  '3': '2.422 GHz',
  '4': '2.427 GHz',
  '5': '2.432 GHz',
  '6': '2.437 GHz',
  '7': '2.442 GHz',
  '8': '2.447 GHz',
  '9': '2.452 GHz',
  '10': '2.457 GHz',
  '11': '2.462 GHz',
  '12': '2.467 GHz',
  '13': '2.472 GHz',
};

const Map<String, String> _freq5 = {
  '36': '5.180 GHz',
  '40': '5.200 GHz',
  '44': '5.220 GHz',
  '48': '5.240 GHz',
  '52': '5.260 GHz',
  '56': '5.280 GHz',
  '60': '5.300 GHz',
  '64': '5.320 GHz',
  '149': '5.745 GHz',
  '153': '5.765 GHz',
  '157': '5.785 GHz',
  '161': '5.805 GHz',
  '165': '5.825 GHz',
};

bool _isDfs(String channel) => const {'52', '56', '60', '64'}.contains(channel);

String channelLabel(String channel, {required bool is5g, String? freq}) {
  if (channel == 'auto' || channel == '0') return 'Automatic';
  final f = freq ?? (is5g ? _freq5[channel] : _freq24[channel]);
  final dfs = _isDfs(channel) ? ', DFS' : '';
  if (f != null) return 'Channel $channel ($f$dfs)';
  return 'Channel $channel';
}

List<String> channelOptions({required bool is5g}) {
  if (is5g) return ['auto', '36', '40', '44', '48', '52', '56', '60', '64', '149', '153', '157', '161', '165'];
  return ['auto', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13'];
}

String radioBandLabel(dynamic relatedRadio) {
  final r = relatedRadio?.toString() ?? '';
  final has1 = r.contains('1');
  final has2 = r.contains('2');
  if (has1 && has2) return '2.4 GHz and 5 GHz';
  if (has1) return '2.4 GHz';
  if (has2) return '5 GHz';
  return 'Not set';
}

String radioTypeLabel(dynamic type, dynamic radioIndex) {
  final t = type?.toString() ?? '';
  if (t.contains('5')) return '5 GHz';
  if (t.contains('2.4') || t.contains('2')) return '2.4 GHz';
  if (radioIndex?.toString() == '2') return '5 GHz';
  if (radioIndex?.toString() == '1') return '2.4 GHz';
  return 'Radio';
}

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDisplayDateTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $hh:$mm';
}

String formatDisplayDateTimeMs(int ms) => formatDisplayDateTime(DateTime.fromMillisecondsSinceEpoch(ms));

String formatDisplayTime(TimeOfDay t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

TimeOfDay? parseDisplayTime(String s) {
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

String formatFirmwareSize(dynamic v) {
  if (v == null) return 'unknown';
  final n = double.tryParse(v.toString());
  if (n == null) return 'unknown';
  double mb;
  if (n >= 1000000) {
    mb = n / 1048576;
  } else if (n >= 1000) {
    mb = n / 1024;
  } else {
    mb = n;
  }
  return '${mb.toStringAsFixed(1)} MB';
}

/// Connector v162 /tmp free space. The connector ping returns tmp_free_kb
/// with the unit in the field name (kilobytes from df -k /tmp), so this
/// divides by 1024 exactly once, with one decimal. When the connector is
/// absent or the field is missing, keep the existing unknown behaviour;
/// this never claims the stock Upgrade endpoint returns a size, because
/// stock returns a boolean flag, not a size.
String formatTmpFreeSpace(dynamic kb) {
  if (kb == null) return 'Free size: unknown';
  final n = double.tryParse(kb.toString());
  if (n == null || n < 0) return 'Free size: unknown';
  return 'Free /tmp space (connector): ${(n / 1024).toStringAsFixed(1)} MB';
}

/// Router time: the stock Time/asyncTime value is milliseconds, but older
/// code treated it as seconds and produced year 58796. Magnitude decides:
/// values above 100000000000 are already milliseconds, smaller values are
/// seconds and are multiplied by 1000. Both give 2026 for current dates.
DateTime routerTimestamp(num raw) {
  final v = raw.round();
  return DateTime.fromMillisecondsSinceEpoch(v > 100000000000 ? v : v * 1000);
}

/// Settings WAN display: use the fallback (wanget) IP only when the primary
/// network/info value is missing, otherwise keep the primary value. When
/// both are missing, show Not connected, never a bare dash or 'PPPoE -'.
String resolveWanInfo(String current, String fallbackProto, String fallbackIp) {
  final missing = current == '-' || current.endsWith('· -') || current.endsWith('· ') || current.isEmpty;
  if (!missing) return current;
  if (fallbackIp.isEmpty || fallbackIp == '-') return 'Not connected';
  if (fallbackProto.isEmpty || fallbackProto == '-' || fallbackProto == 'Not set') return fallbackIp;
  return '$fallbackProto · $fallbackIp';
}

/// Settings DNS display: two missing values read as Not set, never '- · -'.
String normalizeDnsDisplay(String joined) {
  if (joined == '- · -' || joined == '-' || joined.isEmpty) return 'Not set';
  return joined;
}

String humaniseKey(String key) {
  final cleaned = key.replaceAll(RegExp(r'^(WAN6|LAN6|wan6|lan6)[:_ ]?'), '');
  final spaced = cleaned.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}').replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String ipv6EntryLabel(String key) {
  final lower = key.toLowerCase();
  if (lower.contains('prefixlen') || lower.contains('prefix_len')) return 'Prefix length';
  if (lower.contains('prefix')) return 'Prefix';
  if (lower.contains('gateway')) return 'Gateway';
  if (lower.contains('dnsprimary') || lower.contains('dns1')) return 'Primary DNS';
  if (lower.contains('dnssecondary') || lower.contains('dns2')) return 'Secondary DNS';
  if (lower.contains('staticaddr')) return 'Static address';
  if (lower.contains('ulaprefix')) return 'Local prefix';
  if (lower.contains('addrstart')) return 'Address start';
  if (lower.contains('addend')) return 'Address end';
  if (lower.contains('leasetime')) return 'Lease time';
  if (lower.contains('dhcpv6server')) return 'DHCPv6 server';
  if (lower.contains('radvd')) return 'Router advertisement';
  if (lower == 'mode') return 'Mode';
  if (lower.contains('ipaddr') || lower == 'ip') return 'Address';
  return humaniseKey(key);
}

bool isSensitiveKey(String key) {
  final lower = key.toLowerCase();
  return lower.contains('pwd') || lower.contains('pass');
}
