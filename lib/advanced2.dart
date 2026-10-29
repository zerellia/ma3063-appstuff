import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'custom_ui.dart';
import 'advanced.dart';
import 'labels.dart';
import 'choice_widgets.dart';

class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  Widget build(BuildContext context) {
    final items = <(String, String, Widget)>[
      ('Parental control', 'Behavior rules, max 32', BehaviorScreen(api: api, onSessionExpired: onSessionExpired)),
      ('Radio', 'Channel, bandwidth, power', RadioScreen(api: api, onSessionExpired: onSessionExpired)),
      ('Mesh', 'Topology, roaming, EasyMesh', MeshScreen(api: api, onSessionExpired: onSessionExpired)),
      ('Network', 'Static DNS, DMZ, UPnP, WPS, WAN', NetworkScreen(api: api, onSessionExpired: onSessionExpired)),
      ('IPv6', 'Mode and manual WAN and LAN', Ipv6Screen(api: api, onSessionExpired: onSessionExpired)),
      ('System', 'Hostname, time, scheduled reboot, session, language, acceleration, LED schedule, firmware version', SystemScreen(api: api, onSessionExpired: onSessionExpired)),
      ('MAC filter', 'Blacklist and whitelist', FilterScreen(api: api, onSessionExpired: onSessionExpired)),
      ('IPTV and multicast', 'IPTV, IGMP snooping, group transfer', MediaScreen(api: api, onSessionExpired: onSessionExpired)),
    ];
    return Scaffold(
            body: DetailScroll(
  title: 'Advanced router settings',
  children: [
          const GlassCard(
            child: Text(
              'Every change here uses a real stock endpoint from the web panel, and is reloaded after saving. Nothing here is a local only setting, except where a card says so.',
              style: TextStyle(color: appMuted, height: 1.45),
            ),
          ),
          for (final item in items)
            GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(item.$2, style: const TextStyle(color: appMuted)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.$3)),
              ),
            ),
          const GlassCard(
            child: Text(
              'Not in this build on purpose: factory reset execution, firmware file upload, client rename that saves on the router, mesh signal strength, cloud upgrade, telemetry, and province or CMCC plugins. Firmware version is shown read only on the System page.',
              style: TextStyle(color: appMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Network: DNS, DMZ, UPnP, WPS, WAN ----------------

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  bool _loading = true;
  String? _error;
  final _dns1 = TextEditingController();
  final _dns2 = TextEditingController();
  int _dnsType = 1;
  final _dmz = TextEditingController();
  bool _upnp = false;
  String _wps = '-';
  String _detect = '';
  String _wanType = 'dhcp';
  final _mtu = TextEditingController(text: '1500');
  final _pppoeUser = TextEditingController();
  final _pppoePass = TextEditingController();
  final _wanIp = TextEditingController();
  final _wanMask = TextEditingController();
  final _wanGw = TextEditingController();
  final _wanDns = TextEditingController();
  String _wanStatus = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dns1.dispose();
    _dns2.dispose();
    _dmz.dispose();
    _mtu.dispose();
    _pppoeUser.dispose();
    _pppoePass.dispose();
    _wanIp.dispose();
    _wanMask.dispose();
    _wanGw.dispose();
    _wanDns.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dns = await widget.api.post('/api/v1/lua/StaticDns/GetStaticDns', {'DnsType': _dnsType});
      final dd = dataOf(dns);
      if (dd is Map) {
        _dns1.text = str(dd['dns1'], '');
        _dns2.text = str(dd['dns2'], '');
        if (dd['DnsType'] != null) _dnsType = int.tryParse(dd['DnsType'].toString()) ?? _dnsType;
      }
    } catch (_) {}
    try {
      final dmz = await widget.api.get('/api/v1/lua/Dmz/DmzGetHost');
      final dd = dataOf(dmz);
      _dmz.text = dd is String ? dd : (dd is Map ? str(dd['HostIpAddress'], '') : '');
    } catch (_) {}
    try {
      final up = await widget.api.get('/api/v1/lua/UPnP/loadUpnp');
      final dd = dataOf(up);
      if (dd is Map) _upnp = dd['enabled'] == 'yes' || dd['enabled'] == '1' || dd['enabled'] == 1 || dd['enabled'] == true;
    } catch (_) {}
    try {
      final wps = await widget.api.get('/api/v1/lua/Wps/GetWpsInfo');
      final dd = dataOf(wps);
      if (dd is Map && dd['wpsswitch'] != null) _wps = str(dd['wpsswitch']);
    } catch (_) {}
    try {
      final w = await widget.api.get('/api/v1/lua/network/wanget');
      final dd = dataOf(w);
      if (dd is Map && dd['wan'] is Map) {
        final wan = dd['wan'] as Map;
        _wanStatus = '${wanProtoLabel(wan['proto'])} · ${str(wan['ip'], '-')}';
        final proto = str(wan['proto'], '').toLowerCase();
        _wanType = proto.contains('pppoe') ? 'pppoe' : (proto.contains('static') ? 'static' : 'dhcp');
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveDns() async {
    try {
      await widget.api.post('/api/v1/lua/StaticDns/SetStaticDns', {
        'dns_server': [_dns1.text.trim(), _dns2.text.trim()].where((e) => e.isNotEmpty).toList(),
        'dns1': _dns1.text.trim(),
        'dns2': _dns2.text.trim(),
        'DnsType': _dnsType,
      });
      await _load();
      advShowMsg(context, 'Static DNS saved. Reload shows ${_dns1.text} and ${_dns2.text}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save DNS.');
    }
  }

  Future<void> _saveDmz() async {
    try {
      await widget.api.post('/api/v1/lua/Dmz/DmzSetHost', {'HostIpAddress': _dmz.text.trim()});
      await _load();
      advShowMsg(context, 'DMZ saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save DMZ.');
    }
  }

  Future<void> _saveUpnp() async {
    try {
      await widget.api.post('/api/v1/lua/UPnP/setUpnp', {'upnpSwitch': _upnp ? 'yes' : 'no'});
      await _load();
      advShowMsg(context, 'UPnP saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save UPnP.');
    }
  }

  Future<void> _setWps(String state) async {
    try {
      await widget.api.post('/api/v1/lua/Wps/SetWpsInfo', {'wpsswitch': state});
      await _load();
      advShowMsg(context, 'WPS is now ${state == 'on' ? 'On' : 'Off'}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to set WPS.');
    }
  }

  Future<void> _saveWan() async {
    final form = {
      'proto': _wanType,
      'mtu': _mtu.text.trim(),
      'pppoeUser': _pppoeUser.text.trim(),
      'pppoePass': _pppoePass.text.trim(),
      'ipaddr': _wanIp.text.trim(),
      'netmask': _wanMask.text.trim(),
      'gateway': _wanGw.text.trim(),
      'dns': _wanDns.text.trim(),
    };
    final ok = await advConfirm(context, 'Change WAN', 'Apply ${WanType.fromCode(form['proto']).label}? The internet connection will restart.');
    if (!ok) return;
    try {
      await widget.api.post('/api/v1/lua/network/wansetPlain', form);
      await Future.delayed(const Duration(seconds: 3));
      await _load();
      advShowMsg(context, 'WAN saved. Reload shows $_wanStatus.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save WAN.');
    }
  }

  Future<void> _detectWan() async {
    setState(() => _detect = 'Detecting, waiting for the router result.');
    try {
      final res = await widget.api.post('/api/v1/lua/network/getWandetect', {});
      final d = dataOf(res);
      String human;
      if (d is Map) {
        final t = d['type'] ?? d['proto'] ?? d['wanType'] ?? d['result'] ?? d['status'];
        if (t != null && t.toString().isNotEmpty) {
          final wt = WanType.fromCode(t);
          human = wt == WanType.custom ? 'Detected: ${t.toString()}' : 'Detected: ${wt.label}';
        } else {
          human = 'Detection finished, but the router did not name a connection type. Check the WAN cable and settings.';
        }
      } else if (d is String && d.isNotEmpty) {
        human = 'Detected: $d';
      } else {
        human = 'Detection finished, but the router did not name a connection type. Check the WAN cable and settings.';
      }
      setState(() => _detect = human);
      await _load();
    } catch (e) {
      setState(() => _detect = e is ApiException ? 'Detect did not return a result: ${e.message}' : 'Detect did not return a result.');
    }
  }

  Future<void> _pickDmzDevice() async {
    try {
      final res = await widget.api.post('/api/v1/lua/OnlineUsers/sta_list', {'page': 1, 'size': 100});
      final list = listOf(dataOf(res) is Map ? (dataOf(res) as Map)['list'] : const []);
      final opts = <(String, String, String?)>[];
      for (final m in list.whereType<Map>()) {
        final ip = str(m['ip'], '');
        if (ip.isEmpty) continue;
        opts.add((ip, str(m['hostName'] ?? m['deviceName'], 'Unknown device'), 'IP $ip'));
      }
      if (opts.isEmpty) {
        advShowMsg(context, 'No online devices to pick from.');
        return;
      }
      final picked = await showChoiceSheet<String>(context, title: 'Pick a device for DMZ', options: opts, current: _dmz.text.trim());
      if (picked != null) setState(() => _dmz.text = picked);
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to load devices.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'Network',
  children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('Static DNS'),
          GlassCard(
            child: Column(
              children: [
                advField(_dns1, 'Primary DNS'),
                advField(_dns2, 'Secondary DNS'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    CustomChoiceChip(label: 'Cloudflare', selected: false, onTap: () => setState(() { _dns1.text = '1.1.1.1'; _dns2.text = '1.0.0.1'; })),
                    CustomChoiceChip(label: 'Google', selected: false, onTap: () => setState(() { _dns1.text = '8.8.8.8'; _dns2.text = '8.8.4.4'; })),
                    CustomChoiceChip(label: 'Quad9', selected: false, onTap: () => setState(() { _dns1.text = '9.9.9.9'; _dns2.text = '149.112.112.112'; })),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _saveDns, child: const Text('Save DNS')),
              ],
            ),
          ),
          advSection('DMZ'),
          GlassCard(
            child: Column(
              children: [
                advField(_dmz, 'DMZ host IP (empty clears it)'),
                OutlinedButton(onPressed: _pickDmzDevice, child: const Text('Pick a device')),
                const Text('DMZ opens all ports to one device. Only use it for a device you trust.', style: TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
                const SizedBox(height: 8),
                FilledButton(onPressed: _saveDmz, child: const Text('Save DMZ')),
              ],
            ),
          ),
          advSection('UPnP and WPS'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _upnp, onChanged: (v) => setState(() => _upnp = v), title: const Text('UPnP')),
                FilledButton(onPressed: _saveUpnp, child: const Text('Save UPnP')),
                const SizedBox(height: 12),
                Text('WPS: ${(() { final w = _wps.toLowerCase(); if (w == 'on' || w == '1' || w == 'true') return 'On'; if (w == 'off' || w == '0' || w == 'false') return 'Off'; return 'Unknown'; })()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _setWps('on'), child: const Text('WPS on'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _setWps('off'), child: const Text('WPS off'))),
                  ],
                ),
              ],
            ),
          ),
          advSection('WAN'),
          GlassCard(
            child: Column(
              children: [
                Text('Current: $_wanStatus', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SegmentedControl<WanType>(
                  options: const [(WanType.dhcp, 'Automatic'), (WanType.pppoe, 'PPPoE'), (WanType.static, 'Static IP')],
                  value: WanType.fromCode(_wanType),
                  onChanged: (v) => setState(() => _wanType = v.code),
                ),
                Text(WanType.fromCode(_wanType).description, style: const TextStyle(color: appMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    CustomChoiceChip(label: 'Auto (1500)', selected: _mtu.text == '1500', onTap: () => setState(() => _mtu.text = '1500')),
                    CustomChoiceChip(label: '1492 (PPPoE)', selected: _mtu.text == '1492', onTap: () => setState(() => _mtu.text = '1492')),
                    CustomChoiceChip(label: '1400', selected: _mtu.text == '1400', onTap: () => setState(() => _mtu.text = '1400')),
                  ],
                ),
                advField(_mtu, 'MTU (usual default 1500)', keyboardType: TextInputType.number),
                if (_wanType == 'pppoe') ...[
                  advField(_pppoeUser, 'PPPoE username'),
                  advField(_pppoePass, 'PPPoE password'),
                ],
                if (_wanType == 'static') ...[
                  advField(_wanIp, 'Static IP'),
                  advField(_wanMask, 'Static netmask'),
                  advField(_wanGw, 'Static gateway'),
                  advField(_wanDns, 'Static DNS, space separated'),
                ],
                FilledButton(onPressed: _saveWan, child: const Text('Save WAN')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _detectWan, child: const Text('Detect WAN')),
                if (_detect.isNotEmpty) ...[const SizedBox(height: 8), Text(_detect, style: const TextStyle(height: 1.45))],
              ],
            ),
          ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}

// ---------------- IPv6 ----------------

class Ipv6Screen extends StatefulWidget {
  const Ipv6Screen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<Ipv6Screen> createState() => _Ipv6ScreenState();
}

class _Ipv6ScreenState extends State<Ipv6Screen> {
  bool _isUnknownEntry(String key) {
    final base = key.toLowerCase().replaceAll('wan6:', '').replaceAll('lan6:', '').replaceAll('_', '').trim();
    const known = {'ip', 'ipaddr', 'prefix', 'prefixlen', 'gateway', 'dnsprimary', 'dns1', 'dnssecondary', 'dns2', 'staticaddr', 'ulaprefix', 'addrstart', 'addend', 'leasetime', 'dhcpv6server', 'radvd', 'mode', 'address', 'subnet'};
    return !known.contains(base);
  }

  String _ipv6DisplayValue(String key, dynamic value) {
    final v = value?.toString() ?? '';
    if (isSensitiveKey(key)) return '••••••••';
    final base = key.toLowerCase().replaceAll('wan6:', '').replaceAll('lan6:', '').replaceAll('_', '').trim();
    if (base == 'mode') return Ipv6Mode.fromCode(v).label;
    if (base == 'leasetime') {
      for (final o in ipv6LeaseOptions) {
        if (o.$1 == v) return o.$2;
      }
      return v.isEmpty ? 'Not set' : '$v seconds';
    }
    if (base == 'dhcpv6server') {
      for (final o in ipv6DhcpOptions) {
        if (o.$1 == v) return o.$2;
      }
    }
    if (base == 'prefixlen') return v.isEmpty ? 'Not set' : '/$v';
    return v.isEmpty ? 'Not set' : v;
  }

  List<(String, String, String?)> _opt2(List<(String, String)> xs) => [for (final x in xs) (x.$1, x.$2, null)];

  Future<void> _pickOption(String title, List<(String, String, String?)> options, String current, void Function(String) onPick, {bool allowCustom = false}) async {
    final opts = List<(String, String, String?)>.from(options);
    if (!opts.any((o) => o.$1 == current) && current.isNotEmpty) opts.insert(0, (current, 'Custom setting', 'Tap to choose a standard option.'));
    if (allowCustom) opts.add(('__custom__', 'Custom address', 'Type an address that is not in the list.'));
    final picked = await showChoiceSheet<String>(context, title: title, options: opts, current: current);
    if (picked == null) return;
    if (picked == '__custom__') {
      final c = TextEditingController();
      final typed = await showDialog<String>(context: context, builder: (dc) => AlertDialog(title: Text(title), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Address')), actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dc, c.text.trim()), child: const Text('Use this'))]));
      if (typed != null && typed.isNotEmpty) onPick(typed);
      return;
    }
    onPick(picked);
  }

  bool _loading = true;
  String? _error;
  String _mode = '';
  Map<String, dynamic> _entries = {};
  Map<String, dynamic> _wanRaw = {};
  Map<String, dynamic> _lanRaw = {};
  final _wanIp = TextEditingController();
  final _wanPrefix = TextEditingController();
  final _wanPrefixLen = TextEditingController();
  final _wanGw = TextEditingController();
  final _wanDns1 = TextEditingController();
  final _wanDns2 = TextEditingController();
  final _lanStatic = TextEditingController();
  final _lanUla = TextEditingController();
  final _lanStart = TextEditingController();
  final _lanEnd = TextEditingController();
  final _lanLease = TextEditingController();
  final _lanDhcp = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wanIp.dispose();
    _wanPrefix.dispose();
    _wanPrefixLen.dispose();
    _wanGw.dispose();
    _wanDns1.dispose();
    _wanDns2.dispose();
    _lanStatic.dispose();
    _lanUla.dispose();
    _lanStart.dispose();
    _lanEnd.dispose();
    _lanLease.dispose();
    _lanDhcp.dispose();
    super.dispose();
  }

  void _fill(TextEditingController c, Map m, List<String> keys) {
    for (final k in keys) {
      if (m[k] != null && m[k].toString().isNotEmpty) {
        c.text = m[k].toString();
        return;
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.api.get('/api/v1/lua/InternetProtocolVersionSix/GetIPv6Status');
      final sd = dataOf(s);
      if (sd is Map && sd['mode'] != null) _mode = sd['mode'].toString();
    } catch (_) {}
    try {
      final n = await widget.api.get('/api/v1/lua/InternetProtocolVersionSix/getNetwork6');
      final nd = dataOf(n);
      if (nd is Map) {
        final flat = <String, dynamic>{};
        if (nd['wan6'] is List && (nd['wan6'] as List).isNotEmpty) {
          for (final e in (nd['wan6'].first as Map).entries) {
            flat['WAN6: ${e.key}'] = e.value;
          }
        }
        if (nd['lan6'] is List && (nd['lan6'] as List).isNotEmpty) {
          for (final e in (nd['lan6'].first as Map).entries) {
            flat['LAN6: ${e.key}'] = e.value;
          }
        }
        _entries = flat.isEmpty ? Map<String, dynamic>.from(nd) : flat;
      }
    } catch (_) {}
    try {
      final mw = await widget.api.get('/api/v1/lua/InternetProtocolVersionSix/GetManualV6');
      final md = dataOf(mw);
      if (md is Map) {
        _wanRaw = Map<String, dynamic>.from(md);
        _fill(_wanIp, md, ['ip', 'ipaddr']);
        _fill(_wanPrefix, md, ['prefix']);
        _fill(_wanPrefixLen, md, ['prefixlen', 'prefixLen']);
        _fill(_wanGw, md, ['gateway']);
        _fill(_wanDns1, md, ['dnsPrimary', 'dns1']);
        _fill(_wanDns2, md, ['dnsSecondary', 'dns2']);
      }
    } catch (_) {}
    try {
      final ml = await widget.api.get('/api/v1/lua/InternetProtocolVersionSix/GetManualV6Lan');
      final md = dataOf(ml);
      if (md is Map) {
        _lanRaw = Map<String, dynamic>.from(md);
        _fill(_lanStatic, md, ['staticaddr']);
        _fill(_lanUla, md, ['ulaprefix']);
        _fill(_lanStart, md, ['addrstart']);
        _fill(_lanEnd, md, ['addend']);
        _fill(_lanLease, md, ['leasetime']);
        _fill(_lanDhcp, md, ['dhcpv6server']);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveMode() async {
    final mode = int.tryParse(_mode);
    if (mode == null || Ipv6Mode.fromCode(_mode) == Ipv6Mode.custom) {
      advShowMsg(context, 'Choose an IPv6 mode first.');
      return;
    }
    try {
      await widget.api.post('/api/v1/lua/InternetProtocolVersionSix/SetNetwork6', {
        'wan6': [
          {'mode': mode}
        ],
        'type': 'mode',
      });
      await _load();
      advShowMsg(context, 'IPv6 mode is now ${Ipv6Mode.fromCode(_mode).label}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save IPv6 mode.');
    }
  }

  Future<void> _saveWan() async {
    final payload = Map<String, dynamic>.from(_wanRaw);
    void put(String key, String v) {
      if (v.isNotEmpty) payload[key] = v;
    }

    put('ip', _wanIp.text.trim());
    put('prefix', _wanPrefix.text.trim());
    put('prefixlen', _wanPrefixLen.text.trim());
    put('gateway', _wanGw.text.trim());
    put('dnsPrimary', _wanDns1.text.trim());
    put('dnsSecondary', _wanDns2.text.trim());
    try {
      await widget.api.post('/api/v1/lua/InternetProtocolVersionSix/SetManualV6', payload);
      await _load();
      advShowMsg(context, 'Manual IPv6 WAN saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save manual IPv6 WAN.');
    }
  }

  Future<void> _saveLan() async {
    final payload = Map<String, dynamic>.from(_lanRaw);
    void put(String key, String v) {
      if (v.isNotEmpty) payload[key] = v;
    }

    put('staticaddr', _lanStatic.text.trim());
    put('ulaprefix', _lanUla.text.trim());
    put('addrstart', _lanStart.text.trim());
    put('addend', _lanEnd.text.trim());
    put('leasetime', _lanLease.text.trim());
    put('dhcpv6server', _lanDhcp.text.trim());
    try {
      await widget.api.post('/api/v1/lua/InternetProtocolVersionSix/SetManualV6Lan', payload);
      await _load();
      advShowMsg(context, 'Manual IPv6 LAN saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save manual IPv6 LAN.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'IPv6',
  children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('Current IPv6'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode: ${Ipv6Mode.fromCode(_mode).label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final e in _entries.entries.where((e) => !_isUnknownEntry(e.key.toString())))
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${ipv6EntryLabel(e.key.toString())}: ${_ipv6DisplayValue(e.key.toString(), e.value)}', style: const TextStyle(color: appMuted, fontSize: 12))),
                if (_entries.entries.any((e) => _isUnknownEntry(e.key.toString())))
                  ExpansionTile(
                    title: const Text('More details'),
                    children: [
                      for (final e in _entries.entries.where((e) => _isUnknownEntry(e.key.toString())))
                        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${humaniseKey(e.key.toString())}: ${isSensitiveKey(e.key.toString()) ? '••••••••' : e.value}', style: const TextStyle(color: appMuted, fontSize: 12))),
                    ],
                  ),
                if (_entries.isEmpty) const Text('No IPv6 network data returned.', style: TextStyle(color: appMuted)),
              ],
            ),
          ),
          advSection('IPv6 mode'),
          GlassCard(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedControl<Ipv6Mode>(
                    options: const [(Ipv6Mode.v4Only, 'IPv4 only'), (Ipv6Mode.v6Only, 'IPv6 only'), (Ipv6Mode.dual, 'IPv4 and IPv6')],
                    value: Ipv6Mode.fromCode(_mode),
                    onChanged: (v) => setState(() => _mode = v.code),
                  ),
                ),
                Text(Ipv6Mode.fromCode(_mode).description, style: const TextStyle(color: appMuted, fontSize: 12)),
                const SizedBox(height: 8),
                FilledButton(onPressed: _saveMode, child: const Text('Save mode')),
              ],
            ),
          ),
          advSection('Manual IPv6 WAN'),
          GlassCard(
            child: Column(
              children: [
                advField(_wanIp, 'WAN IPv6 address'),
                advField(_wanPrefix, 'Prefix'),
                choiceRow('Prefix length', _wanPrefixLen.text.trim().isEmpty ? 'Keep current' : '/${_wanPrefixLen.text.trim()}', null, () => _pickOption('Prefix length', _opt2(ipv6PrefixOptions), _wanPrefixLen.text.trim(), (v) => setState(() => _wanPrefixLen.text = v))),
                advField(_wanGw, 'Gateway'),
                choiceRow('Primary DNS', _wanDns1.text.trim().isEmpty ? 'Keep current' : _wanDns1.text.trim(), null, () => _pickOption('Primary DNS', _opt2(ipv6DnsOptions), _wanDns1.text.trim(), (v) => setState(() => _wanDns1.text = v), allowCustom: true)),
                choiceRow('Secondary DNS', _wanDns2.text.trim().isEmpty ? 'Keep current' : _wanDns2.text.trim(), null, () => _pickOption('Secondary DNS', _opt2(ipv6DnsOptions), _wanDns2.text.trim(), (v) => setState(() => _wanDns2.text = v), allowCustom: true)),
                FilledButton(onPressed: _saveWan, child: const Text('Save manual WAN')),
              ],
            ),
          ),
          advSection('Manual IPv6 LAN'),
          GlassCard(
            child: Column(
              children: [
                advField(_lanStatic, 'LAN static address'),
                advField(_lanUla, 'Local prefix'),
                advField(_lanStart, 'Address start'),
                advField(_lanEnd, 'Address end'),
                choiceRow('Lease time', _lanLease.text.trim().isEmpty ? 'Keep current' : (ipv6LeaseOptions.where((o) => o.$1 == _lanLease.text.trim()).isEmpty ? '${_lanLease.text.trim()} seconds' : ipv6LeaseOptions.firstWhere((o) => o.$1 == _lanLease.text.trim()).$2), null, () => _pickOption('Lease time', _opt2(ipv6LeaseOptions), _lanLease.text.trim(), (v) => setState(() => _lanLease.text = v))),
                choiceRow('DHCPv6 server', _lanDhcp.text.trim().isEmpty ? 'Keep current' : (ipv6DhcpOptions.where((o) => o.$1 == _lanDhcp.text.trim()).isEmpty ? _lanDhcp.text.trim() : ipv6DhcpOptions.firstWhere((o) => o.$1 == _lanDhcp.text.trim()).$2), null, () => _pickOption('DHCPv6 server', _opt2(ipv6DhcpOptions), _lanDhcp.text.trim(), (v) => setState(() => _lanDhcp.text = v))),
                FilledButton(onPressed: _saveLan, child: const Text('Save manual LAN')),
              ],
            ),
          ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}

// ---------------- System ----------------

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  bool _loading = true;
  String? _error;
  final _hostname = TextEditingController();
  String _tzCode = 'GMT+7:00';
  String _routerTime = '-';
  String _tzName = '-';
  bool _rebootEnabled = false;
  Set<String> _rebootDays = {'wed'};
  TimeOfDay _rebootTime = const TimeOfDay(hour: 3, minute: 0);
  int? _sessionMinutes = 5;
  bool _accSoftware = false;
  bool _accHardware = false;
  bool _accRadio1 = false;
  bool _accRadio2 = false;
  String _ledAll = 'restore';
  List<Map<String, dynamic>> _ledSchedules = [];
  String _firmware = '-';
  String _freeSize = '-';
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostname.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final h = await widget.api.get('/api/v1/lua/Hostname/getHostnamePlain');
      final hd = dataOf(h);
      if (hd is Map && hd['hostname'] != null) _hostname.text = str(hd['hostname']);
    } catch (_) {}
    try {
      final t = await widget.api.get('/api/v1/lua/Time/asyncTime');
      final td = dataOf(t);
      final n = numOrNull(td is Map ? td['time'] ?? td : td);
      if (n != null) _routerTime = formatDisplayDateTime(DateTime.fromMillisecondsSinceEpoch(n.round() * 1000));
    } catch (_) {}
    try {
      final tz = await widget.api.get('/api/v1/lua/Time/getTimezone');
      final td = dataOf(tz);
      if (td is Map) {
        _tzName = str(td['zonename'] ?? td['timezone'], '-');
        if (td['timezone'] != null) _tzCode = str(td['timezone']);
      }
    } catch (_) {}
    try {
      final rb = await widget.api.get('/api/v1/lua/SystemManage/getTimeReboot');
      final rd = dataOf(rb);
      if (rd is Map) {
        _rebootEnabled = rd['enable'] == '1' || rd['enable'] == 1;
        if (rd['week'] is List && (rd['week'] as List).isNotEmpty) _rebootDays = (rd['week'] as List).map((e) => e.toString()).where((e) => _days.contains(e)).toSet();
        if (rd['time'] is List && (rd['time'] as List).length >= 2) {
          final h = int.tryParse((rd['time'] as List)[0].toString());
          final m = int.tryParse((rd['time'] as List)[1].toString());
          if (h != null && m != null) _rebootTime = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
        }
      }
    } catch (_) {}
    try {
      final st = await widget.api.get('/api/v1/lua/userinfo/getSessiontime');
      final sd = dataOf(st);
      if (sd is Map) {
        if (sd['enabled'] == false) {
          _sessionMinutes = null;
        } else if (sd['sessiontime'] != null) {
          _sessionMinutes = (int.tryParse(sd['sessiontime'].toString()) ?? 300) ~/ 60;
        }
      }
    } catch (_) {}
    try {
      final ac = await widget.api.get('/api/v1/lua/AccelerateInfo/GetAccelerateInfo');
      final ad = dataOf(ac);
      if (ad is Map) {
        _accSoftware = ad['software'] == 'yes';
        _accHardware = ad['hardware'] == 'yes';
        _accRadio1 = ad['radio1'] == '1' || ad['radio1'] == 1;
        _accRadio2 = ad['radio2'] == '1' || ad['radio2'] == 1;
      }
    } catch (_) {}
    try {
      final led = await widget.api.get('/api/v1/lua/LED/devLed');
      final ld = dataOf(led);
      if (ld is Map) {
        if (ld['led_all'] != null) _ledAll = str(ld['led_all']);
        if (ld['LedConfigList'] is List) {
          _ledSchedules = (ld['LedConfigList'] as List).whereType<Map>().map((m) {
            final r = Map<String, dynamic>.from(m);
            r['enable'] = r['enable'] == '1' || r['enable'] == 1 || r['enable'] == true || r['enable'] == 'true';
            r['week'] = r['week'] is List ? List<String>.from((r['week'] as List).map((e) => e.toString())) : <String>[];
            r['time'] = r['time'] is List ? List<String>.from((r['time'] as List).map((e) => e.toString())) : <String>['', ''];
            return r;
          }).toList();
        }
      }
    } catch (_) {}
    try {
      final v = await widget.api.get('/api/v1/lua/Upgrade/getVersion');
      final vd = dataOf(v);
      if (vd is Map && vd['version'] != null) _firmware = str(vd['version']);
    } catch (_) {}
    try {
      final f = await widget.api.get('/api/v1/lua/Upgrade/CheckUpgradeFreeSize');
      final fd = dataOf(f);
      if (fd is Map && fd['freeSize'] != null) _freeSize = str(fd['freeSize']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveHostname() async {
    try {
      await widget.api.post('/api/v1/lua/Hostname/setHostnamePlain', {'hostname': _hostname.text.trim()});
      await _load();
      advShowMsg(context, 'Hostname saved. Reload shows ${_hostname.text}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save hostname.');
    }
  }

  Future<void> _saveTimezone() async {
    try {
      await widget.api.post('/api/v1/lua/Time/setTimezone', {'timezone': _tzCode});
      await _load();
      advShowMsg(context, 'Timezone saved: ${timezoneOptions.where((t) => t.$1 == _tzCode).isEmpty ? _tzCode : timezoneOptions.firstWhere((t) => t.$1 == _tzCode).$2}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save timezone.');
    }
  }

  Future<void> _syncPhoneTime() async {
    final sec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await widget.api.post('/api/v1/lua/Time/setSysTime', {'time': sec, 'force': 'true'});
      await _load();
      advShowMsg(context, 'Router time synced to this phone and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to sync time.');
    }
  }

  Future<void> _saveReboot() async {
    try {
      final daysOrdered = _days.where((d) => _rebootDays.contains(d)).toList();
      await widget.api.post('/api/v1/lua/SystemManage/setTimeReboot', {
        'enable': _rebootEnabled ? '1' : '0',
        'week': daysOrdered,
        'time': [_rebootTime.hour.toString().padLeft(2, '0'), _rebootTime.minute.toString().padLeft(2, '0')],
      });
      await _load();
      advShowMsg(context, _rebootEnabled ? 'Scheduled reboot saved: ${Weekday.summary(daysOrdered)} at ${formatDisplayTime(_rebootTime)}.' : 'Scheduled reboot saved and turned off.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save scheduled reboot.');
    }
  }

  Future<void> _saveSession() async {
    final s = (_sessionMinutes ?? 5) * 60;
    try {
      await widget.api.post('/api/v1/lua/userinfo/setSessionTime', {'enabled': _sessionMinutes != null, 'sessiontime': s});
      await _load();
      advShowMsg(context, _sessionMinutes == null ? 'Session timeout saved and turned off.' : 'Session timeout saved: ${_sessionMinutes == 60 ? '1 hour' : '$_sessionMinutes minutes'}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save session timeout.');
    }
  }

  Future<void> _saveAccel() async {
    try {
      await widget.api.post('/api/v1/lua/AccelerateInfo/SetAccelerateInfo', {
        'software': _accSoftware ? 'yes' : 'no',
        'hardware': _accHardware ? 'yes' : 'no',
        'radio1': _accRadio1 ? '1' : '0',
        'radio2': _accRadio2 ? '1' : '0',
      });
      await _load();
      advShowMsg(context, 'Acceleration saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save acceleration.');
    }
  }

  Future<void> _saveLed() async {
    if (_ledAll == 'sched') {
      if (_ledSchedules.isEmpty) {
        advShowMsg(context, 'Add a schedule first before choosing schedule mode.');
        return;
      }
      for (final s in _ledSchedules) {
        final week = s['week'] is List ? s['week'] as List : [];
        final time = s['time'] is List ? s['time'] as List : [];
        if (week.isEmpty || time.length < 2 || time[0].toString().isEmpty || time[1].toString().isEmpty) {
          advShowMsg(context, 'Every LED schedule needs weekdays and a start and end time.');
          return;
        }
      }
    }
    final payloadList = _ledAll == 'sched'
        ? _ledSchedules.map((s) {
            return {
              'enable': (s['enable'] == true) ? '1' : '0',
              'week': s['week'],
              'time': s['time'],
            };
          }).toList()
        : [];
    try {
      await widget.api.post('/api/v1/lua/LED/setLed', {'led_all': _ledAll, 'LedConfigList': payloadList});
      await _load();
      advShowMsg(context, 'LED mode is now ${LedMode.fromCode(_ledAll).label}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save LED.');
    }
  }

  Future<void> _setRouterLanguageEnglish() async {
    try {
      await widget.api.post('/api/v1/lua/Language/setLang', {'lang': 'en'});
      advShowMsg(context, 'Router language set to English.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to set router language.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'System',
  children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('Firmware, read only'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version: $_firmware', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Free size: ${formatFirmwareSize(_freeSize)}', style: const TextStyle(color: appMuted)),
                const SizedBox(height: 8),
                const Text('Firmware file upload and factory reset are not in this build.', style: TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
              ],
            ),
          ),
          advSection('Hostname'),
          GlassCard(
            child: Column(
              children: [
                advField(_hostname, 'Router hostname'),
                FilledButton(onPressed: _saveHostname, child: const Text('Save hostname')),
              ],
            ),
          ),
          advSection('Time and timezone'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Router time: $_routerTime', style: const TextStyle(color: appMuted)),
                Text('Timezone: $_tzName', style: const TextStyle(color: appMuted)),
                const SizedBox(height: 8),
                choiceRow('Timezone', timezoneOptions.where((t) => t.$1 == _tzCode).isEmpty ? _tzCode : timezoneOptions.firstWhere((t) => t.$1 == _tzCode).$2, null, () async {
                  final opts = <(String, String, String?)>[for (final t in timezoneOptions) (t.$1, t.$2, null)];
                  if (!opts.any((o) => o.$1 == _tzCode)) opts.insert(0, (_tzCode, 'Custom setting', 'Tap to choose a standard option.'));
                  final picked = await showChoiceSheet<String>(context, title: 'Timezone', options: opts, current: _tzCode, searchable: true);
                  if (picked != null) setState(() => _tzCode = picked);
                }),
                FilledButton(onPressed: _saveTimezone, child: const Text('Save timezone')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _syncPhoneTime, child: const Text('Sync router time to this phone')),
              ],
            ),
          ),
          advSection('Scheduled reboot'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _rebootEnabled, onChanged: (v) => setState(() => _rebootEnabled = v), title: const Text('Scheduled reboot')),
                WeekdayChips(selected: _rebootDays, onChanged: (v) => setState(() => _rebootDays = v)),
                const SizedBox(height: 8),
                TimePickerRow(label: 'Reboot time', value: _rebootTime, onChanged: (v) => setState(() => _rebootTime = v)),
                FilledButton(onPressed: _saveReboot, child: const Text('Save scheduled reboot')),
              ],
            ),
          ),
          advSection('Session timeout and language'),
          GlassCard(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedControl<int?>(
                    options: const [(null, 'Off'), (5, '5 min'), (15, '15 min'), (30, '30 min'), (60, '1 hour')],
                    value: _sessionMinutes,
                    onChanged: (v) => setState(() => _sessionMinutes = v),
                  ),
                ),
                FilledButton(onPressed: _saveSession, child: const Text('Save session timeout')),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _setRouterLanguageEnglish, child: const Text('Set router language to English')),
              ],
            ),
          ),
          advSection('Acceleration'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _accSoftware, onChanged: (v) => setState(() => _accSoftware = v), title: const Text('Software acceleration')),
                SwitchListTile(value: _accHardware, onChanged: (v) => setState(() => _accHardware = v), title: const Text('Hardware acceleration')),
                SwitchListTile(value: _accRadio1, onChanged: (v) => setState(() => _accRadio1 = v), title: const Text('Radio 1 frame burst')),
                SwitchListTile(value: _accRadio2, onChanged: (v) => setState(() => _accRadio2 = v), title: const Text('Radio 2 frame burst')),
                FilledButton(onPressed: _saveAccel, child: const Text('Save acceleration')),
              ],
            ),
          ),
          advSection('LED schedule'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedControl<LedMode>(
                  options: const [(LedMode.normal, 'Normal'), (LedMode.off, 'LED off'), (LedMode.schedule, 'Schedule')],
                  value: LedMode.fromCode(_ledAll),
                  onChanged: (v) => setState(() => _ledAll = v.code),
                ),
                Text(LedMode.fromCode(_ledAll).description, style: const TextStyle(color: appMuted, fontSize: 12)),
                const SizedBox(height: 8),
                for (var i = 0; i < _ledSchedules.length; i++) _ledScheduleCard(i),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _ledSchedules.add({'enable': true, 'week': <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'time': <String>['22:00', '06:00']})),
                  icon: const Icon(Icons.add),
                  label: const Text('Add LED schedule'),
                ),
                const SizedBox(height: 8),
                const Text('Schedules below are sent as a list. An empty list would not save a schedule.', style: TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
                const SizedBox(height: 8),
                FilledButton(onPressed: _saveLed, child: const Text('Save LED')),
              ],
            ),
          ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }

  Widget _ledScheduleCard(int i) {
    final s = _ledSchedules[i];
    final week = s['week'] is List ? List<String>.from((s['week'] as List).map((e) => e.toString())) : <String>[];
    final time = s['time'] is List ? List<String>.from((s['time'] as List).map((e) => e.toString())) : <String>['', ''];
    while (time.length < 2) {
      time.add('');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: appBorder), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Schedule ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Switch(
                value: s['enable'] == true,
                onChanged: (v) => setState(() => _ledSchedules[i]['enable'] = v),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: appRed), onPressed: () => setState(() => _ledSchedules.removeAt(i))),
            ],
          ),
          WeekdayChips(
            selected: week.toSet(),
            onChanged: (v) => setState(() => _ledSchedules[i]['week'] = v.toList()),
          ),
          const SizedBox(height: 8),
          TimePickerRow(
            label: 'Start',
            value: parseDisplayTime(time.isNotEmpty ? time[0] : ''),
            onChanged: (v) => setState(() => _ledSchedules[i]['time'] = [formatDisplayTime(v), time.length > 1 ? time[1] : '']),
          ),
          TimePickerRow(
            label: 'End',
            value: parseDisplayTime(time.length > 1 ? time[1] : ''),
            onChanged: (v) => setState(() => _ledSchedules[i]['time'] = [time.isNotEmpty ? time[0] : '', formatDisplayTime(v)]),
          ),
        ],
      ),
    );
  }
}

