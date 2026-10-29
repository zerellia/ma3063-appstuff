import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'custom_ui.dart';
import 'labels.dart';
import 'choice_widgets.dart';

void advShowMsg(BuildContext context, String text) {
  try {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  } catch (_) {}
}

Future<bool> advConfirm(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
      ],
    ),
  );
  return r == true;
}

Widget advField(TextEditingController c, String label, {TextInputType? keyboardType}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(controller: c, keyboardType: keyboardType, decoration: InputDecoration(labelText: label)),
  );
}

Widget advError(String? message) {
  if (message == null || message.isEmpty) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: appRedBg, borderRadius: BorderRadius.circular(16)),
    child: Text(message, style: const TextStyle(color: appRed)),
  );
}

Widget advSection(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: appMuted)),
  );
}

// ---------------- Behavior / parental control ----------------

class BehaviorScreen extends StatefulWidget {
  const BehaviorScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<BehaviorScreen> createState() => _BehaviorScreenState();
}

class _BehaviorScreenState extends State<BehaviorScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rules = [];
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final res = await widget.api.get('/api/v1/lua/behavior/access_ctrl');
    final d = dataOf(res);
    final list = d is Map ? listOf(d['list']) : const [];
    return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rules = await _fetch();
      if (mounted) setState(() => _rules = rules);
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to load rules.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? rule]) async {
    final isEdit = rule != null;
    final name = TextEditingController(text: str(rule?['ruleName'], ''));
    final mac = TextEditingController(text: str(rule?['mac'], ''));
    // url, host, start and end are held as chips and time pickers below.
    var target = str(rule?['target'], 'REJECT');
    if (target != 'REJECT' && target != 'ACCEPT') target = 'REJECT';
    var days = List<String>.from(rule?['weekdays'] is List ? (rule!['weekdays'] as List).map((e) => e.toString()) : _days);
    var by = str(rule?['by'], 'ip') == 'mac' ? 'mac' : 'ip';
    var urls = splitListValue(str(rule?['urlString'], ''));
    var hosts = splitListValue(str(rule?['hostnames'], ''));
    TimeOfDay? startTod = parseDisplayTime(str(rule?['startTime'], ''));
    TimeOfDay? endTod = parseDisplayTime(str(rule?['endTime'], ''));
    String? dialogError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isEdit ? 'Edit rule' : 'Add rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dialogError != null) Text(dialogError!, style: const TextStyle(color: appRed)),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Rule name')),
                const SizedBox(height: 8),
                TextField(controller: mac, decoration: const InputDecoration(labelText: 'Device MAC')),
                const SizedBox(height: 8),
                SegmentedControl<String>(
                  options: const [('REJECT', 'Block'), ('ACCEPT', 'Allow')],
                  value: target,
                  onChanged: (v) => setD(() => target = v),
                ),
                const SizedBox(height: 8),
                SegmentedControl<String>(
                  options: const [('ip', 'By website list'), ('mac', 'By device list')],
                  value: by,
                  onChanged: (v) => setD(() => by = v),
                ),
                const SizedBox(height: 8),
                if (by == 'ip')
                  ChipInput(values: urls, onChanged: (v) => setD(() => urls = v), addLabel: 'Add a blocked website', hint: 'example.com')
                else
                  ChipInput(values: hosts, onChanged: (v) => setD(() => hosts = v), addLabel: 'Add a hostname', hint: 'example.com'),
                const SizedBox(height: 16),
                TimePickerRow(label: 'Start time', value: startTod, onChanged: (v) => setD(() => startTod = v), onClear: () => setD(() => startTod = null)),
                const SizedBox(height: 16),
                TimePickerRow(label: 'End time', value: endTod, onChanged: (v) => setD(() => endTod = v), onClear: () => setD(() => endTod = null)),
                const SizedBox(height: 8),
                WeekdayChips(selected: days.toSet(), onChanged: (v) => setD(() => days = v.toList())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || mac.text.trim().isEmpty) {
                  setD(() => dialogError = 'Rule name and MAC are required.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final payload = {
      'by': by,
      'mac': mac.text.trim(),
      'src': 'lan',
      'dest': 'wan',
      'srcIP': '',
      'destIP': '',
      'srcPort': '',
      'destPort': '',
      'proto': 'all',
      'target': target,
      'tmngtName': '',
      'ruleName': name.text.trim(),
      'urlString': by == 'ip' ? urls.join(', ') : '',
      'hostnames': by == 'mac' ? hosts.join(', ') : '',
      'weekdays': days,
      'startTime': startTod == null ? '' : formatDisplayTime(startTod!),
      'endTime': endTod == null ? '' : formatDisplayTime(endTod!),
      'mode': '0',
    };
    try {
      await widget.api.post(
        isEdit ? '/api/v1/lua/behavior/setAccessCtrlupdate' : '/api/v1/lua/behavior/setAccessCtrladd',
        {'list': [payload]},
      );
      final after = await _fetch();
      final found = after.any((r) => str(r['ruleName']) == name.text.trim());
      if (mounted) setState(() => _rules = after);
      advShowMsg(context, found ? (isEdit ? 'Rule updated and verified.' : 'Rule added and verified.') : 'Router accepted the change, but the rule was not found on reload. Check the list.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save rule.');
    }
  }

  Future<void> _delete(Map<String, dynamic> rule) async {
    final uuid = rule['uuid'];
    if (uuid == null) {
      advShowMsg(context, 'This rule has no id, so it cannot be deleted from here.');
      return;
    }
    final ok = await advConfirm(context, 'Delete rule', 'Delete rule ${str(rule['ruleName'])}?');
    if (!ok) return;
    try {
      await widget.api.post('/api/v1/lua/behavior/setAccessCtrldel', {'uuid': [uuid]});
      final after = await _fetch();
      final gone = !after.any((r) => r['uuid'] == uuid);
      if (mounted) setState(() => _rules = after);
      advShowMsg(context, gone ? 'Rule deleted and verified.' : 'Router accepted the delete, but the rule is still listed on reload.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to delete rule.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: RefreshIndicator(
        onRefresh: _load,
        child: DetailScroll(
  title: 'Parental control',
  loading: _loading,
  children: [
            advError(_error),
            GlassCard(
              child: Text(
                '${_rules.length} of 32 rules used. Rules are enforced by the router, not by this phone.',
                style: const TextStyle(color: appMuted, height: 1.45),
              ),
            ),
            if (_loading)
              skeletonCard()
            else if (_rules.isEmpty)
              emptyState('No rules yet', 'Add a rule to limit a device by time or blocked sites.', 'Add rule', () => _edit())
            else
              for (final r in _rules)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(str(r['ruleName']), style: const TextStyle(fontWeight: FontWeight.w700))),
                          pillChip(BehaviorTarget.fromCode(r['target']).label, active: str(r['target']) == 'REJECT', color: str(r['target']) == 'REJECT' ? appRed : appGreen),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('MAC ${str(r['mac'])}', style: const TextStyle(color: appMuted)),
                      if (str(r['urlString'], '').isNotEmpty) Text('Websites: ${str(r['urlString'])}', style: const TextStyle(color: appMuted)),
                      if (str(r['hostnames'], '').isNotEmpty) Text('Hostnames: ${str(r['hostnames'])}', style: const TextStyle(color: appMuted)),
                      Text('Days: ${Weekday.summary(r['weekdays'] is List ? (r['weekdays'] as List).map((e) => e.toString()).toList() : const <String>[])}', style: const TextStyle(color: appMuted)),
                      if (str(r['startTime'], '').isNotEmpty || str(r['endTime'], '').isNotEmpty)
                        Text('Time ${str(r['startTime'])} to ${str(r['endTime'])}', style: const TextStyle(color: appMuted)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => _edit(r), child: const Text('Edit'))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton(onPressed: () => _delete(r), child: const Text('Delete'))),
                        ],
                      ),
                    ],
                  ),
                ),
            FilledButton.icon(onPressed: _rules.length >= 32 ? null : () => _edit(), icon: const Icon(Icons.add), label: const Text('Add rule')),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

