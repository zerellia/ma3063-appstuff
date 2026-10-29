/// Pure helpers for the Topology screen. No widgets, no router calls,
/// so they are unit testable. Nothing here guesses: a WiFi standard is
/// only reported when the router actually returned a standard field.

const List<String> _standardFields = ['mode', 'wifiMode', 'standard', 'phyMode', 'protocol'];

String? _standardFieldValue(Map client) {
  for (final f in _standardFields) {
    final v = client[f];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString().toLowerCase();
  }
  return null;
}

/// Maps a real router standard value to a WiFi generation label.
/// 11ax -> WiFi 6, 11ac -> WiFi 5, 11n -> WiFi 4. Anything else, including
/// a missing field, is Unknown, never a guessed generation.
String wifiStandardOf(Map client) {
  final v = _standardFieldValue(client);
  if (v == null) return 'Unknown';
  if (v.contains('11ax') || v == 'ax' || v.endsWith('-ax') || v.contains('wifi6') || v == 'wifi 6') return 'WiFi 6';
  if (v.contains('11ac') || v == 'ac' || v.endsWith('-ac') || v.contains('wifi5') || v == 'wifi 5') return 'WiFi 5';
  if (v.contains('11n') || v == 'n' || v.endsWith('-n') || v.contains('wifi4') || v == 'wifi 4') return 'WiFi 4';
  return 'Unknown';
}

/// True when at least one client actually carried a standard field.
/// When false, the screen shows Unknown plus a per-band breakdown.
bool hasStandardField(List<Map<String, dynamic>> clients) {
  return clients.any((c) => _standardFieldValue(c) != null);
}

Map<String, int> countByStandard(List<Map<String, dynamic>> clients) {
  final out = <String, int>{};
  for (final c in clients) {
    final label = wifiStandardOf(c);
    out[label] = (out[label] ?? 0) + 1;
  }
  return out;
}

/// Band from text the router actually returned: an SSID or radio name
/// containing 5G/5 GHz, or 2.4G/2.4 GHz. Numeric radio indexes are not
/// mapped, because their band meaning is not verified for this router.
String bandOf(Map client) {
  final parts = <String>[];
  for (final f in ['band', 'radio', 'relatedRadio', 'ssid', 'ssidName', 'wifiName']) {
    final v = client[f];
    if (v != null) parts.add(v.toString().toLowerCase());
  }
  final joined = parts.join(' ');
  if (joined.contains('5ghz') || joined.contains('5g') || joined.contains('5 ghz')) return '5 GHz';
  if (joined.contains('2.4ghz') || joined.contains('2.4g') || joined.contains('2.4 ghz')) return '2.4 GHz';
  return 'Unknown band';
}

Map<String, int> countByBand(List<Map<String, dynamic>> clients) {
  final out = <String, int>{};
  for (final c in clients) {
    final label = bandOf(c);
    out[label] = (out[label] ?? 0) + 1;
  }
  return out;
}

/// Port display from Portinfo/list, mirroring the Home parsing exactly:
/// portId, isWan (or name WAN, or port 1), link from status on or link
/// 1, speed from the speed field with a 1000 fallback when up.
Map<String, dynamic> portDisplay(Map m) {
  final pid = (m['portId'] is num)
      ? (m['portId'] as num).round()
      : int.tryParse(m['portId'].toString()) ?? 0;
  final isWan = m['isWan'] == true || m['name'] == 'WAN' || pid == 1;
  final up = m['status'] == 'on' || m['link'] == 1 || m['link'] == '1';
  final speed = m['speed']?.toString();
  return {
    'portId': pid,
    'isWan': isWan,
    'up': up,
    'label': isWan ? 'WAN' : 'LAN $pid',
    'portLabel': isWan ? 'WAN Port 1' : 'LAN Port $pid',
    'speedLabel': up ? '${(speed == null || speed.isEmpty) ? '1000' : speed} Mbps' : 'Disconnected',
  };
}
