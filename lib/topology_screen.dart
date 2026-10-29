import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'custom_ui.dart';
import 'local_store.dart';
import 'device_icons.dart';
import 'topology_data.dart';

/// Topology, as a separate Settings menu, never on the Home dashboard.
/// Network map only: main router on top, then connected devices from
/// mainData_GetStaList plus sta_list. No mesh section in this map.
class TopologyScreen extends StatefulWidget {
  const TopologyScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<TopologyScreen> createState() => _TopologyScreenState();
}

class _TopologyScreenState extends State<TopologyScreen> {
  bool _loading = true;
  String? _error;
  String _hostname = 'Main router';
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _ports = [];
  Map<String, dynamic> _nicks = {};
  Map<String, dynamic> _icons = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _clientName(Map c) {
    final mac = (c['mac'] ?? '').toString().toUpperCase();
    final n = _nicks[mac];
    if (n is Map && n['name'] != null && n['name'].toString().isNotEmpty) return n['name'].toString();
    return str(c['hostName'] ?? c['deviceName'], 'Unknown device');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final h = await widget.api.get('/api/v1/lua/Hostname/getHostnamePlain');
      final hd = dataOf(h);
      if (hd is Map && hd['hostname'] != null) _hostname = str(hd['hostname']);
    } catch (_) {}
    try {
      final res = await widget.api.get('/api/v1/lua/OnlineUsers/mainData_GetStaList');
      var clients = listOf(dataOf(res) is Map ? (dataOf(res) as Map)['list'] : dataOf(res));
      var list = clients.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      try {
        final full = await widget.api.post('/api/v1/lua/OnlineUsers/sta_list', {'page': 1, 'size': 100});
        final fullList = listOf(dataOf(full) is Map ? (dataOf(full) as Map)['list'] : const []);
        final byMac = <String, Map<String, dynamic>>{};
        for (final item in fullList.whereType<Map>()) {
          if (item['mac'] != null) byMac[item['mac'].toString().toUpperCase()] = Map<String, dynamic>.from(item);
        }
        list = list.map((c) {
          final m = byMac[(c['mac'] ?? '').toString().toUpperCase()];
          if (m == null) return c;
          final merged = {...m, ...c};
          merged['hostName'] = c['hostName'] ?? m['hostName'];
          merged['mac'] = c['mac'];
          return merged;
        }).toList();
      } catch (_) {}
      _clients = list;
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/Portinfo/list');
      final d = dataOf(r);
      if (d is Map) {
        final list = listOf(d['List'] ?? d['list']);
        final rows = list.whereType<Map>().toList();
        rows.sort((a, b) => (numOrNull(a['portId']) ?? 0).compareTo(numOrNull(b['portId']) ?? 0));
        _ports = rows
            .map((m) => portDisplay(Map<String, dynamic>.from(m)))
            .where((p) => (p['portId'] as int) >= 1 && (p['portId'] as int) <= 4)
            .toList();
      }
    } catch (_) {}
    try {
      _nicks = await LocalStore.nicknames();
      _icons = await LocalStore.deviceIcons();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickIcon(Map c) async {
    final mac = (c['mac'] ?? '').toString().toUpperCase();
    if (mac.isEmpty) return;
    final current = _icons[mac]?.toString();
    final picked = await showDeviceIconPicker(context, current);
    if (picked == null) return;
    await LocalStore.setDeviceIcon(mac, picked);
    final icons = await LocalStore.deviceIcons();
    if (mounted) setState(() => _icons = icons);
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: appMuted)),
    );
  }

  Widget _nodeTile({required IconData icon, required String title, String? subtitle, Color? iconColor, VoidCallback? onIconTap}) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: appPrimaryContainer, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: iconColor ?? appBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: appMuted, fontSize: 12)),
              ],
            ),
          ),
          if (onIconTap != null)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onIconTap, tooltip: 'Change icon (local only)'),
        ],
      ),
    );
  }

  Widget _connector() {
    return const Padding(
      padding: EdgeInsets.only(left: 27),
      child: SizedBox(
        width: 2,
        height: 20,
        child: DecoratedBox(decoration: BoxDecoration(color: appOutlineVariant)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final standardCounts = countByStandard(_clients);
    final hasStandard = hasStandardField(_clients);
    final bandCounts = countByBand(_clients);
    final total = _clients.length;
    final standardOrder = ['WiFi 6', 'WiFi 5', 'WiFi 4', 'Unknown'];
    final standardColors = {
      'WiFi 6': appBlue,
      'WiFi 5': const Color(0xFF60A5FA),
      'WiFi 4': const Color(0xFF94A3B8),
      'Unknown': appMuted,
    };
    return Scaffold(
      body: DetailScroll(
        title: 'Topology',
        subtitle: 'Router, devices, standards, ports',
        loading: _loading,
        children: [
          if (_error != null && _error!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: appRedBg, borderRadius: BorderRadius.circular(16)),
              child: Text(_error!, style: const TextStyle(color: appRed)),
            ),
          _section('Network map'),
          _nodeTile(icon: Icons.router_outlined, title: _hostname, subtitle: 'Main router · RG-MA3063'),
          _connector(),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Connected devices', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (_clients.isEmpty)
            const GlassCard(child: Text('No online devices found.', style: TextStyle(color: appMuted)))
          else
            for (final c in _clients)
              _nodeTile(
                icon: deviceIconForKey(_icons[(c['mac'] ?? '').toString().toUpperCase()]?.toString()),
                title: _clientName(c),
                subtitle: '${str(c['ip'])} · ${str(c['mac'])}',
                onIconTap: () => _pickIcon(c),
              ),
          _section('Clients by WiFi standard'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RepaintBoundary(child: _Donut(counts: standardCounts, order: standardOrder, colors: standardColors)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$total clients', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                          const Text('Total online clients', style: TextStyle(color: appMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final label in standardOrder)
                  if ((standardCounts[label] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: standardColors[label], shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text('${standardCounts[label]}', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                        ],
                      ),
                    ),
                if (!hasStandard)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No standard field was returned for these clients, so the standard is Unknown. The band breakdown below comes from SSID or radio text only.',
                      style: TextStyle(color: appMuted, fontSize: 12, height: 1.45),
                    ),
                  ),
                if (bandCounts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('By band', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final e in bandCounts.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value} clients', style: const TextStyle(color: appMuted)),
                    ),
                ],
              ],
            ),
          ),
          _section('Ports'),
          if (_ports.isEmpty)
            const GlassCard(child: Text('No port data returned.', style: TextStyle(color: appMuted)))
          else
            GlassCard(
              child: Row(
                children: [
                  for (final p in _ports)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        decoration: BoxDecoration(
                          color: (p['up'] as bool) ? const Color(0xFFE6F4EA) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: (p['up'] as bool) ? const Color(0xFF16A34A) : appOutlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              (p['up'] as bool) ? Icons.bolt : Icons.link_off_outlined,
                              color: (p['up'] as bool) ? const Color(0xFF137333) : appMuted,
                              size: 20,
                            ),
                            const SizedBox(height: 8),
                            Text(p['portLabel'] as String, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(p['speedLabel'] as String, textAlign: TextAlign.center, style: const TextStyle(color: appMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.counts, required this.order, required this.colors});
  final Map<String, int> counts;
  final List<String> order;
  final Map<String, Color> colors;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(painter: _DonutPainter(counts: counts, order: order, colors: colors)),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.counts, required this.order, required this.colors});
  final Map<String, int> counts;
  final List<String> order;
  final Map<String, Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    if (total == 0) {
      final paint = Paint()
        ..color = appOutlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;
      canvas.drawCircle(center, radius, paint);
      return;
    }
    var start = -90.0 * 3.141592653589793 / 180.0;
    for (final label in order) {
      final count = counts[label] ?? 0;
      if (count == 0) continue;
      final sweep = count / total * 2 * 3.141592653589793;
      final paint = Paint()
        ..color = colors[label] ?? appMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.counts != counts;
}