// ---------------- Radio ----------------

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _radios = [];
  List<String> _ch24 = [];
  List<String> _ch50 = [];
  final Map<String, String> _chFreq = {};
  bool _wifiFirst = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.get('/api/v1/lua/Radio/getRadioList');
      final d = dataOf(res);
      if (d is Map) {
        _wifiFirst = d['wifiFirst'] == true;
        final list = listOf(d['radioList']);
        _radios = list.whereType<Map>().map((m) {
          final r = Map<String, dynamic>.from(m);
          r['enable'] = r['enable'] == true || r['enable'] == 'yes';
          r['channel'] = r['channel'] == 0 ? 'auto' : r['channel'].toString();
          r['bandWidth'] = (r['bandWidth'] ?? 'auto').toString();
          r['txpower'] = (r['txpower'] ?? 'auto').toString();
          if (r['txpower'] == '') r['txpower'] = 'auto';
          return r;
        }).toList();
      }
      try {
        final ch = await widget.api.get('/api/v1/lua/Radio/getChannel');
        final cd = dataOf(ch);
        if (cd is Map) {
          final c24 = cd['channel2G'];
          final c50 = cd['channel5G'];
          String parseChannel(dynamic e) {
            if (e is Map) {
              final v = (e['v'] ?? e['value'] ?? e['channel'])?.toString() ?? '';
              final k = e['k']?.toString();
              if (v.isNotEmpty && k != null && k.isNotEmpty) _chFreq[v] = k;
              return v;
            }
            return e.toString();
          }

          if (c24 is Map && c24['items'] is List) _ch24 = (c24['items'] as List).map(parseChannel).where((e) => e.isNotEmpty).toList();
          if (c50 is Map && c50['items'] is List) _ch50 = (c50['items'] as List).map(parseChannel).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {}
      try {
        final bw = await widget.api.get('/api/v1/lua/Radio/getBandWidthMap');
        final bd = dataOf(bw);
        if (bd is Map && bd['bandForFive'] is List) {
        }
      } catch (_) {}
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to load radios.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _channelsFor(Map<String, dynamic> r) {
    final type = str(r['type']);
    final base = type.contains('5') ? _ch50 : _ch24;
    final fallback = type.contains('5') ? ['36', '40', '44', '48', '149', '153', '157', '161'] : ['1', '6', '11'];
    return ['auto', ...(base.isEmpty ? fallback : base)];
  }

  Future<void> _save() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = {
      'radioList': _radios.map((r) {
        return {
          'type': r['type'],
          'radioIndex': (r['radioIndex'] ?? '').toString(),
          'enable': r['enable'] == true,
          'channel': r['channel'] == 'auto' ? 'auto' : int.tryParse(r['channel'].toString()) ?? r['channel'],
          'bandWidth': r['bandWidth'],
          'txpower': r['txpower'],
          'hwmode': r['hwmode'] ?? '11ax',
          'wmeSwitch': r['wmeSwitch'] ?? 'on',
          'beacon_txpow_p': '0',
          'beacon_txpow': '0',
          'assoc_rssi': '0',
          'response_rssi': '0',
        };
      }).toList(),
      'wifiFirst': _wifiFirst,
      'configId': '$now',
      'currentTime': '$now',
      'configTime': '$now',
      'version': '1.0.0',
    };
    try {
      await widget.api.post('/api/v1/lua/Radio/setRadio', payload);
      final before = _radios.map((r) => '${r['type']}:${r['channel']}:${r['bandWidth']}').join(';');
      await _load();
      final after = _radios.map((r) => '${r['type']}:${r['channel']}:${r['bandWidth']}').join(';');
      advShowMsg(context, before == after ? 'Radio saved and verified on reload.' : 'Router accepted the change, but reload shows different values. Check the list above.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save radio.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'Radio',
  loading: _loading,
  children: [
          advError(_error),
          if (_loading)
            skeletonCard()
          else if (_radios.isEmpty)
            emptyState('No radio data', 'The router did not return a radio list.', 'Retry', _load)
          else
            for (var i = 0; i < _radios.length; i++) _radioCard(i),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 0), 
                  value: _wifiFirst,
                  onChanged: (v) => setState(() => _wifiFirst = v),
                  title: const Text('Prefer 5 GHz first (Band steering)'),
                  subtitle: const Text('Steer supporting devices to 5G first.', style: TextStyle(color: appMuted)),
                ),

              ],
            ),
          ),
          FilledButton(onPressed: _save, child: const Text('Save radio')),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }

  Widget _radioCard(int i) {
    final r = _radios[i];
    final channels = _channelsFor(r);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${radioTypeLabel(r['type'], r['radioIndex'])} radio', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              Switch(
                value: r['enable'] == true,
                onChanged: (v) => setState(() => _radios[i]['enable'] = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          choiceRow('Channel', channelLabel(r['channel'].toString(), is5g: str(r['type']).contains('5'), freq: _chFreq[r['channel'].toString()]), null, () async {
            final is5 = str(r['type']).contains('5');
            final base = channels.isEmpty ? channelOptions(is5g: is5) : channels;
            final opts = <(String, String, String?)>[];
            for (final c in base) {
              opts.add((c, channelLabel(c, is5g: is5, freq: _chFreq[c]), null));
            }
            if (!base.contains(r['channel'].toString())) opts.insert(0, (r['channel'].toString(), 'Custom setting', 'Tap to choose a standard option.'));
            final picked = await showChoiceSheet<String>(context, title: 'Channel', options: opts, current: r['channel'].toString());
            if (picked != null) setState(() => _radios[i]['channel'] = picked);
          }),
          choiceRow('Bandwidth', bandwidthLabel(r['bandWidth'].toString(), is5g: str(r['type']).contains('5')), null, () async {
            final is5 = str(r['type']).contains('5');
            final codes = is5 ? ['auto', 'auto_160', '20', '40', '80', '160'] : ['20', '40', '20_40'];
            final opts = <(String, String, String?)>[for (final b in codes) (b, bandwidthLabel(b, is5g: is5), null)];
            if (!codes.contains(r['bandWidth'].toString())) opts.insert(0, (r['bandWidth'].toString(), 'Custom setting', 'Tap to choose a standard option.'));
            final picked = await showChoiceSheet<String>(context, title: 'Bandwidth', options: opts, current: r['bandWidth'].toString());
            if (picked != null) setState(() => _radios[i]['bandWidth'] = picked);
          }),
          const Text('Signal strength', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedControl<TxPower>(
            options: const [(TxPower.automatic, 'Automatic'), (TxPower.throughWall, 'Through-wall'), (TxPower.balanced, 'Balanced'), (TxPower.eco, 'Eco')],
            value: TxPower.fromCode(r['txpower']),
            onChanged: (v) => setState(() => _radios[i]['txpower'] = v.code),
          ),
          const SizedBox(height: 12),
          Text(TxPower.fromCode(r['txpower']).description, style: const TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
          const SizedBox(height: 16),
          const Text('WiFi generation', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedControl<String>(
            options: const [('11ax', 'WiFi 6'), ('11ac', 'WiFi 5'), ('11n', 'WiFi 4')],
            value: (r['hwmode'] ?? '11ax').toString(),
            onChanged: (v) => setState(() => _radios[i]['hwmode'] = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 0), 
            value: (r['wmeSwitch'] ?? 'on').toString() == 'on',
            onChanged: (v) => setState(() => _radios[i]['wmeSwitch'] = v ? 'on' : 'off'),
            title: const Text('WMM'),
            subtitle: const Text('Multimedia prioritisation for WiFi traffic.', style: TextStyle(color: appMuted)),
          ),
        ],
      ),
    );
  }
}