// ---------------- MAC filter ----------------

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  bool _loading = true;
  String? _error;
  String _type = 'deny';
  List<Map<String, dynamic>> _items = [];
  final _name = TextEditingController();
  final _mac = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch(String type) async {
    final res = await widget.api.post('/api/v1/lua/BlackWhiteList/wirelessMacFilter', {'firstIn': 'true', 'type': type});
    final d = dataOf(res);
    if (d is Map) {
      if (d['type'] != null) _type = d['type'].toString() == 'allow' ? 'allow' : 'deny';
      final list = listOf(d['macList']);
      return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _fetch(_type);
      if (mounted) setState(() => _items = items);
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to load MAC filter.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty || _mac.text.trim().isEmpty) {
      advShowMsg(context, 'Name and MAC are required.');
      return;
    }
    try {
      await widget.api.post('/api/v1/lua/BlackWhiteList/addwirelessMacFilter', {'type': _type, 'name': _name.text.trim(), 'mac': _mac.text.trim()});
      final after = await _fetch(_type);
      final found = after.any((m) => str(m['mac']).toUpperCase() == _mac.text.trim().toUpperCase());
      if (mounted) setState(() => _items = after);
      advShowMsg(context, found ? 'Device added and verified.' : 'Router accepted the add, but the entry was not found on reload.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to add device.');
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final mac = str(item['mac']);
    final ok = await advConfirm(context, 'Remove device', 'Remove $mac from the ${_type == 'deny' ? 'blacklist' : 'whitelist'}?');
    if (!ok) return;
    try {
      await widget.api.post('/api/v1/lua/BlackWhiteList/deletewirelessMacFilter', {'type': _type, 'macList': [mac]});
      final after = await _fetch(_type);
      if (mounted) setState(() => _items = after);
      advShowMsg(context, 'Device removed and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to remove device.');
    }
  }

  Future<void> _toggleMode() async {
    final target = _type == 'deny' ? 'allow' : 'deny';
    final ok = await advConfirm(context, 'Switch filter mode', 'Switch to ${target == 'deny' ? 'blacklist' : 'whitelist'} mode? WiFi may drop briefly.');
    if (!ok) return;
    try {
      await widget.api.post('/api/v1/lua/BlackWhiteList/setMacBwList', {'type': target});
      await Future.delayed(const Duration(seconds: 2));
      final after = await _fetch(target);
      if (mounted) setState(() => _items = after);
      advShowMsg(context, 'Filter mode is now $_type on reload.');
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to switch filter mode. Reload to check the real mode.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'MAC filter',
  children: [
          advError(_error),
          SegmentedControl<String>(
            options: const [('deny', 'Blacklist'), ('allow', 'Whitelist')],
            value: _type,
            onChanged: (v) async {
              setState(() => _type = v);
              await _load();
            },
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                advField(_name, 'Device name'),
                advField(_mac, 'MAC address'),
                FilledButton(onPressed: _add, child: const Text('Add device')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _toggleMode, child: Text('Switch to ${_type == 'deny' ? 'whitelist' : 'blacklist'} mode')),
              ],
            ),
          ),
          if (_loading)
            skeletonCard()
          else if (_items.isEmpty)
            emptyState('No entries', 'This list is empty on the router.', 'Refresh', _load)
          else
            for (final m in _items)
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(m['name'], 'Unnamed'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(str(m['mac']), style: const TextStyle(color: appMuted)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline, color: appRed), onPressed: () => _delete(m)),
                  ],
                ),
              ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}

