import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'theme.dart';
import 'local_store.dart';
import 'advanced2.dart';
import 'local_screen.dart';
import 'labels.dart';
import 'choice_widgets.dart';

void main() {
  runApp(const MaApp());
}

const Color reyeeBlue = Color(0xFF2F7CF6);
const Color reyeeCyan = Color(0xFF00C2FF);
const Color reyeeBg = Color(0xFFEDF3FA);
const Color reyeeInk = Color(0xFF0F172A);
const Color reyeeMuted = Color(0xFF64748B);

class MaApp extends StatelessWidget {
  const MaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MA3063 Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: reyeeBlue, brightness: Brightness.light),
        scaffoldBackgroundColor: reyeeBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: reyeeInk,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFEAF1F8),
          indicatorColor: const Color(0xFFDCE9FD),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF173A6B));
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B));
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const IconThemeData(color: Color(0xFF173A6B), size: 24);
            return const IconThemeData(color: Color(0xFF64748B), size: 24);
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: reyeeBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

Widget reyeeCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(padding: padding, child: child),
  );
}

Widget sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: reyeeMuted)),
  );
}

Widget infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: reyeeMuted))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, color: reyeeInk))),
      ],
    ),
  );
}

Widget errorBanner(String? message) {
  if (message == null || message.isEmpty) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFEECEB), borderRadius: BorderRadius.circular(12)),
    child: Text(message, style: const TextStyle(color: Color(0xFFB42318))),
  );
}

void showMsg(BuildContext context, String text) {
  // Never crash the app if the screen was left while a router call finished.
  try {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  } catch (_) {}
}