// ---------------- Mesh detail, config, topology ----------------

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _children = [];
  Map<String, dynamic> _mainData = {};
  String _mode = '';
  bool _roaming = false;
  int _t24i = -70;
  int _t5i = -70;
  bool _easyMesh = false;
  String _pairResult = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.get('/api/v1/lua/mesh/MeshGetTopo');
      final d = dataOf(res);
      if (d is Map) {
        if (d['mainData'] is Map) _mainData = Map<String, dynamic>.from(d['mainData'] as Map);
        final cl = d['childList'];
        if (cl is List) {
          _children = cl;
        } else if (cl is Map) {
          _children = cl.values.toList();
        } else {
          _children = [];
        }
      }
      try {
        final gm = await widget.api.get('/api/v1/lua/mesh/GetMesh');
        final gd = dataOf(gm);
        if (gd is Map && gd['mode'] != null) _mode = gd['mode'].toString();
      } catch (_) {}
      try {
        final rc = await widget.api.get('/api/v1/lua/mesh/getMeshRoamingCfg');
        final rd = dataOf(rc);
        if (rd is Map) {
          _roaming = rd['roamingSwitch'] == 'enable';
          if (rd['threshold24G'] != null) _t24i = int.tryParse(rd['threshold24G'].toString()) ?? -70;
          if (rd['threshold5G'] != null) _t5i = int.tryParse(rd['threshold5G'].toString()) ?? -70;
        }
      } catch (_) {}
      try {
        final em = await widget.api.get('/api/v1/lua/mesh/getEasyMesh');
        final ed = dataOf(em);
        _easyMesh = ed == 1 || ed == '1' || ed == true;
      } catch (_) {}
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to load mesh.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveMode() async {
    try {
      await widget.api.post('/api/v1/lua/mesh/SetMesh', {'mode': _mode});
      await _load();
      advShowMsg(context, 'Mesh mode is now ${MeshMode.fromCode(_mode).label}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save mesh mode.');
    }
  }

  Future<void> _saveRoaming() async {
    final t24 = _t24i.clamp(-90, -40);
    final t5 = _t5i.clamp(-90, -40);
    try {
      await widget.api.post('/api/v1/lua/mesh/setMeshRoamingCfg', {
        'roamingSwitch': _roaming ? 'enable' : 'disable',
        'threshold24G': '$t24',
        'threshold5G': '$t5',
      });
      await _load();
      advShowMsg(context, 'Roaming saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save roaming.');
    }
  }

  Future<void> _saveEasyMesh() async {
    try {
      await widget.api.post('/api/v1/lua/mesh/setEasyMesh', {'status': _easyMesh ? '1' : '0'});
      await _load();
      advShowMsg(context, 'EasyMesh saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save EasyMesh.');
    }
  }

  Future<void> _startPairing() async {
    setState(() => _pairResult = 'Starting mesh pairing. This needs a real mesh device nearby.');
    try {
      dynamic oldNum;
      try {
        final n = await widget.api.get('/api/v1/lua/mesh/getNowMeshNum');
        oldNum = dataOf(n);
      } catch (_) {
        oldNum = 1;
      }
      await widget.api.post('/api/v1/lua/mesh/SetMeshNetworking', {'wpsswitch': 'on'});
      await Future.delayed(const Duration(seconds: 3));
      try {
        final s = await widget.api.post('/api/v1/lua/mesh/GetMeshingSuccess', {'oldNum': oldNum});
        final ok = dataOf(s) == 1 || dataOf(s) == '1';
        if (mounted) setState(() => _pairResult = ok ? 'Mesh node count increased.' : 'Mesh node count did not increase. Check the new device and try again.');
      } catch (_) {
        if (mounted) setState(() => _pairResult = 'Pairing result is uncertain. Reload to check the node count.');
      }
      await _load();
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _pairResult = e is ApiException ? e.message : 'Mesh pairing failed.');
    }
  }

  String _nodeName(dynamic n) {
    if (n is Map) return str(n['hostName'] ?? n['hostname'] ?? n['name'] ?? n['mac'], 'Mesh node');
    return n.toString();
  }

  List<dynamic> _nodeChildren(dynamic n) {
    if (n is Map) {
      final c = n['childList'];
      if (c is List) return c;
      if (c is Map) return c.values.toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'Mesh',
  loading: _loading,
  children: [
          advError(_error),
          advSection('Mesh nodes'),
          if (_loading)
            skeletonCard()
          else
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: appBlue, borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.router_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(_mainData['hostName'] ?? _mainData['hostname'], 'Main router'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('Mode: ${MeshMode.fromCode(_mode).label}', style: const TextStyle(color: appMuted, fontSize: 12)),
                            Text('${meshNodeCount(_children.isEmpty ? {} : _children)} node(s) total. No signal values are shown because the router does not report mesh signal strength.', style: const TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_children.isEmpty)
                    const Text('No mesh child nodes. This router is the only node.', style: TextStyle(color: appMuted))
                  else
                    for (final child in _children) _topoNode(child, 0),
                ],
              ),
            ),
          advSection('Mesh mode'),
          GlassCard(
            child: Column(
              children: [
                SegmentedControl<MeshMode>(
                    options: const [(MeshMode.controller, 'Main router'), (MeshMode.agent, 'Mesh child'), (MeshMode.unknown, 'Not in mesh')],
                    value: MeshMode.fromCode(_mode),
                    onChanged: (v) => setState(() => _mode = v.code),
                  ),
                const SizedBox(height: 8),
                Text(MeshMode.fromCode(_mode).description, style: const TextStyle(color: appMuted, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _saveMode, child: const Text('Save mesh mode')),
              ],
            ),
          ),
          advSection('Roaming'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 0), value: _roaming, onChanged: (v) => setState(() => _roaming = v), title: const Text('Roaming enabled')),
                RoamingSlider(label: '2.4 GHz threshold', dbm: _t24i, onChanged: (v) => setState(() => _t24i = v)),
                const SizedBox(height: 8),
                RoamingSlider(label: '5 GHz threshold', dbm: _t5i, onChanged: (v) => setState(() => _t5i = v)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _saveRoaming, child: const Text('Save roaming')),
              ],
            ),
          ),
          advSection('EasyMesh'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 0), value: _easyMesh, onChanged: (v) => setState(() => _easyMesh = v), title: const Text('EasyMesh')),
                FilledButton(onPressed: _saveEasyMesh, child: const Text('Save EasyMesh')),
              ],
            ),
          ),
          advSection('Add a mesh node'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This starts the stock mesh pairing step. A real mesh device must be nearby, and the result is checked by node count, not assumed.', style: TextStyle(color: appMuted, height: 1.45)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _startPairing, child: const Text('Start mesh pairing')),
                if (_pairResult.isNotEmpty) ...[const SizedBox(height: 8), Text(_pairResult, style: const TextStyle(height: 1.45))],
              ],
            ),
          ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }

  Widget _topoNode(dynamic node, int level) {
    final kids = _nodeChildren(node);
    return Padding(
      padding: EdgeInsets.only(left: level * 16, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: appBlue),
              const SizedBox(width: 8),
              Expanded(child: Text(_nodeName(node), style: const TextStyle(fontWeight: FontWeight.w700))),
              if (node is Map && node['mac'] != null) Text(str(node['mac']), style: const TextStyle(color: appMuted, fontSize: 12)),
            ],
          ),
          for (final k in kids) _topoNode(k, level + 1),
        ],
      ),
    );
  }
}