// ---------------- IPTV, IGMP, group transfer ----------------

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  bool _loading = true;
  String? _error;
  bool _iptvEnabled = false;
  final _vlan = TextEditingController();
  List<int> _ethPortsSel = [];
  List<int> _ethPortOptions = [2, 3, 4];
  List<String> _radio1List = [];
  List<String> _radio2List = [];
  bool _igmpEnabled = false;
  final _igmpMode = TextEditingController();
  final _igmpLan2Lan = TextEditingController();
  List<int> _group1 = [];
  List<int> _group2 = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vlan.dispose();
    _igmpMode.dispose();
    _igmpLan2Lan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final iptv = await widget.api.get('/api/v1/lua/IPTV/GetIptv');
      final d = dataOf(iptv);
      if (d is Map) {
        _iptvEnabled = d['enable'] == 'yes';
        if (d['vlanid'] != null) _vlan.text = d['vlanid'].toString();
        if (d['ethport'] is List) _ethPortsSel = (d['ethport'] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toList();
        if (d['radio1'] is List) _radio1List = (d['radio1'] as List).map((e) => e.toString()).toList();
        if (d['radio2'] is List) _radio2List = (d['radio2'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    try {
      final ports = await widget.api.get('/api/v1/lua/IPTV/IptvGetPort');
      final pd = dataOf(ports);
      final pl = pd is Map ? (pd['ports'] ?? pd['availablePorts'] ?? pd['list']) : null;
      if (pl is List) {
        final parsed = pl.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
        if (parsed.isNotEmpty) _ethPortOptions = parsed;
      }
    } catch (_) {}
    try {
      final ig = await widget.api.get('/api/v1/lua/IGMPSnooping/getIGMPSnooping');
      final d = dataOf(ig);
      if (d is Map) {
        _igmpEnabled = d['enable'] == 'yes' || d['enable'] == '1' || d['enable'] == 1 || d['enable'] == true;
        if (d['mode'] != null) _igmpMode.text = d['mode'].toString();
        if (d['lan2lan'] != null) _igmpLan2Lan.text = d['lan2lan'].toString();
      }
    } catch (_) {}
    try {
      final g = await widget.api.get('/api/v1/lua/GroupTransfer/GetUcigmpQuery');
      final d = dataOf(g);
      if (d is Map) {
        if (d['radio1'] is List) _group1 = (d['radio1'] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toList();
        if (d['radio2'] is List) _group2 = (d['radio2'] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveIptv() async {
    final vlan = int.tryParse(_vlan.text.trim());
    if (vlan == null || vlan < 1 || vlan > 4094) {
      advShowMsg(context, 'VLAN ID must be between 1 and 4094.');
      return;
    }
    try {
      await widget.api.post('/api/v1/lua/IPTV/SetIptv', {
        'enable': _iptvEnabled ? 'yes' : 'no',
        'vlanid': vlan,
        'ethport': _ethPortsSel,
        'radio1': _radio1List,
        'radio2': _radio2List,
      });
      await _load();
      advShowMsg(context, 'IPTV saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save IPTV.');
    }
  }

  Future<void> _saveIgmp() async {
    try {
      await widget.api.post('/api/v1/lua/IGMPSnooping/setIGMPSnooping', {
        'enable': _igmpEnabled ? 'yes' : 'no',
        'mode': _igmpMode.text.trim(),
        'lan2lan': _igmpLan2Lan.text.trim(),
      });
      await _load();
      advShowMsg(context, 'IGMP snooping saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save IGMP snooping.');
    }
  }

  Future<void> _saveGroup() async {
    try {
      await widget.api.post('/api/v1/lua/GroupTransfer/SetUcigmpQuery', {
        'radio1': _group1,
        'radio2': _group2,
      });
      await _load();
      advShowMsg(context, 'Group transfer saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save group transfer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            body: DetailScroll(
  title: 'IPTV and multicast',
  children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('IPTV'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _iptvEnabled, onChanged: (v) => setState(() => _iptvEnabled = v), title: const Text('IPTV enabled')),
                advField(_vlan, 'VLAN ID (1 to 4094)', keyboardType: TextInputType.number),
                const Align(alignment: Alignment.centerLeft, child: Text('Ethernet ports', style: TextStyle(fontWeight: FontWeight.w600))),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final port in {..._ethPortOptions, ..._ethPortsSel}.toList()..sort())
                      CustomChoiceChip(
                        label: 'LAN $port',
                        selected: _ethPortsSel.contains(port),
                        onTap: () => setState(() {
                          if (_ethPortsSel.contains(port)) {
                            _ethPortsSel.remove(port);
                          } else {
                            _ethPortsSel.add(port);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ChipInput(values: _radio1List, onChanged: (v) => setState(() => _radio1List = v), addLabel: 'Add a Radio 1 entry', hint: 'Entry value'),
                const SizedBox(height: 8),
                ChipInput(values: _radio2List, onChanged: (v) => setState(() => _radio2List = v), addLabel: 'Add a Radio 2 entry', hint: 'Entry value'),
                FilledButton(onPressed: _saveIptv, child: const Text('Save IPTV')),
              ],
            ),
          ),
          advSection('IGMP snooping'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _igmpEnabled, onChanged: (v) => setState(() => _igmpEnabled = v), title: const Text('IGMP snooping enabled')),
                advField(_igmpMode, 'Mode'),
                advField(_igmpLan2Lan, 'LAN to LAN'),
                const Text('No confirmed choice list yet, kept as text.', style: TextStyle(color: appMuted, fontSize: 12)),
                FilledButton(onPressed: _saveIgmp, child: const Text('Save IGMP snooping')),
              ],
            ),
          ),
          advSection('Multicast group transfer'),
          GlassCard(
            child: Column(
              children: [
                const Align(alignment: Alignment.centerLeft, child: Text('Radio 1 BSSIDs', style: TextStyle(fontWeight: FontWeight.w600))),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var b = 1; b <= 4; b++)
                      CustomChoiceChip(
                        label: 'BSSID $b',
                        selected: _group1.contains(b),
                        onTap: () => setState(() {
                          if (_group1.contains(b)) {
                            _group1.remove(b);
                          } else {
                            _group1.add(b);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('Radio 2 BSSIDs', style: TextStyle(fontWeight: FontWeight.w600))),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var b = 1; b <= 4; b++)
                      CustomChoiceChip(
                        label: 'BSSID $b',
                        selected: _group2.contains(b),
                        onTap: () => setState(() {
                          if (_group2.contains(b)) {
                            _group2.remove(b);
                          } else {
                            _group2.add(b);
                          }
                        }),
                      ),
                  ],
                ),
                FilledButton(onPressed: _saveGroup, child: const Text('Save group transfer')),
              ],
            ),
          ),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
        ],
      ),
    );
  }
}
