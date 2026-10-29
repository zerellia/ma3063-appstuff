import 'package:flutter/material.dart';

/// Local only device icons. The stock API does not save a device rename
/// on the router, and it does not save a device icon either, so the
/// choice is stored on this phone only, keyed by MAC address, exactly
/// like the local nickname. Nothing here is sent to the router.
class DeviceIconOption {
  const DeviceIconOption(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const List<DeviceIconOption> deviceIconOptions = [
  DeviceIconOption('laptop', 'Laptop', Icons.laptop_outlined),
  DeviceIconOption('pc', 'PC', Icons.desktop_windows_outlined),
  DeviceIconOption('phone', 'Phone', Icons.smartphone_outlined),
  DeviceIconOption('router', 'Router', Icons.router_outlined),
  DeviceIconOption('cctv', 'CCTV', Icons.videocam_outlined),
  DeviceIconOption('tv', 'TV', Icons.tv_outlined),
  DeviceIconOption('printer', 'Printer', Icons.print_outlined),
  DeviceIconOption('console', 'Game console', Icons.sports_esports_outlined),
  DeviceIconOption('speaker', 'Speaker', Icons.speaker_outlined),
  DeviceIconOption('generic', 'Other device', Icons.devices_outlined),
];

IconData deviceIconForKey(String? key, {IconData fallback = Icons.devices_outlined}) {
  if (key == null || key.isEmpty) return fallback;
  for (final o in deviceIconOptions) {
    if (o.key == key) return o.icon;
  }
  return fallback;
}

String deviceIconLabel(String? key) {
  if (key == null || key.isEmpty) return 'Other device';
  for (final o in deviceIconOptions) {
    if (o.key == key) return o.label;
  }
  return 'Other device';
}

/// Icon picker sheet. Returns the picked key, or null when dismissed.
/// The caller saves it with LocalStore.setDeviceIcon; this sheet itself
/// writes nothing, so it can be reused from Devices and from Topology.
Future<String?> showDeviceIconPicker(BuildContext context, String? currentKey) async {
  return showModalBottomSheet<String>(
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
            const Text('Device icon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Local only, saved on this phone. It is not sent to the router.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.45)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in deviceIconOptions)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(o.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(o.label),
                      ],
                    ),
                    selected: o.key == currentKey,
                    onSelected: (_) => Navigator.pop(ctx, o.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
