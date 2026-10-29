import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'custom_ui.dart';
import 'labels.dart';
import 'local_store.dart';
import 'speed_test.dart';

/// Local only insights. Charts, history, alerts, reports and the
/// speed test all live on this phone. Nothing here changes the router.
///
/// Performance rules in this screen: computed summaries are cached
/// in memory when loaded, so reopening the screen does not recompute
/// them from SharedPreferences; charts are downsampled to at most 60
/// points and wrapped in RepaintBoundary; long lists use
/// SliverList.builder with keys; the speed test progress lives in a
/// ValueNotifier, so it never rebuilds the whole screen.
class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _samples = [];
  Map<String, dynamic> _history = {};
  List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic>? _cache;
  int? _cacheTime;
  String _report = '';
  List<(String, String, int)> _top3 = [];
  String _busiestHour = '-';
  List<String> _newThisWeek = [];
  final _speedRunning = ValueNotifier<bool>(false);
  final _speedText = ValueNotifier<String>('');
  String _speedDetail = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _speedRunning.dispose();
    _speedText.dispose();
    super.dispose();
  }

  static List<double> downsample(List<double> values, [int max = 60]) {
    if (values.length <= max) return values;
    final step = values.length / max;
    final out = <double>[];
    for (var i = 0; i < max; i++) {
      out.add(values[(i * step).floor()]);
    }
    return out;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final samples = await LocalStore.samples();
    final history = await LocalStore.history();
    final alerts = await LocalStore.alerts();
    final cache = await LocalStore.homeCache();
    if (!mounted) return;
    final entries = history.entries.toList();
    entries.sort((a, b) {
      final sa = (a.value is Map ? a.value as Map : {})['sessions'];
      final sb = (b.value is Map ? b.value as Map : {})['sessions'];
      return ((sb ?? 0) as num).compareTo((sa ?? 0) as num);
    });
    final top3 = entries.take(3).map((e) {
      final m = e.value is Map ? e.value as Map : {};
      return (str(m['name'], e.key), e.key, ((m['sessions'] ?? 0) as num).toInt());
    }).toList();
    final hourCounts = <int, int>{};
    for (final s in samples) {
      final t = s['t'];
      if (t is num) {
        final h = DateTime.fromMillisecondsSinceEpoch(t.toInt()).hour;
        hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      }
    }
    var busiest = '-';
    var bestCount = 0;
    hourCounts.forEach((h, c) {
      if (c > bestCount) {
        bestCount = c;
        busiest = '$h:00 with $c samples';
      }
    });
    final weekAgo = DateTime.now().millisecondsSinceEpoch - 7 * 24 * 60 * 60 * 1000;
    final newThisWeek = entries.where((e) {
      final m = e.value is Map ? e.value as Map : {};
      final first = m['firstSeen'];
      return first is num && first.toInt() >= weekAgo;
    }).map((e) {
      final m = e.value is Map ? e.value as Map : {};
      return str(m['name'], e.key);
    }).toList();
    setState(() {
      _samples = samples;
      _history = history;
      _alerts = alerts;
      _cache = cache.$1;
      _cacheTime = cache.$2;
      _report = LocalStore.weeklyReport(history, samples);
      _top3 = top3;
      _busiestHour = busiest;
      _newThisWeek = newThisWeek;
      _loading = false;
    });
  }

  Future<void> _runSpeed() async {
    _speedRunning.value = true;
    _speedText.value = 'Measuring this phone, please wait.';
    _speedDetail = '';
    try {
      final r = await runPhoneSpeedTest(onStage: (s) {
        _speedText.value = '$s, measuring this phone.';
      });
      _speedText.value = '${r.downloadMbps.toStringAsFixed(1)} Mbps down, ${r.uploadMbps.toStringAsFixed(1)} Mbps up';
      if (mounted) setState(() => _speedDetail = 'Based on ${r.bytesDownloaded} bytes downloaded. Phone internet speed, not router WAN speed.');
    } catch (e) {
      _speedText.value = 'Phone speed test failed.';
      if (mounted) setState(() => _speedDetail = '$e');
    } finally {
      _speedRunning.value = false;
    }
  }

  String _time(dynamic ms) {
    if (ms is! num) return '-';
    return formatDisplayDateTimeMs(ms.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final cpus = downsample(_samples.map((s) => s['cpu']).whereType<num>().map((n) => n.toDouble()).toList());
    final mems = downsample(_samples.map((s) => s['mem']).whereType<num>().map((n) => n.toDouble()).toList());
    final temps = downsample(_samples.map((s) => s['temp']).whereType<num>().map((n) => n.toDouble()).toList());
    final historyEntries = _history.entries.toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: DetailTopBar(title: 'Local insights', subtitle: 'Local only, on this phone'),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const GlassCard(
                  child: Text(
                    'Local only. Charts are samples taken while the app was open, history is recorded on this phone, and the speed test measures this phone. None of this changes the router.',
                    style: TextStyle(color: appMuted, height: 1.45),
                  ),
                ),
                if (_loading) skeletonCard(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Health charts, sampled while the app is open', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk)),
                ),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CPU %', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      RepaintBoundary(child: Sparkline(values: cpus)),
                      const SizedBox(height: 12),
                      const Text('Memory %', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      RepaintBoundary(child: Sparkline(values: mems, color: appCyan)),
                      const SizedBox(height: 12),
                      const Text('CPU temperature', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      RepaintBoundary(child: Sparkline(values: temps, color: appAmber)),
                      const SizedBox(height: 8),
                      Text('${_samples.length} samples stored on this phone, newest last. Charts show at most 60 points.', style: const TextStyle(color: appMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Phone speed test', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk)),
                ),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('This measures the phone internet speed, not the router WAN speed.', style: TextStyle(color: appMuted, height: 1.45)),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<bool>(
                        valueListenable: _speedRunning,
                        builder: (_, running, __) => FilledButton(onPressed: running ? null : _runSpeed, child: Text(running ? 'Measuring...' : 'Run phone speed test')),
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: _speedText,
                        builder: (_, text, __) => text.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()], height: 1.3)),
                              ),
                      ),
                      if (_speedDetail.isNotEmpty) ...[const SizedBox(height: 4), Text(_speedDetail, style: const TextStyle(color: appMuted, fontSize: 12, height: 1.4))],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Weekly summary, local only', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk)),
                ),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_report.isEmpty ? 'No report yet.' : _report, style: const TextStyle(height: 1.5)),
                      const SizedBox(height: 10),
                      Text('Top devices by sessions (local): ${_top3.isEmpty ? 'none yet' : _top3.map((t) => '${t.$1} (${t.$3})').join(', ')}', style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 4),
                      Text('Busiest hour from samples (local): $_busiestHour', style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 4),
                      Text('New devices this week (local): ${_newThisWeek.isEmpty ? 'none' : _newThisWeek.join(', ')}', style: const TextStyle(height: 1.45)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Device history, local only', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk)),
                ),
                if (_history.isEmpty)
                  emptyState('No device history yet', 'History is recorded when the Devices page loads. Open Devices, then come back here.', 'Refresh', _load),
              ]),
            ),
          ),
          if (_history.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: historyEntries.length,
                itemBuilder: (context, i) {
                  final e = historyEntries[i];
                  final m = e.value is Map ? e.value as Map : {};
                  return GlassCard(
                    key: ValueKey('hist_${e.key}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(m['name'], e.key), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(e.key, style: const TextStyle(color: appMuted, fontSize: 12)),
                        Text('First seen: ${_time(m['firstSeen'])}', style: const TextStyle(color: appMuted, fontSize: 12)),
                        Text('Last seen: ${_time(m['lastSeen'])}', style: const TextStyle(color: appMuted, fontSize: 12)),
                        Text('Sessions: ${str(m['sessions'], '0')}', style: const TextStyle(color: appMuted, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Local alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk)),
                ),
                if (_alerts.isEmpty)
                  const GlassCard(child: Text('No local alerts yet. Alerts are created only from values this app has actually observed, for example a new device or a high CPU or temperature reading.', style: TextStyle(color: appMuted, height: 1.45)))
                else
                  for (final a in _alerts)
                    GlassCard(key: ValueKey('alert_${a['t']}'), child: Text('${_time(a['t'])}: ${str(a['text'])}', style: const TextStyle(height: 1.45))),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Offline cache', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: appInk)),
                ),
                GlassCard(
                  child: Text(
                    _cache == null ? 'No cached Home snapshot yet.' : 'Last cached Home snapshot: ${_time(_cacheTime)}.\nHostname: ${str(_cache!['hostname'], '-')}\nWAN IP: ${str(_cache!['wanIp'], '-')}\nClients: ${str(_cache!['clients'], '-')}\nUse the Refresh button on Home to retry the live router.',
                    style: const TextStyle(height: 1.5),
                  ),
                ),
                OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
