import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'local_store.dart';
import 'speed_test.dart';

/// Local only insights. Charts, history, alerts, reports and the
/// speed test all live on this phone. Nothing here changes the router.
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
  String _speed = '';
  bool _speedRunning = false;
  String _report = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final samples = await LocalStore.samples();
    final history = await LocalStore.history();
    final alerts = await LocalStore.alerts();
    final cache = await LocalStore.homeCache();
    if (!mounted) return;
    setState(() {
      _samples = samples;
      _history = history;
      _alerts = alerts;
      _cache = cache.$1;
      _cacheTime = cache.$2;
      _report = LocalStore.weeklyReport(history, samples);
      _loading = false;
    });
  }

  Future<void> _runSpeed() async {
    setState(() {
      _speedRunning = true;
      _speed = 'Measuring this phone, please wait.';
    });
    try {
      final r = await runPhoneSpeedTest(onStage: (s) {
        if (mounted) setState(() => _speed = '$s, measuring this phone.');
      });
      if (mounted) {
        setState(() => _speed = 'Phone internet speed: ${r.downloadMbps.toStringAsFixed(1)} Mbps down, ${r.uploadMbps.toStringAsFixed(1)} Mbps up, based on ${r.bytesDownloaded} bytes downloaded. This is the phone internet speed, not the router WAN speed.');
      }
    } catch (e) {
      if (mounted) setState(() => _speed = 'Phone speed test failed: $e');
    } finally {
      if (mounted) setState(() => _speedRunning = false);
    }
  }

  String _time(dynamic ms) {
    if (ms is! num) return '-';
    return DateTime.fromMillisecondsSinceEpoch(ms.toInt()).toString();
  }

  @override
  Widget build(BuildContext context) {
    final cpus = _samples.map((s) => s['cpu']).whereType<num>().map((n) => n.toDouble()).toList();
    final mems = _samples.map((s) => s['mem']).whereType<num>().map((n) => n.toDouble()).toList();
    final temps = _samples.map((s) => s['temp']).whereType<num>().map((n) => n.toDouble()).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Local insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GlassCard(
            child: Text(
              'Local only. Charts are samples taken while the app was open, history is recorded on this phone, and the speed test measures this phone. None of this changes the router.',
              style: TextStyle(color: appMuted, height: 1.45),
            ),
          ),
          if (_loading) skeletonCard(),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('Health charts, sampled while the app is open', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: appInk)),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CPU %', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Sparkline(values: cpus),
                const SizedBox(height: 12),
                const Text('Memory %', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Sparkline(values: mems, color: appCyan),
                const SizedBox(height: 12),
                const Text('CPU temperature', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Sparkline(values: temps, color: appAmber),
                const SizedBox(height: 8),
                Text('${_samples.length} samples stored on this phone, newest last.', style: const TextStyle(color: appMuted, fontSize: 12)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('Phone speed test', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: appInk)),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This measures the phone internet speed, not the router WAN speed.', style: TextStyle(color: appMuted, height: 1.45)),
                const SizedBox(height: 10),
                FilledButton(onPressed: _speedRunning ? null : _runSpeed, child: Text(_speedRunning ? 'Measuring...' : 'Run phone speed test')),
                if (_speed.isNotEmpty) ...[const SizedBox(height: 10), Text(_speed, style: const TextStyle(height: 1.45))],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('Device history, local only', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: appInk)),
          ),
          if (_history.isEmpty)
            emptyState('No device history yet', 'History is recorded when the Devices page loads. Open Devices, then come back here.', 'Refresh', _load)
          else
            for (final e in _history.entries)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str((e.value is Map ? e.value as Map : {})['name'], e.key), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(e.key, style: const TextStyle(color: appMuted, fontSize: 12)),
                    Text('First seen: ${_time((e.value is Map ? e.value as Map : {})['firstSeen'])}', style: const TextStyle(color: appMuted, fontSize: 12)),
                    Text('Last seen: ${_time((e.value is Map ? e.value as Map : {})['lastSeen'])}', style: const TextStyle(color: appMuted, fontSize: 12)),
                    Text('Sessions: ${str((e.value is Map ? e.value as Map : {})['sessions'], '0')}', style: const TextStyle(color: appMuted, fontSize: 12)),
                  ],
                ),
              ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('Local alerts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: appInk)),
          ),
          if (_alerts.isEmpty)
            const GlassCard(child: Text('No local alerts yet. Alerts are created only from values this app has actually observed, for example a new device or a high CPU or temperature reading.', style: TextStyle(color: appMuted, height: 1.45)))
          else
            for (final a in _alerts)
              GlassCard(child: Text('${_time(a['t'])}: ${str(a['text'])}', style: const TextStyle(height: 1.45))),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('Weekly report, local only', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: appInk)),
          ),
          GlassCard(child: Text(_report.isEmpty ? 'No report yet.' : _report, style: const TextStyle(height: 1.5))),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('Offline cache', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: appInk)),
          ),
          GlassCard(
            child: Text(
              _cache == null ? 'No cached Home snapshot yet.' : 'Last cached Home snapshot: ${_time(_cacheTime)}.\nHostname: ${str(_cache!['hostname'], '-')}\nWAN IP: ${str(_cache!['wanIp'], '-')}\nClients: ${str(_cache!['clients'], '-')}\nUse the Refresh button on Home to retry the live router.',
              style: const TextStyle(height: 1.5),
            ),
          ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}
