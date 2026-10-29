import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/device_icons.dart';
import 'package:ma3063_control/topology_data.dart';
import 'package:ma3063_control/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('WiFi standard maps from real fields only', () {
    expect(wifiStandardOf({'mode': '11ax'}), 'WiFi 6');
    expect(wifiStandardOf({'wifiMode': '11ac'}), 'WiFi 5');
    expect(wifiStandardOf({'standard': '11n'}), 'WiFi 4');
    expect(wifiStandardOf({'phyMode': '11ax'}), 'WiFi 6');
    expect(wifiStandardOf({'protocol': '11ac'}), 'WiFi 5');
    expect(wifiStandardOf({'mode': 'ax'}), 'WiFi 6');
  });

  test('WiFi standard is Unknown when the field is missing or unrecognized', () {
    expect(wifiStandardOf({}), 'Unknown');
    expect(wifiStandardOf({'mode': '11g'}), 'Unknown');
    expect(wifiStandardOf({'mode': ''}), 'Unknown');
    expect(hasStandardField([{}, {}]), isFalse);
    expect(hasStandardField([{'mode': '11ax'}]), isTrue);
  });

  test('Standard counts and band breakdown', () {
    final clients = [
      {'mode': '11ax', 'ssid': 'JAYANA 5G'},
      {'mode': '11ac', 'ssid': 'JAYANA 5G'},
      {'ssid': 'JAYANA 2.4G'},
    ];
    expect(countByStandard(clients), {'WiFi 6': 1, 'WiFi 5': 1, 'Unknown': 1});
    expect(countByBand(clients)['5 GHz'], 2);
    expect(countByBand(clients)['2.4 GHz'], 1);
  });

  test('Band is Unknown when no band text is present', () {
    expect(bandOf({'ssid': 'MyWifi'}), 'Unknown band');
    expect(bandOf({}), 'Unknown band');
  });

  test('Port display mirrors Home parsing, never PoE', () {
    final wan = portDisplay({'portId': 1, 'isWan': true, 'status': 'on', 'speed': '1000'});
    expect(wan['portLabel'], 'WAN Port 1');
    expect(wan['up'], isTrue);
    expect(wan['speedLabel'], '1000 Mbps');
    final lanDown = portDisplay({'portId': 3, 'isWan': false, 'status': 'off', 'speed': '100'});
    expect(lanDown['portLabel'], 'LAN Port 3');
    expect(lanDown['up'], isFalse);
    expect(lanDown['speedLabel'], 'Disconnected');
    expect('$wan$lanDown', isNot(contains('PoE')));
  });

  test('Device icon options cover the requested set', () {
    final keys = deviceIconOptions.map((o) => o.key).toSet();
    expect(keys, containsAll(['laptop', 'pc', 'phone', 'router', 'cctv', 'tv', 'printer', 'console', 'speaker', 'generic']));
    expect(deviceIconForKey('laptop'), Icons.laptop_outlined);
    expect(deviceIconForKey('cctv'), Icons.videocam_outlined);
    expect(deviceIconForKey(null), Icons.devices_outlined);
    expect(deviceIconForKey('bogus'), Icons.devices_outlined);
    expect(deviceIconLabel('tv'), 'TV');
  });

  test('Local device icons round-trip on this phone only', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.setDeviceIcon('AA:BB:CC:DD:EE:FF', 'laptop');
    final icons = await LocalStore.deviceIcons();
    expect(icons['AA:BB:CC:DD:EE:FF'], 'laptop');
  });
}
