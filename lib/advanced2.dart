import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'advanced.dart';

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
      appBar: AppBar(title: const Text('Advanced router settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
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
  final _proto = TextEditingController(text: 'dhcp');
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
    _proto.dispose();
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
        _wanStatus = '${str(wan['proto'], '-').toUpperCase()} · ${str(wan['ip'], '-')}';
        final proto = str(wan['proto'], '').toLowerCase();
        _proto.text = proto.contains('pppoe') ? 'pppoe' : (proto.contains('static') ? 'static' : 'dhcp');
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
      advShowMsg(context, 'WPS set to $state and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to set WPS.');
    }
  }

  Future<void> _saveWan() async {
    final form = {
      'proto': _proto.text.trim(),
      'mtu': _mtu.text.trim(),
      'pppoeUser': _pppoeUser.text.trim(),
      'pppoePass': _pppoePass.text.trim(),
      'ipaddr': _wanIp.text.trim(),
      'netmask': _wanMask.text.trim(),
      'gateway': _wanGw.text.trim(),
      'dns': _wanDns.text.trim(),
    };
    final ok = await advConfirm(context, 'Change WAN', 'Apply WAN type ${form['proto']}? The internet connection will restart.');
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
      setState(() => _detect = d.toString());
      await _load();
    } catch (e) {
      setState(() => _detect = e is ApiException ? 'Detect did not return a result: ${e.message}' : 'Detect did not return a result.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('Static DNS'),
          GlassCard(
            child: Column(
              children: [
                advField(_dns1, 'Primary DNS'),
                advField(_dns2, 'Secondary DNS'),
                FilledButton(onPressed: _saveDns, child: const Text('Save DNS')),
              ],
            ),
          ),
          advSection('DMZ'),
          GlassCard(
            child: Column(
              children: [
                advField(_dmz, 'DMZ host IP (empty clears it)'),
                const Text('DMZ opens all ports to one device. Only use it for a device you trust.', style: TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
                const SizedBox(height: 10),
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
                Text('WPS: $_wps', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _setWps('on'), child: const Text('WPS on'))),
                    const SizedBox(width: 10),
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
                const SizedBox(height: 10),
                advField(_proto, 'Type: dhcp, pppoe, or static'),
                advField(_mtu, 'MTU', keyboardType: TextInputType.number),
                advField(_pppoeUser, 'PPPoE username'),
                advField(_pppoePass, 'PPPoE password'),
                advField(_wanIp, 'Static IP'),
                advField(_wanMask, 'Static netmask'),
                advField(_wanGw, 'Static gateway'),
                advField(_wanDns, 'Static DNS, space separated'),
                FilledButton(onPressed: _saveWan, child: const Text('Save WAN')),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _detectWan, child: const Text('Detect WAN')),
                if (_detect.isNotEmpty) ...[const SizedBox(height: 10), Text(_detect, style: const TextStyle(height: 1.45))],
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
    if (mode == null) {
      advShowMsg(context, 'IPv6 mode must be a number as returned by the router.');
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
      advShowMsg(context, 'IPv6 mode saved and reloaded.');
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
      appBar: AppBar(title: const Text('IPv6')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('Current IPv6'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode: ${_mode.isEmpty ? '-' : _mode}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final e in _entries.entries) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${e.key}: ${e.value}', style: const TextStyle(color: appMuted, fontSize: 12))),
                if (_entries.isEmpty) const Text('No IPv6 network data returned.', style: TextStyle(color: appMuted)),
              ],
            ),
          ),
          advSection('IPv6 mode'),
          GlassCard(
            child: Column(
              children: [
                TextField(controller: TextEditingController(text: _mode), onChanged: (v) => _mode = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mode number')),
                const SizedBox(height: 10),
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
                advField(_wanPrefixLen, 'Prefix length'),
                advField(_wanGw, 'Gateway'),
                advField(_wanDns1, 'Primary DNS'),
                advField(_wanDns2, 'Secondary DNS'),
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
                advField(_lanLease, 'Lease time'),
                advField(_lanDhcp, 'DHCPv6 server'),
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
  final _tz = TextEditingController(text: 'GMT+7:00');
  String _routerTime = '-';
  String _tzName = '-';
  bool _rebootEnabled = false;
  String _rebootDay = 'wed';
  final _rebootHour = TextEditingController(text: '03');
  final _rebootMinute = TextEditingController(text: '00');
  bool _sessionEnabled = true;
  final _sessionTime = TextEditingController(text: '300');
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
    _tz.dispose();
    _rebootHour.dispose();
    _rebootMinute.dispose();
    _sessionTime.dispose();
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
      if (n != null) _routerTime = DateTime.fromMillisecondsSinceEpoch(n.round() * 1000).toString();
    } catch (_) {}
    try {
      final tz = await widget.api.get('/api/v1/lua/Time/getTimezone');
      final td = dataOf(tz);
      if (td is Map) {
        _tzName = str(td['zonename'] ?? td['timezone'], '-');
        if (td['timezone'] != null) _tz.text = str(td['timezone']);
      }
    } catch (_) {}
    try {
      final rb = await widget.api.get('/api/v1/lua/SystemManage/getTimeReboot');
      final rd = dataOf(rb);
      if (rd is Map) {
        _rebootEnabled = rd['enable'] == '1' || rd['enable'] == 1;
        if (rd['week'] is List && (rd['week'] as List).isNotEmpty) _rebootDay = (rd['week'] as List).first.toString();
        if (rd['time'] is List && (rd['time'] as List).length >= 2) {
          _rebootHour.text = (rd['time'] as List)[0].toString();
          _rebootMinute.text = (rd['time'] as List)[1].toString();
        }
      }
    } catch (_) {}
    try {
      final st = await widget.api.get('/api/v1/lua/userinfo/getSessiontime');
      final sd = dataOf(st);
      if (sd is Map) {
        if (sd['enabled'] != null) _sessionEnabled = sd['enabled'] == true;
        if (sd['sessiontime'] != null) _sessionTime.text = sd['sessiontime'].toString();
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
      await widget.api.post('/api/v1/lua/Time/setTimezone', {'timezone': _tz.text.trim()});
      await _load();
      advShowMsg(context, 'Timezone saved and reloaded.');
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
      await widget.api.post('/api/v1/lua/SystemManage/setTimeReboot', {
        'enable': _rebootEnabled ? '1' : '0',
        'week': [_rebootDay],
        'time': [_rebootHour.text.trim(), _rebootMinute.text.trim()],
      });
      await _load();
      advShowMsg(context, 'Scheduled reboot saved and reloaded.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save scheduled reboot.');
    }
  }

  Future<void> _saveSession() async {
    final s = int.tryParse(_sessionTime.text.trim()) ?? 300;
    try {
      await widget.api.post('/api/v1/lua/userinfo/setSessionTime', {'enabled': _sessionEnabled, 'sessiontime': s});
      await _load();
      advShowMsg(context, 'Session timeout saved and reloaded.');
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
      advShowMsg(context, 'LED saved and reloaded. Mode is now $_ledAll.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to save LED.');
    }
  }

  Future<void> _setRouterLanguageEnglish() async {
    try {
      await widget.api.post('/api/v1/lua/Language/setLang', {'lang': 'en'});
      advShowMsg(context, 'Router language set to English. Other web panel languages are not sent to the stock backend, as in the web panel.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      advShowMsg(context, e is ApiException ? e.message : 'Failed to set router language.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('Firmware, read only'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version: $_firmware', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Free size: $_freeSize', style: const TextStyle(color: appMuted)),
                const SizedBox(height: 6),
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
                const SizedBox(height: 10),
                advField(_tz, 'Timezone, for example GMT+7:00'),
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
                DropdownButtonFormField<String>(
                  initialValue: _days.contains(_rebootDay) ? _rebootDay : 'wed',
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _rebootDay = v ?? 'wed'),
                  decoration: const InputDecoration(labelText: 'Day'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: advField(_rebootHour, 'Hour')),
                    const SizedBox(width: 10),
                    Expanded(child: advField(_rebootMinute, 'Minute')),
                  ],
                ),
                FilledButton(onPressed: _saveReboot, child: const Text('Save scheduled reboot')),
              ],
            ),
          ),
          advSection('Session timeout and language'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _sessionEnabled, onChanged: (v) => setState(() => _sessionEnabled = v), title: const Text('Session timeout enabled')),
                advField(_sessionTime, 'Session timeout seconds', keyboardType: TextInputType.number),
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
                DropdownButtonFormField<String>(
                  initialValue: ['restore', 'close', 'sched'].contains(_ledAll) ? _ledAll : 'restore',
                  items: const [
                    DropdownMenuItem(value: 'restore', child: Text('Normal')),
                    DropdownMenuItem(value: 'close', child: Text('LED off')),
                    DropdownMenuItem(value: 'sched', child: Text('Schedule')),
                  ],
                  onChanged: (v) => setState(() => _ledAll = v ?? 'restore'),
                  decoration: const InputDecoration(labelText: 'LED mode'),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _ledSchedules.length; i++) _ledScheduleCard(i),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _ledSchedules.add({'enable': true, 'week': <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'time': <String>['22:00', '06:00']})),
                  icon: const Icon(Icons.add),
                  label: const Text('Add LED schedule'),
                ),
                const SizedBox(height: 8),
                const Text('This sends the real schedule list from the web panel, not an empty list. The old empty list version never saved a schedule.', style: TextStyle(color: appMuted, fontSize: 12, height: 1.45)),
                const SizedBox(height: 10),
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
    final start = TextEditingController(text: time[0]);
    final end = TextEditingController(text: time[1]);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: appBorder), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Schedule ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
              Switch(
                value: s['enable'] == true,
                onChanged: (v) => setState(() => _ledSchedules[i]['enable'] = v),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: appRed), onPressed: () => setState(() => _ledSchedules.removeAt(i))),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final d in _days)
                FilterChip(
                  label: Text(d),
                  selected: week.contains(d),
                  onSelected: (v) => setState(() {
                    final w = List<String>.from(week);
                    if (v) {
                      if (!w.contains(d)) w.add(d);
                    } else {
                      w.remove(d);
                    }
                    _ledSchedules[i]['week'] = w;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: start, onChanged: (v) => setState(() => _ledSchedules[i]['time'] = [v, end.text]), decoration: const InputDecoration(labelText: 'Start HH:MM'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: end, onChanged: (v) => setState(() => _ledSchedules[i]['time'] = [start.text, v]), decoration: const InputDecoration(labelText: 'End HH:MM'))),
            ],
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
      appBar: AppBar(title: const Text('MAC filter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                          Text(str(m['name'], 'Unnamed'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
  final _ethPorts = TextEditingController();
  final _radio1 = TextEditingController();
  final _radio2 = TextEditingController();
  bool _igmpEnabled = false;
  final _igmpMode = TextEditingController();
  final _igmpLan2Lan = TextEditingController();
  final _groupRadio1 = TextEditingController();
  final _groupRadio2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vlan.dispose();
    _ethPorts.dispose();
    _radio1.dispose();
    _radio2.dispose();
    _igmpMode.dispose();
    _igmpLan2Lan.dispose();
    _groupRadio1.dispose();
    _groupRadio2.dispose();
    super.dispose();
  }

  List<dynamic> _commaToList(String s) {
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<dynamic> _commaToInts(String s) {
    return _commaToList(s).map((e) => int.tryParse(e) ?? e).toList();
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
        if (d['ethport'] is List) _ethPorts.text = (d['ethport'] as List).join(', ');
        if (d['radio1'] is List) _radio1.text = (d['radio1'] as List).join(', ');
        if (d['radio2'] is List) _radio2.text = (d['radio2'] as List).join(', ');
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
        if (d['radio1'] is List) _groupRadio1.text = (d['radio1'] as List).join(', ');
        if (d['radio2'] is List) _groupRadio2.text = (d['radio2'] as List).join(', ');
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveIptv() async {
    try {
      await widget.api.post('/api/v1/lua/IPTV/SetIptv', {
        'enable': _iptvEnabled ? 'yes' : 'no',
        'vlanid': int.tryParse(_vlan.text.trim()) ?? 0,
        'ethport': _commaToInts(_ethPorts.text),
        'radio1': _commaToList(_radio1.text),
        'radio2': _commaToList(_radio2.text),
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
        'radio1': _commaToList(_groupRadio1.text),
        'radio2': _commaToList(_groupRadio2.text),
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
      appBar: AppBar(title: const Text('IPTV and multicast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          advError(_error),
          if (_loading) skeletonCard(),
          advSection('IPTV'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(value: _iptvEnabled, onChanged: (v) => setState(() => _iptvEnabled = v), title: const Text('IPTV enabled')),
                advField(_vlan, 'VLAN id', keyboardType: TextInputType.number),
                advField(_ethPorts, 'Ethernet ports, comma separated'),
                advField(_radio1, 'Radio 1, comma separated'),
                advField(_radio2, 'Radio 2, comma separated'),
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
                FilledButton(onPressed: _saveIgmp, child: const Text('Save IGMP snooping')),
              ],
            ),
          ),
          advSection('Multicast group transfer'),
          GlassCard(
            child: Column(
              children: [
                advField(_groupRadio1, 'Radio 1 groups, comma separated'),
                advField(_groupRadio2, 'Radio 2 groups, comma separated'),
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
