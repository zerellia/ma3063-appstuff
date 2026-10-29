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
          const GlassCard(
            child: Text(
              'Lines show devices connected to the main router.',
              style: TextStyle(color: appMuted, height: 1.45),
            ),
          ),
          if (_clients.isEmpty)
            const GlassCard(child: Text('No online devices found.', style: TextStyle(color: appMuted)))
          else
            _StarMap(
              hostname: _hostname,
              clients: _clients,
              clientName: _clientName,
              iconFor: (c) => deviceIconForKey(_icons[(c['mac'] ?? '').toString().toUpperCase()]?.toString()),
              onTap: _pickIcon,
            ),
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
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}

/// Star map: router at the top centre, one straight line to each
/// connected device below. Lines mean only that the device is
/// connected to the main router, never a mesh node or a port, because
/// the router does not report that attachment. Device positions are
/// computed from the same grid formula the painter uses, so lines and
/// nodes always line up. Tapping a device opens the local icon picker.
class _StarMap extends StatelessWidget {
  const _StarMap({required this.hostname, required this.clients, required this.clientName, required this.iconFor, required this.onTap});
  final String hostname;
  final List<Map<String, dynamic>> clients;
  final String Function(Map<String, dynamic>) clientName;
  final IconData Function(Map<String, dynamic>) iconFor;
  final void Function(Map<String, dynamic>) onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 320 ? 3 : 2;
          final cellWidth = width / columns;
          const cellHeight = 104.0;
          const gridTop = 124.0;
          final rows = (clients.length / columns).ceil();
          final height = gridTop + rows * cellHeight;
          Offset deviceCenter(int i) {
            final col = i % columns;
            final row = i ~/ columns;
            return Offset(col * cellWidth + cellWidth / 2, gridTop + row * cellHeight + 24);
          }

          return SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StarLinesPainter(
                      router: Offset(width / 2, 110),
                      targets: [for (var i = 0; i < clients.length; i++) deviceCenter(i)],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: appPrimaryContainer, shape: BoxShape.circle, border: Border.all(color: appBlue, width: 1.5)),
                        child: const Icon(Icons.router_outlined, color: appBlue, size: 32),
                      ),
                      const SizedBox(height: 6),
                      Text(hostname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Text('Main router', style: TextStyle(color: appMuted, fontSize: 12)),
                    ],
                  ),
                ),
                for (var i = 0; i < clients.length; i++) ...[
                  Positioned(
                    left: deviceCenter(i).dx - 24,
                    top: deviceCenter(i).dy - 24,
                    child: GestureDetector(
                      onTap: () => onTap(clients[i]),
                      child: Stack(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: appBlue)),
                            child: Icon(iconFor(clients[i]), color: appBlue, size: 24),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF16A34A), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (i % columns) * cellWidth,
                    top: deviceCenter(i).dy + 28,
                    width: cellWidth,
                    child: GestureDetector(
                      onTap: () => onTap(clients[i]),
                      child: Text(clientName(clients[i]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StarLinesPainter extends CustomPainter {
  const _StarLinesPainter({required this.router, required this.targets});
  final Offset router;
  final List<Offset> targets;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFDBFE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final t in targets) {
      canvas.drawLine(router, t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarLinesPainter old) => old.router != router || old.targets.length != targets.length;
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