Future<bool> confirmDialog(BuildContext context, String title, String body) async {
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

// ---------------- Login ----------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ip = TextEditingController();
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController();
  bool _showPass = false;
  bool _busy = false;
  bool _remember = true;
  String? _error;
  String? _scannedInfo;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ip.text = p.getString('router_ip') ?? '';
      _user.text = p.getString('router_user') ?? 'admin';
    });
  }

  @override
  void dispose() {
    _ip.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final ip = _ip.text.trim();
    final user = _user.text.trim();
    final pass = _pass.text;
    if (ip.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Fill in router IP, username and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = RouterApi(ip);
    try {
      await api.login(user, pass);
      final p = await SharedPreferences.getInstance();
      if (_remember) {
        await p.setString('router_ip', ip);
        await p.setString('router_user', user);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(api: api, routerIp: ip)),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Login failed. Check the router IP and network.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanQr() async {
    if (_busy) return;
    setState(() => _error = null);
    PermissionStatus status;
    try {
      status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Camera permission could not be requested. Log in manually instead.');
      }
      return;
    }
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _error = status.isPermanentlyDenied
            ? 'Camera permission was denied. Allow camera access in Android Settings, Apps, MA3063 Control, Permissions, to scan a QR code, or log in manually.'
            : 'Camera permission was denied. Allow camera access to scan a QR code, or log in manually.';
      });
      return;
    }
    if (!mounted) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || raw.isEmpty) return;
    await _claimQr(raw);
  }

  Future<void> _claimQr(String raw) async {
    QrPair pair;
    try {
      pair = parseQrPayload(raw);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ip.text = pair.ip;
      _scannedInfo = 'Scanned router: ${pair.hostname ?? 'RG-MA3063'} (${pair.model ?? 'RG-MA3063'}) at ${pair.ip}. Pairing code valid until the web panel expiry, 5 minutes from generation.';
    });
    final api = RouterApi(pair.ip);
    try {
      await api.claimPair(pair.code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('router_ip', pair.ip);
      if (pair.hostname != null) await prefs.setString('router_hostname', pair.hostname!);
      if (pair.model != null) await prefs.setString('router_model', pair.model!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(api: api, routerIp: pair.ip)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = '${e.message} The IP from the QR is already filled in above, so you can log in manually.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Pairing failed. The IP from the QR is already filled in above, so you can log in manually.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [reyeeBlue, reyeeCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                child: const Icon(Icons.router_outlined, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text('MA3063 Control', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: reyeeInk)),
              const Text('Ruijie RG-MA3063, directly. No cloud account.', style: TextStyle(color: reyeeMuted, fontSize: 15)),
              const SizedBox(height: 24),
              errorBanner(_error),
              const Text('Router IP', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(controller: _ip, keyboardType: TextInputType.text, decoration: const InputDecoration(hintText: '192.168.1.1')),
              const SizedBox(height: 14),
              const Text('Username', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(controller: _user, decoration: const InputDecoration(hintText: 'admin')),
              const SizedBox(height: 14),
              const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _pass,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  hintText: 'Router admin password',
                  suffixIcon: IconButton(
                    icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              CheckboxListTile(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? true),
                title: const Text('Remember router IP and username'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _login,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Connect to router'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _scanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR from web panel'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              if (_scannedInfo != null) ...[
                const SizedBox(height: 12),
                reyeeCard(child: Text(_scannedInfo!, style: const TextStyle(color: reyeeMuted, height: 1.45))),
              ],
              const SizedBox(height: 16),
              reyeeCard(
                child: const Text(
                  'This app connects straight to your router over HTTP, the same login the web panel uses. Use it only on your home LAN. Never expose the router web port to the public internet.\n\nYour password is not stored on this phone. Only the router IP and username are remembered, and only if you tick the box above.',
                  style: TextStyle(color: reyeeMuted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- QR scan ----------------

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    _controller.stop();
    if (mounted) Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan router QR'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                if (mounted) setState(() => _torchOn = !_torchOn);
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Camera could not start. Check camera permission and try again, or log in manually. ($error)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: reyeeMuted),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Point the camera at the QR code on the Hubungkan Aplikasi page in the web panel. The code is valid for 5 minutes and can be used only once.',
              textAlign: TextAlign.center,
              style: TextStyle(color: reyeeMuted, height: 1.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Main shell ----------------

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api, required this.routerIp});
  final RouterApi api;
  final String routerIp;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _sessionExpired() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    showMsg(context, 'Session ended. Please log in again.');
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(api: widget.api, onSessionExpired: _sessionExpired),
      DevicesScreen(api: widget.api, onSessionExpired: _sessionExpired),
      WifiScreen(api: widget.api, onSessionExpired: _sessionExpired),
      ToolsScreen(api: widget.api, onSessionExpired: _sessionExpired),
      SettingsScreen(api: widget.api, routerIp: widget.routerIp, onSessionExpired: _sessionExpired),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('MA3063 Control')),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEAF1F8),
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFFEAF1F8),
          indicatorColor: const Color(0xFFDCE9FD),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.devices_outlined), selectedIcon: Icon(Icons.devices), label: 'Devices'),
            NavigationDestination(icon: Icon(Icons.wifi_outlined), selectedIcon: Icon(Icons.wifi), label: 'WiFi'),
            NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'Tools'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ---------------- Home ----------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  String _hostname = '-';
  String _model = 'RG-MA3063';
  String _firmware = '-';
  String _wanIp = '-';
  String _wanProto = '-';
  String _lanIp = '-';
  String _clientCount = '-';
  String _meshCount = '-';
  String _uptime = '-';
  String _cpu = '-';
  String _mem = '-';
  String _loadAvg = '-';
  String _cpuTemp = '-';
  String _connector = 'Checking...';
  List<Map<String, String>> _ports = [];
  List<Map<String, String>> _ssids = [];
  List<Map<String, String>> _radios = [];
  List<dynamic> _topoChildren = [];
  bool _stale = false;
  String _staleTime = '';
  List<double> _cpuSamples = [];

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
    // Each call is guarded on its own, like Promise.allSettled in the eweb:
    // one failing stock endpoint must not blank the whole home screen.
    try {
      await _loadConnector();
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/Hostname/getHostnamePlain');
      final d = dataOf(r);
      if (d is Map && d['hostname'] != null) _hostname = str(d['hostname']);
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/apinfo/sysinfo');
      final d = dataOf(r);
      if (d is Map) {
        if (d['model'] != null) _model = str(d['model']);
        if (d['software_version'] != null) _firmware = str(d['software_version']);
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/dev/getUserCount');
      final d = dataOf(r);
      if (d is Map && d['count'] != null) {
        _clientCount = str(d['count']);
      } else if (d is num) {
        _clientCount = '$d';
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/network/info');
      final d = dataOf(r);
      if (d is Map) {
        final wan = d['wan'];
        final lan = d['lan'];
        Map? wanMap;
        Map? lanMap;
        if (wan is List && wan.isNotEmpty) wanMap = wan.first as Map?;
        if (wan is Map) wanMap = wan;
        if (lan is List && lan.isNotEmpty) lanMap = lan.first as Map?;
        if (lan is Map) lanMap = lan;
        if (wanMap != null) {
          if (wanMap['ipaddr'] != null) _wanIp = str(wanMap['ipaddr']);
          if (wanMap['proto'] != null) _wanProto = wanProtoLabel(wanMap['proto']);
        }
        if (lanMap != null && lanMap['ipaddr'] != null) _lanIp = str(lanMap['ipaddr']);
        if (_wanIp == '-' && d['wanIp'] != null) _wanIp = str(d['wanIp']);
        if (_lanIp == '-' && d['lanIp'] != null) _lanIp = str(d['lanIp']);
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/network/wanget');
      final d = dataOf(r);
      if (d is Map && d['wan'] is Map) {
        final w = d['wan'] as Map;
        if (w['ip'] != null) _wanIp = str(w['ip']);
        if (w['proto'] != null) _wanProto = wanProtoLabel(w['proto']);
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/WiFi/getWifiPlain');
      final d = dataOf(r);
      if (d is Map) {
        final list = listOf(d['ssidList'] ?? d['list']);
        _ssids = list.whereType<Map>().map((m) {
          return {
            'name': str(m['ssidName'], 'Unnamed'),
            'radio': str(m['relatedRadio']),
            'on': (m['enable'] == 'yes' || m['enable'] == 'true' || m['enable'] == true) ? 'On' : 'Off',
          };
        }).toList();
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/Radio/getRadioList');
      final d = dataOf(r);
      if (d is Map) {
        final list = listOf(d['radioList']);
        _radios = list.whereType<Map>().map((m) {
          return {
            'type': str(m['type']),
            'channel': str(m['channel']),
            'width': str(m['bandWidth']),
            'on': (m['enable'] == true || m['enable'] == 'true' || m['enable'] == '1') ? 'On' : 'Off',
          };
        }).toList();
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/mesh/MeshGetTopo');
      final d = dataOf(r);
      if (d is Map) {
        _meshCount = '${meshNodeCount(d['childList'])}';
        final cl = d['childList'];
        if (cl is List) {
          _topoChildren = cl;
        } else if (cl is Map) {
          _topoChildren = cl.values.toList();
        }
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/v1/lua/Portinfo/list');
      final d = dataOf(r);
      if (d is Map) {
        final list = listOf(d['List'] ?? d['list']);
        final rows = list.whereType<Map>().toList();
        rows.sort((a, b) => (numOrNull(a['portId']) ?? 0).compareTo(numOrNull(b['portId']) ?? 0));
        _ports = rows.map((m) {
          final pid = (numOrNull(m['portId']) ?? 0).round();
          final isWan = m['isWan'] == true || m['name'] == 'WAN' || pid == 1;
          final up = m['status'] == 'on' || m['link'] == 1 || m['link'] == '1';
          return {
            'label': isWan ? 'WAN (Port 1)' : 'LAN (Port $pid)',
            'status': up ? '${str(m['speed'], '1000')} Mbps' : 'Disconnected',
          };
        }).toList();
      }
    } catch (_) {}
    try {
      final r = await widget.api.get('/api/tempdata.lua');
      final zones = _zonesOf(r);
      if (zones.isNotEmpty) {
        final cpu = zones.firstWhere((z) => (z['name'] ?? '').toLowerCase().contains('cpu'), orElse: () => zones.first);
        _cpuTemp = formatTemp(cpu['temp']);
      }
      final d = dataOf(r);
      if (d is Map && d['uptime'] != null) _uptime = formatDuration(d['uptime']);
    } catch (_) {
      try {
        final r = await widget.api.get('/api/temp.lua');
        final zones = _zonesOf(r);
        if (zones.isNotEmpty) _cpuTemp = formatTemp(zones.first['temp']);
      } catch (_) {}
    }
    if (_hostname == '-' && _wanIp == '-' && _clientCount == '-') {
      final cache = await LocalStore.homeCache();
      if (cache.$1 != null) {
        _stale = true;
        _staleTime = cache.$2 == null ? '' : formatDisplayDateTimeMs(cache.$2!);
        final c = cache.$1!;
        if (c['hostname'] != null) _hostname = c['hostname'].toString();
        if (c['wanIp'] != null) _wanIp = c['wanIp'].toString();
        if (c['clients'] != null) _clientCount = c['clients'].toString();
        if (c['mesh'] != null) _meshCount = c['mesh'].toString();
      }
    } else {
      _stale = false;
      await LocalStore.saveHomeCache({
        'hostname': _hostname,
        'wanIp': _wanIp,
        'clients': _clientCount,
        'mesh': _meshCount,
        'cpu': _cpu,
        'mem': _mem,
        'temp': _cpuTemp,
      });
    }
    final samples = await LocalStore.samples();
    _cpuSamples = samples.map((e) => e['cpu']).whereType<num>().map((n) => n.toDouble()).toList();
    if (!mounted) return;
    setState(() => _loading = false);
    // CPU is measured after the other calls plus a 2 second pause, exactly
    // like eweb v133, so the measurement is not polluted by this page load.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final r = await widget.api.get('/api/v1/lua/Runtime/getRuntimePlain');
      final d = dataOf(r);
      if (d is Map) {
        setState(() {
          if (d['cpuusage'] != null) _cpu = '${str(d['cpuusage'])}%';
          if (d['memusage'] != null) _mem = '${str(d['memusage'])}%';
          if (d['load1'] != null) _loadAvg = str(d['load1']);
          if (d['uptime'] != null) _uptime = formatDuration(d['uptime']);
        });
        final cpuN = numOrNull(d['cpuusage']);
        final memN = numOrNull(d['memusage']);
        double? tempN;
        final tempText = _cpuTemp.replaceAll(' °C', '');
        tempN = double.tryParse(tempText);
        await LocalStore.addSample(cpu: cpuN, mem: memN, temp: tempN);
        if (cpuN != null && cpuN > 85) await LocalStore.addAlert('CPU usage observed at ${cpuN.toStringAsFixed(0)}%, above the 85% local threshold.');
        if (tempN != null && tempN > 80) await LocalStore.addAlert('CPU temperature observed at ${tempN.toStringAsFixed(1)} C, above the 80 C local threshold.');
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _zonesOf(dynamic json) {
    if (json is Map) {
      final zones = json['zones'];
      if (zones is List) return zones.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      final d = dataOf(json);
      if (d is Map && d['zones'] is List) {
        return (d['zones'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    }
    return const [];
  }

  Future<void> _loadConnector() async {
    try {
      final r = await widget.api.get('/api/maapp.lua?action=ping');
      final d = dataOf(r);
      if (d is Map && d['connector'] == 'maapp') {
        _connector = 'Installed · v${str(d['version'], '1.0.0')}';
        if (d['uptime'] != null) _uptime = formatDuration(d['uptime']);
        return;
      }
      _connector = 'Not installed (app still works)';
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      _connector = 'Not installed (app still works)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          errorBanner(_error),
          if (_stale)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16)),
              child: Text('Showing the last cached snapshot from $_staleTime because the live router did not answer. Tap Refresh to retry.', style: const TextStyle(color: Color(0xFF92400E))),
            ),
          if (_loading)
            skeletonCard()
          else
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [reyeeBlue, reyeeCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.router_outlined, color: Colors.white, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_hostname, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text('$_model', style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999)),
                          child: const Text('Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_clientCount, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
                    const Text('devices online', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Text('WAN $_wanIp · $_wanProto', style: const TextStyle(color: Colors.white)),
                    Text('LAN $_lanIp · Uptime $_uptime', style: const TextStyle(color: Colors.white70)),
                    Text('Firmware $_firmware · Connector $_connector', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: reyeeCard(
                  child: Column(
                    children: [
                      RingGauge(value: double.tryParse(_cpu.replaceAll('%', '')) ?? 0, label: 'CPU usage'),
                      Text(_cpu, style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: reyeeCard(
                  child: Column(
                    children: [
                      RingGauge(value: double.tryParse(_mem.replaceAll('%', '')) ?? 0, label: 'Memory', color: reyeeCyan),
                      Text(_mem, style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: _stat('Mesh nodes', _meshCount, Icons.hub_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _stat('CPU temp', _cpuTemp, Icons.thermostat_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _stat('Load 1m', _loadAvg, Icons.show_chart_outlined)),
            ],
          ),
          sectionTitle('CPU trend, sampled while the app is open'),
          reyeeCard(child: Sparkline(values: _cpuSamples)),
          sectionTitle('Topology'),
          if (_topoChildren.isEmpty)
            reyeeCard(child: Text(_loading ? 'Loading...' : 'No mesh child nodes. This router is the only node.'))
          else
            reyeeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.router_outlined, color: reyeeBlue),
                      SizedBox(width: 8),
                      Expanded(child: Text('Main router', style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final child in _topoChildren) _topoRow(child, 0),
                  const SizedBox(height: 8),
                  const Text('Lines are connections from the topology data only. No signal values are shown because the router does not report mesh signal strength.', style: TextStyle(color: reyeeMuted, fontSize: 12, height: 1.45)),
                ],
              ),
            ),
          sectionTitle('WiFi networks'),
          if (_ssids.isEmpty)
            reyeeCard(child: Text(_loading ? 'Loading...' : 'No WiFi networks returned by the router.'))
          else
            for (final s in _ssids)
              reyeeCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, color: reyeeBlue),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(s['on'] ?? '-', style: const TextStyle(color: reyeeMuted)),
                  ],
                ),
              ),
          sectionTitle('Radios'),
          if (_radios.isEmpty)
            reyeeCard(child: Text(_loading ? 'Loading...' : 'No radio data returned.'))
          else
            for (final r in _radios)
              reyeeCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('${radioTypeLabel(r['type'], null)} · ${channelLabel(r['channel'] ?? 'auto', is5g: (r['type'] ?? '').toString().contains('5'))} · ${bandwidthLabel(r['width'] ?? 'auto', is5g: (r['type'] ?? '').toString().contains('5'))}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(r['on'] ?? '-', style: const TextStyle(color: reyeeMuted)),
                  ],
                ),
              ),
          sectionTitle('Ports'),
          if (_ports.isEmpty)
            reyeeCard(child: Text(_loading ? 'Loading...' : 'No port data returned.'))
          else
            for (final p in _ports)
              reyeeCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(p['label'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(p['status'] ?? '-', style: const TextStyle(color: reyeeMuted)),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          const SizedBox(height: 8),
          const Text('No auto refresh. Tap Refresh to update, the same rule as the web panel.', style: TextStyle(color: reyeeMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _topoRow(dynamic node, int level) {
    List<dynamic> kids = const [];
    String name = 'Mesh node';
    if (node is Map) {
      name = str(node['hostName'] ?? node['hostname'] ?? node['name'] ?? node['mac'], 'Mesh node');
      final c = node['childList'];
      if (c is List) kids = c;
      if (c is Map) kids = c.values.toList();
    }
    return Padding(
      padding: EdgeInsets.only(left: level * 16, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: reyeeCyan),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          for (final k in kids) _topoRow(k, level + 1),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return reyeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: reyeeBlue, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: reyeeMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------- Devices ----------------

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  List<Map<String, dynamic>> _clients = [];
  Map<String, dynamic> _nicks = {};
  Map<String, dynamic> _hist = {};

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
      final res = await widget.api.get('/api/v1/lua/OnlineUsers/mainData_GetStaList');
      var list = listOf(dataOf(res) is Map ? (dataOf(res) as Map)['list'] : dataOf(res));
      var clients = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      try {
        final full = await widget.api.post('/api/v1/lua/OnlineUsers/sta_list', {'page': 1, 'size': 100});
        final fullList = listOf(dataOf(full) is Map ? (dataOf(full) as Map)['list'] : const []);
        final byMac = <String, Map<String, dynamic>>{};
        for (final item in fullList.whereType<Map>()) {
          if (item['mac'] != null) byMac[item['mac'].toString().toUpperCase()] = Map<String, dynamic>.from(item);
        }
        clients = clients.map((c) {
          final m = byMac[(c['mac'] ?? '').toString().toUpperCase()];
          if (m == null) return c;
          final merged = {...m, ...c};
          merged['hostName'] = c['hostName'] ?? m['hostName'];
          merged['mac'] = c['mac'];
          return merged;
        }).toList();
      } catch (_) {}
      for (final c in clients) {
        final mac = (c['mac'] ?? '').toString();
        if (mac.isNotEmpty) {
          await LocalStore.recordSeen(mac, str(c['hostName'] ?? c['deviceName'], 'Unknown device'));
        }
      }
      final nicks = await LocalStore.nicknames();
      final hist = await LocalStore.history();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _nicks = nicks;
        _hist = hist;
      });
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to load devices.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setBlock(Map<String, dynamic> c, bool block) async {
    final idx = c['idx'];
    if (idx == null) {
      showMsg(context, 'This device has no router index, so it cannot be blocked from here.');
      return;
    }
    final ok = await confirmDialog(
      context,
      block ? 'Block internet' : 'Allow internet',
      block
          ? 'Block ${c['hostName'] ?? c['mac']} from the internet?'
          : 'Allow ${c['hostName'] ?? c['mac']} back on the internet?',
    );
    if (!ok) return;
    try {
      // Stock: internetaccess 0 means blocked, 2 means allowed.
      await widget.api.post('/api/v1/lua/OnlineUsers/set_sta_list', {'idx': idx, 'internetaccess': block ? 0 : 2});
      await _load();
      // Verify, do not trust the success message alone.
      final after = _clients.firstWhere(
        (x) => (x['mac'] ?? '').toString().toUpperCase() == (c['mac'] ?? '').toString().toUpperCase(),
        orElse: () => {},
      );
      if (after.isNotEmpty) {
        final nowBlocked = after['internetaccess'].toString() == '0';
        if (nowBlocked != block) {
          showMsg(context, 'Router did not apply that change. It still shows ${nowBlocked ? 'blocked' : 'allowed'}.');
          return;
        }
      }
      showMsg(context, block ? 'Device blocked.' : 'Device allowed.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Failed to change device access.');
    }
  }

  Future<void> _bandwidth(Map<String, dynamic> c) async {
    final idx = c['idx'];
    if (idx == null) {
      showMsg(context, 'This device has no router index, so its limit cannot be changed from here.');
      return;
    }
    var up = TextEditingController(text: _toMbps(c['usbandwidth']));
    var down = TextEditingController(text: _toMbps(c['dsbandwidth']));
    try {
      final res = await widget.api.post('/api/v1/lua/OnlineUsers/getStaItem', {'idx': idx});
      final item = dataOf(res);
      final m = item is Map ? (item['staItem'] ?? item) : null;
      if (m is Map) {
        if (m['usbandwidth'] != null) up.text = _toMbps(m['usbandwidth']);
        if (m['dsbandwidth'] != null) down.text = _toMbps(m['dsbandwidth']);
      }
    } catch (_) {}
    if (!mounted) return;
    var upMbps = int.tryParse(up.text) ?? 0;
    var downMbps = int.tryParse(down.text) ?? 0;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Bandwidth limit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload', style: TextStyle(fontWeight: FontWeight.w600)),
                LimitSlider(mbps: upMbps, onChanged: (v) => setD(() => upMbps = v)),
                const SizedBox(height: 16),
                const Text('Download', style: TextStyle(fontWeight: FontWeight.w600)),
                LimitSlider(mbps: downMbps, onChanged: (v) => setD(() => downMbps = v)),
              ],
            ),
          ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
        ),
      ),
    );
    if (save != true) return;
    final upKbps = upMbps * 1000;
    final downKbps = downMbps * 1000;
    try {
      await widget.api.post('/api/v1/lua/OnlineUsers/setStaItem', {'idx': idx, 'usbandwidth': upKbps, 'dsbandwidth': downKbps});
      await _load();
      showMsg(context, 'Bandwidth limit saved.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Failed to save limit.');
    } finally {
      up.dispose();
      down.dispose();
    }
  }

  String _toMbps(dynamic kbps) {
    final n = numOrNull(kbps);
    if (n == null) return '0';
    final v = n / 1000;
    return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final shown = _clients.where((c) {
      if (q.isEmpty) return true;
      return (c['hostName'] ?? '').toString().toLowerCase().contains(q) ||
          (c['mac'] ?? '').toString().toLowerCase().contains(q) ||
          (c['ip'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          errorBanner(_error),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, MAC or IP'),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (shown.isEmpty)
            reyeeCard(child: const Text('No online devices found.'))
          else
            for (final c in shown) _deviceCard(c),
        ],
      ),
    );
  }

  String _localName(Map<String, dynamic> c) {
    final mac = (c['mac'] ?? '').toString().toUpperCase();
    final n = _nicks[mac];
    if (n is Map && n['name'] != null && n['name'].toString().isNotEmpty) return n['name'].toString();
    return str(c['hostName'] ?? c['deviceName'], 'Unknown device');
  }

  Future<void> _deviceSheet(Map<String, dynamic> c) async {
    final mac = (c['mac'] ?? '').toString().toUpperCase();
    final n = _nicks[mac] is Map ? Map<String, dynamic>.from(_nicks[mac] as Map) : <String, dynamic>{};
    final h = _hist[mac] is Map ? Map<String, dynamic>.from(_hist[mac] as Map) : <String, dynamic>{};
    final nameC = TextEditingController(text: (n['name'] ?? '').toString());
    final roomC = TextEditingController(text: (n['room'] ?? '').toString());
    final groupC = TextEditingController(text: (n['group'] ?? '').toString());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_localName(c), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('IP ${str(c['ip'])} · MAC ${str(c['mac'])}', style: const TextStyle(color: reyeeMuted)),
              if (c['rssi'] != null) Text('Signal ${signalLabel(c['rssi'])}', style: const TextStyle(color: reyeeMuted)),
              if (c['ssid'] != null) Text('WiFi ${str(c['ssid'])}', style: const TextStyle(color: reyeeMuted)),
              const SizedBox(height: 6),
              Text('Local history: first seen ${h['firstSeen'] is num ? formatDisplayDateTimeMs((h['firstSeen'] as num).toInt()) : '-'}, sessions ${str(h['sessions'], '0')}.', style: const TextStyle(color: reyeeMuted, fontSize: 12, height: 1.45)),
              const SizedBox(height: 12),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Local nickname (local only, not saved on the router)')),
              const SizedBox(height: 10),
              TextField(controller: roomC, decoration: const InputDecoration(labelText: 'Room (local only)')),
              const SizedBox(height: 10),
              TextField(controller: groupC, decoration: const InputDecoration(labelText: 'Group (local only)')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await LocalStore.setNickname(mac, name: nameC.text.trim(), room: roomC.text.trim(), group: groupC.text.trim());
                  final nicks = await LocalStore.nicknames();
                  if (mounted) setState(() => _nicks = nicks);
                  if (ctx.mounted) Navigator.pop(ctx);
                  showMsg(context, 'Local nickname saved on this phone only.');
                },
                child: const Text('Save local nickname'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _bandwidth(c), child: const Text('Limit'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(onPressed: () => _setBlock(c, c['internetaccess'].toString() != '0'), child: Text(c['internetaccess'].toString() == '0' ? 'Allow' : 'Block'))),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceCard(Map<String, dynamic> c) {
    final blocked = c['internetaccess'].toString() == '0';
    final name = _localName(c);
    return InkWell(
      onTap: () => _deviceSheet(c),
      borderRadius: BorderRadius.circular(26),
      child: reyeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(blocked ? Icons.block_outlined : Icons.devices_outlined, color: blocked ? Colors.red : reyeeBlue),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: blocked ? const Color(0xFFFEECEB) : const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(20)),
                child: Text(blocked ? 'Blocked' : 'Online', style: TextStyle(color: blocked ? const Color(0xFFB42318) : const Color(0xFF137333), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          infoRow('MAC', str(c['mac'])),
          if (c['ip'] != null) infoRow('IP', str(c['ip'])),
          if (c['ssid'] != null) infoRow('WiFi', str(c['ssid'])),
          if (c['rssi'] != null) infoRow('Signal', signalLabel(c['rssi'])),
          if (c['onlinetime'] != null) infoRow('Online time', formatDuration(c['onlinetime'])),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _bandwidth(c), child: const Text('Limit'))),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _setBlock(c, !blocked),
                  child: Text(blocked ? 'Allow' : 'Block'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ---------------- WiFi ----------------

class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ssids = [];

  static const _groupForWlan = {'1': 1, '2': 1, '7': 2, '8': 2, '3': 3, '4': 3, '5': 4, '6': 4, '9': 5, '10': 5};
  static const _encOptions = ['open', 'wpa-psk', 'wpa2-psk', 'wpa_wpa2-psk', 'wpa3-sae', 'wpa3_wpa2-sae'];

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
      final res = await widget.api.get('/api/v1/lua/WiFi/getWifiPlain');
      final d = dataOf(res);
      var list = const <dynamic>[];
      if (d is Map) list = listOf(d['ssidList'] ?? d['list']);
      if (!mounted) return;
      setState(() => _ssids = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList());
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to load WiFi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> ssid) async {
    final name = TextEditingController(text: str(ssid['ssidName'], ''));
    final pass = TextEditingController(text: str(ssid['password'], ''));
    var enabled = ssid['enable'] == 'yes' || ssid['enable'] == 'true' || ssid['enable'] == true;
    var hidden = ssid['ishidden'] == 'true' || ssid['hide'] == 1;
    var enc = str(ssid['encryptionMode'], authToEncryption(ssid['auth']));
    if (!_encOptions.contains(enc)) enc = 'wpa_wpa2-psk';
    var showPass = false;
    var saving = false;
    String? dialogError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Edit ${str(ssid['ssidName'], 'WiFi')}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dialogError != null) ...[
                  Text(dialogError!, style: const TextStyle(color: Color(0xFFB42318))),
                  const SizedBox(height: 10),
                ],
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Network name')),
                const SizedBox(height: 10),
                choiceRow('Encryption', Encryption.fromCode(enc).label, null, () async {
                  final picked = await showDialog<String>(
                    context: ctx,
                    builder: (dc) => AlertDialog(
                      title: const Text('Encryption'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Standard', style: TextStyle(fontWeight: FontWeight.w700, color: reyeeMuted)),
                            for (final e in [Encryption.open, Encryption.wpa2, Encryption.wpa2Wpa3, Encryption.wpa3])
                              RadioListTile<String>(value: e.code, groupValue: enc, title: Text(e.label), onChanged: (v) => Navigator.pop(dc, v)),
                            const SizedBox(height: 8),
                            const Text('Legacy', style: TextStyle(fontWeight: FontWeight.w700, color: reyeeMuted)),
                            const Text('Older devices only, less secure.', style: TextStyle(color: reyeeMuted, fontSize: 12)),
                            for (final e in [Encryption.wpa, Encryption.wpaWpa2])
                              RadioListTile<String>(value: e.code, groupValue: enc, title: Text(e.label), onChanged: (v) => Navigator.pop(dc, v)),
                          ],
                        ),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel'))],
                    ),
                  );
                  if (picked != null) setD(() => enc = picked);
                }),
                if (enc != 'open') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: pass,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: 'WiFi password (min 8 characters)',
                      suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setD(() => showPass = !showPass)),
                    ),
                  ),
                ],
                SwitchListTile(value: enabled, onChanged: (v) => setD(() => enabled = v), title: const Text('Enabled')),
                SwitchListTile(value: hidden, onChanged: (v) => setD(() => hidden = v), title: const Text('Hidden network')),
                const Text('Connected devices will disconnect briefly when WiFi settings are applied.', style: TextStyle(color: reyeeMuted, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        setD(() => dialogError = 'Network name cannot be empty.');
                        return;
                      }
                      if (enc != 'open' && pass.text.length < 8) {
                        setD(() => dialogError = 'Password must be at least 8 characters.');
                        return;
                      }
                      setD(() => saving = true);
                      try {
                        final wlanId = str(ssid['wlanId'], '1');
                        final updated = _ssids.map((item) {
                          final base = Map<String, dynamic>.from(item);
                          base['encryptionMode'] = base['encryptionMode'] ?? authToEncryption(base['auth']);
                          base['ishidden'] = base['ishidden'] ?? (base['hide'] == 1 ? 'true' : 'false');
                          if (str(base['wlanId']) == wlanId) {
                            base['enable'] = enabled ? 'yes' : 'no';
                            base['ssidName'] = name.text.trim();
                            base['encryptionMode'] = enc;
                            base['password'] = pass.text;
                            base['ishidden'] = hidden ? 'true' : 'false';
                          }
                          return base;
                        }).toList();
                        // groupId must be a number, not a string, or the
                        // stock check silently skips the change. Proven in eweb.
                        await widget.api.post('/api/v1/lua/WiFi/setWifiPlain', {
                          'ssidList': updated,
                          'ssidgroup': '1,2',
                          'groupId': _groupForWlan[wlanId] ?? 1,
                          'wifiFirst': false,
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on SessionExpiredException {
                        if (ctx.mounted) Navigator.pop(ctx, false);
                        widget.onSessionExpired();
                      } catch (e) {
                        setD(() {
                          dialogError = e is ApiException ? e.message : 'Failed to save WiFi.';
                          saving = false;
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _load();
      final after = _ssids.firstWhere((s) => str(s['wlanId']) == str(ssid['wlanId']), orElse: () => {});
      if (after.isNotEmpty) {
        final savedName = str(after['ssidName'], '');
        final savedEnc = str(after['encryptionMode'], authToEncryption(after['auth']));
        if (savedName != name.text.trim() || savedEnc != enc) {
          showMsg(context, 'Saved name is $savedName and encryption is ${Encryption.fromCode(savedEnc).label}, not what was sent. Please try again.');
          return;
        }
      }
      showMsg(context, 'WiFi saved.');
    }
    name.dispose();
    pass.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          errorBanner(_error),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_ssids.isEmpty)
            reyeeCard(child: const Text('No WiFi networks returned by the router.'))
          else
            for (final s in _ssids)
              reyeeCard(
                child: Row(
                  children: [
                    const Icon(Icons.wifi, color: reyeeBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(str(s['ssidName'], 'Unnamed'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${radioBandLabel(s['relatedRadio'])} · ${Encryption.fromCode(str(s['encryptionMode'], authToEncryption(s['auth']))).label} · ${(s['enable'] == 'yes' || s['enable'] == 'true') ? 'On' : 'Off'}', style: const TextStyle(color: reyeeMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => _edit(s), child: const Text('Edit')),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------- Tools ----------------

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.api, required this.onSessionExpired});
  final RouterApi api;
  final VoidCallback onSessionExpired;
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _checking = false;
  bool _diagRunning = false;
  String _checkResult = '';
  String _diagOutput = '';
  String _diagSummary = '';
  final _diagTarget = TextEditingController(text: 'www.google.com');
  String _diagMethod = 'ping';
  String? _error;

  final _checkItems = const [
    ('if_status', 'WAN port'),
    ('ip_status', 'WAN IP'),
    ('dns_status', 'DNS'),
    ('internet_status', 'Internet'),
    ('lan_status', 'LAN'),
  ];

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _error = null;
      _checkResult = '';
    });
    final lines = <String>[];
    try {
      // WAN IP cross-check first, so a passing ubus call is never trusted
      // alone. This is the v16 fix from the web panel.
      var wanHasIp = false;
      try {
        final w = await widget.api.get('/api/v1/lua/network/wanget');
        final d = dataOf(w);
        if (d is Map && d['wan'] is Map && (d['wan'] as Map)['ip'] != null) wanHasIp = true;
      } catch (_) {}
      for (final item in _checkItems) {
        try {
          final res = await widget.api.post('/api/v1/lua/NetworkCheck/StartCheck', {'item': item.$1});
          final raw = dataOf(res);
          Map? m;
          if (raw is Map) m = raw;
          var errCode = m?['errorcode'] ?? m?['ret'];
          if (errCode == null && m != null && m['data'] is Map) {
            errCode = (m['data'] as Map)['errorcode'] ?? (m['data'] as Map)['ret'];
          }
          var ok = errCode == 0 || errCode == '0';
          if (!wanHasIp && (item.$1 == 'ip_status' || item.$1 == 'dns_status')) ok = false;
          lines.add('${item.$2}: ${ok ? 'Passed' : 'Failed'}');
        } catch (e) {
          lines.add('${item.$2}: Error (${e is ApiException ? e.message : 'failed'})');
        }
      }
      if (mounted) setState(() => _checkResult = lines.join('\n'));
    } on SessionExpiredException {
      widget.onSessionExpired();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _recoverFailed() async {
    // Recover is only offered after a check, and only for items that failed.
    // It uses the same DiagnoseRecover payload as the web panel.
    final failed = <String>[];
    for (final line in _checkResult.split('\n')) {
      if (line.contains('Failed')) {
        for (final item in _checkItems) {
          if (line.startsWith(item.$2)) failed.add(item.$1);
        }
      }
    }
    if (failed.isEmpty) {
      showMsg(context, 'No failed item to recover.');
      return;
    }
    final ok = await confirmDialog(context, 'Recover network', 'Try to recover ${failed.length} failed item(s)?');
    if (!ok) return;
    try {
      for (final key in failed) {
        await widget.api.post('/api/v1/lua/NetworkCheck/DiagnoseRecover', {'item': key, 'code': 0});
      }
      showMsg(context, 'Recovery requested. Run the check again to verify.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Recovery failed.');
    }
  }

  Future<void> _runDiagnose() async {
    final target = _diagTarget.text.trim();
    if (target.isEmpty) {
      setState(() => _error = 'Enter a diagnose target.');
      return;
    }
    setState(() {
      _diagRunning = true;
      _error = null;
      _diagOutput = 'Running $_diagMethod to $target...';
    });
    try {
      final res = await widget.api.post('/api/v1/lua/Diagnose/diagnose', {
        'method': _diagMethod,
        'params': {'target': target, 'count': '4', 'size': '64', 'ttl': '20', 'type': '1'}
      });
      final d = dataOf(res);
      if (d is Map && d['res'] != null) {
        setState(() { _diagOutput = d['res'].toString(); _diagSummary = '${_diagMethod == 'ping' ? 'Ping' : 'DNS lookup'} to $target finished. The raw tool output follows.'; });
      } else {
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
        final out = await widget.api.get('/api/v1/lua/Diagnose/getDiagnoseRes');
        final od = dataOf(out);
        if (od is Map && od['res'] != null) setState(() { _diagOutput = od['res'].toString(); _diagSummary = '${_diagMethod == 'ping' ? 'Ping' : 'DNS lookup'} to $target finished. The raw tool output follows.'; });
      }
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Diagnose failed.');
    } finally {
      if (mounted) setState(() => _diagRunning = false);
    }
  }

  @override
  void dispose() {
    _diagTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        errorBanner(_error),
        sectionTitle('Network self check'),
        reyeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Checks WAN port, WAN IP, DNS, internet and LAN. A result only counts as passed when the router confirms it, not just when the call returns.', style: TextStyle(color: reyeeMuted, height: 1.4)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _checking ? null : _runCheck, child: Text(_checking ? 'Checking...' : 'Run network check')),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _recoverFailed, child: const Text('Recover failed items')),
              if (_checkResult.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_checkResult, style: const TextStyle(height: 1.5)),
              ],
            ],
          ),
        ),
        sectionTitle('Ping and diagnose'),
        reyeeCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _diagMethod,
                items: const [
                  DropdownMenuItem(value: 'ping', child: Text('Ping')),
                  DropdownMenuItem(value: 'nslookup', child: Text('DNS lookup')),
                ],
                onChanged: (v) => setState(() => _diagMethod = v ?? 'ping'),
                decoration: const InputDecoration(labelText: 'Method'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _diagTarget, decoration: const InputDecoration(labelText: 'Target')),
              const SizedBox(height: 12),
              FilledButton(onPressed: _diagRunning ? null : _runDiagnose, child: Text(_diagRunning ? 'Running...' : 'Run diagnose')),
              if (_diagSummary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_diagSummary, style: const TextStyle(height: 1.45)),
              ],
              if (_diagOutput.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: reyeeBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(_diagOutput, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Settings: network, mesh, ports, DNS, LED, system ----------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api, required this.routerIp, required this.onSessionExpired});
  final RouterApi api;
  final String routerIp;
  final VoidCallback onSessionExpired;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String? _error;
  String _wanInfo = '-';
  String _lanInfo = '-';
  String _meshInfo = '-';
  String _dnsInfo = '-';
  String _led = '-';
  String _ipv6 = '-';
  String _connector = 'Not installed';
  List<Map<String, dynamic>> _ports = [];
  List<Map<String, dynamic>> _logs = [];

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
      final n = await widget.api.get('/api/v1/lua/network/info');
      final d = dataOf(n);
      if (d is Map) {
        final wan = d['wan'];
        final lan = d['lan'];
        Map? wm;
        Map? lm;
        if (wan is List && wan.isNotEmpty) wm = wan.first as Map?;
        if (wan is Map) wm = wan;
        if (lan is List && lan.isNotEmpty) lm = lan.first as Map?;
        if (lan is Map) lm = lan;
        _wanInfo = wm == null ? '-' : '${wanProtoLabel(wm['proto'])} · ${str(wm['ipaddr'])}';
        final dhcpState = () {
          if (lm == null) return 'DHCP status unknown';
          final f = str(lm['enblDhcpSrv'], '').toLowerCase();
          if (f == 'yes' || f == '1' || f == 'true') return 'DHCP on';
          if (f == 'no' || f == '0' || f == 'false') return 'DHCP off';
          return 'DHCP status unknown';
        }();
        _lanInfo = lm == null ? '-' : '${str(lm['ipaddr'])} / ${str(lm['netmask'])} · $dhcpState';
      }
    } catch (_) {}
    try {
      final m = await widget.api.get('/api/v1/lua/mesh/MeshGetTopo');
      final d = dataOf(m);
      if (d is Map) _meshInfo = '${meshNodeCount(d['childList'])} node(s)';
    } catch (_) {}
    try {
      final s = await widget.api.post('/api/v1/lua/StaticDns/GetStaticDns', {'DnsType': 0});
      final d = dataOf(s);
      if (d is Map) _dnsInfo = '${str(d['dns1'])} · ${str(d['dns2'])}';
    } catch (_) {
      try {
        final s = await widget.api.post('/api/v1/lua/StaticDns/GetStaticDns', {'DnsType': 1});
        final d = dataOf(s);
        if (d is Map) _dnsInfo = '${str(d['dns1'])} · ${str(d['dns2'])}';
      } catch (_) {}
    }
    try {
      final l = await widget.api.get('/api/v1/lua/LED/devLed');
      final d = dataOf(l);
      if (d is Map && d['led_all'] != null) _led = str(d['led_all']);
    } catch (_) {}
    try {
      final v = await widget.api.get('/api/v1/lua/InternetProtocolVersionSix/GetIPv6Status');
      final d = dataOf(v);
      if (d is Map && d['mode'] != null) _ipv6 = Ipv6Mode.fromCode(d['mode']).label;
    } catch (_) {}
    try {
      final p = await widget.api.post('/api/v1/lua/PortMap/getPortMapping', {'page': 1, 'size': 20});
      final d = dataOf(p);
      var list = const <dynamic>[];
      if (d is Map) {
        final all = d['allItem'];
        if (all is List && all.isNotEmpty) {
          list = all;
        } else {
          list = listOf(d['list']);
        }
      }
      _ports = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {}
    try {
      final cg = await widget.api.get('/api/maapp.lua?action=ping');
      final cd = dataOf(cg);
      _connector = (cd is Map && cd['connector'] == 'maapp') ? 'Installed' : 'Not installed';
    } catch (_) {
      _connector = 'Not installed';
    }
    try {
      final lg = await widget.api.get('/api/v1/lua/Log/syslog');
      final d = dataOf(lg);
      var list = const <dynamic>[];
      if (d is Map) list = listOf(d['list'] ?? d['logs'] ?? d['log']);
      _logs = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList().take(20).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _wan(bool connect) async {
    final ok = await confirmDialog(context, connect ? 'Connect WAN' : 'Disconnect WAN', connect ? 'Reconnect the WAN connection?' : 'Disconnect the WAN connection? Internet will stop until you reconnect.');
    if (!ok) return;
    try {
      await widget.api.post(connect ? '/api/v1/lua/network/wanConnectPlain' : '/api/v1/lua/network/wanDisconnectPlain', {});
      showMsg(context, connect ? 'WAN connect requested. Checking...' : 'WAN disconnect requested.');
      await Future.delayed(const Duration(seconds: 3));
      await _load();
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'WAN action failed.');
    }
  }

  Future<void> _addPort() async {
    final name = TextEditingController();
    final proto = ValueNotifier<String>('tcp');
    final src = TextEditingController();
    final ip = TextEditingController();
    final dest = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add port forwarding'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Rule name')),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: proto,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  items: const [DropdownMenuItem(value: 'tcp', child: Text('TCP')), DropdownMenuItem(value: 'udp', child: Text('UDP')), DropdownMenuItem(value: 'tcp/udp', child: Text('TCP/UDP'))],
                  onChanged: (nv) => proto.value = nv ?? 'tcp',
                  decoration: const InputDecoration(labelText: 'Protocol'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: src, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'External port')),
              const SizedBox(height: 10),
              TextField(controller: ip, decoration: const InputDecoration(labelText: 'Internal IP')),
              const SizedBox(height: 10),
              TextField(controller: dest, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Internal port')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || src.text.trim().isEmpty || ip.text.trim().isEmpty || dest.text.trim().isEmpty) {
      showMsg(context, 'Fill in every port forwarding field.');
      return;
    }
    try {
      // Stock add payload, proven in the web panel. Protocol is lowercase.
      await widget.api.post('/api/v1/lua/PortMap/addPortMapping', {
        'ruleName': name.text.trim(),
        'proto': proto.value,
        'srcPort': src.text.trim(),
        'destIp': ip.text.trim(),
        'destPort': dest.text.trim(),
        'srcIp': '0.0.0.0',
      });
      await _load();
      showMsg(context, 'Port forwarding rule added.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Failed to add rule.');
    }
  }

  Future<void> _deletePort(Map<String, dynamic> item) async {
    final ok = await confirmDialog(context, 'Delete rule', 'Delete port forwarding rule ${str(item['ruleName'])}?');
    if (!ok) return;
    try {
      await widget.api.post('/api/v1/lua/PortMap/delPortMapping', {'list': [item]});
      await _load();
      showMsg(context, 'Rule deleted.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Failed to delete rule.');
    }
  }

  Future<void> _ledToggle() async {
    final next = _led == 'close' ? 'restore' : 'close';
    var savedList = <dynamic>[];
    try {
      final led = await widget.api.get('/api/v1/lua/LED/devLed');
      final ld = dataOf(led);
      if (ld is Map && ld['LedConfigList'] is List) savedList = ld['LedConfigList'] as List;
    } catch (_) {}
    try {
      await widget.api.post('/api/v1/lua/LED/setLed', {'led_all': next, 'LedConfigList': savedList});
      await _load();
      showMsg(context, 'LED set to ${LedMode.fromCode(next).label}.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Failed to change LED.');
    }
  }

  Future<void> _reboot() async {
    final ok = await confirmDialog(context, 'Restart router', 'Restart the router now? It will be offline for a few minutes. This app will need to log in again.');
    if (!ok) return;
    try {
      await widget.api.post('/api/v1/lua/SystemManage/reboot', {});
      showMsg(context, 'Restart requested.');
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Restart failed.');
    }
  }

  Future<void> _changeAdminPassword() async {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change admin password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldP, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            const SizedBox(height: 10),
            TextField(controller: newP, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.post('/api/v1/lua/AdminPwd/pwdmodifyPlain', {'oldPassword': oldP.text, 'newPassword': newP.text});
      if (!mounted) return;
      showMsg(context, 'Password changed. Please log in again.');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    } on SessionExpiredException {
      widget.onSessionExpired();
    } catch (e) {
      showMsg(context, e is ApiException ? e.message : 'Failed to change password.');
    }
  }

  void _logout() {
    widget.api.token = null;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          errorBanner(_error),
          sectionTitle('More'),
          reyeeCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Advanced router settings', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Parental control, radio, mesh, network, IPv6, system, MAC filter, IPTV', style: TextStyle(color: reyeeMuted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdvancedScreen(api: widget.api, onSessionExpired: widget.onSessionExpired))),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Local insights', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Charts, device history, phone speed test, local alerts, weekly report, offline cache', style: TextStyle(color: reyeeMuted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocalScreen(api: widget.api, onSessionExpired: widget.onSessionExpired))),
                ),
              ],
            ),
          ),
          sectionTitle('Network'),
          reyeeCard(
            child: Column(
              children: [
                infoRow('WAN', _wanInfo),
                infoRow('LAN', _lanInfo),
                infoRow('Mesh', _meshInfo),
                infoRow('DNS', _dnsInfo),
                infoRow('IPv6', _ipv6),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _wan(true), child: const Text('Connect WAN'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: () => _wan(false), child: const Text('Disconnect WAN'))),
                  ],
                ),
              ],
            ),
          ),
          sectionTitle('Port forwarding'),
          if (_ports.isEmpty)
            reyeeCard(child: Text(_loading ? 'Loading...' : 'No port forwarding rules.'))
          else
            for (final p in _ports)
              reyeeCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('${str(p['ruleName'])} · ${str(p['proto']).toUpperCase()} ${str(p['srcPort'])} to ${str(p['destIp'])}:${str(p['destPort'])}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deletePort(p)),
                  ],
                ),
              ),
          FilledButton.icon(onPressed: _addPort, icon: const Icon(Icons.add), label: const Text('Add rule')),
          sectionTitle('Router'),
          reyeeCard(
            child: Column(
              children: [
                infoRow('LED', LedMode.fromCode(_led).label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: _ledToggle, child: Text(_led == 'close' ? 'Turn LED on' : 'Turn LED off'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: _reboot, child: const Text('Restart router'))),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: _changeAdminPassword, child: const Text('Change admin password')),
              ],
            ),
          ),
          sectionTitle('Recent logs'),
          if (_logs.isEmpty)
            reyeeCard(child: Text(_loading ? 'Loading...' : 'No logs returned.'))
          else
            for (final l in _logs.take(10))
              reyeeCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(() { final t = (l['msg'] ?? l['content'])?.toString(); return (t != null && t.isNotEmpty) ? t : 'Log entry'; }(), style: const TextStyle(fontSize: 12, height: 1.4)),
              ),
          sectionTitle('Session'),
          reyeeCard(
            child: Column(
              children: [
                infoRow('Router IP', widget.routerIp),
                infoRow('Connector', _connector),
                const SizedBox(height: 10),
                FilledButton(onPressed: _logout, child: const Text('Log out')),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
