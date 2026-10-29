/// Pure bandwidth limit conversion. No widget code here, so the
/// conversion is unit tested without a router or a screen.
///
/// Hardware proven factors: 1 Mbps = 1000 Kbps, 1 MBps = 8000 Kbps,
/// 1 KBps = 8 Kbps. Conversion happens at the boundary only: the UI
/// shows the chosen unit, the router always receives Kbps.
enum LimitUnit { mbps, kbps, mbpsByte }

extension LimitUnitX on LimitUnit {
  String get label {
    switch (this) {
      case LimitUnit.mbps:
        return 'Mbps';
      case LimitUnit.kbps:
        return 'KBps';
      case LimitUnit.mbpsByte:
        return 'MBps';
    }
  }

  double get kbpsFactor {
    switch (this) {
      case LimitUnit.mbps:
        return 1000;
      case LimitUnit.kbps:
        return 8;
      case LimitUnit.mbpsByte:
        return 8000;
    }
  }
}

/// Convert a value in [unit] to Kbps, rounded to a whole number.
int kbpsFromValue(double value, LimitUnit unit) => (value * unit.kbpsFactor).round();

/// Convert Kbps to Mbps as a double. This is the summary unit.
double mbpsFromKbps(int kbps) => kbps / 1000;

/// Convert Kbps to a display value in [unit].
double valueFromKbps(int kbps, LimitUnit unit) => kbps / unit.kbpsFactor;

/// Human summary, always in Mbps, never in raw Kbps.
String limitSummary(int kbps) {
  if (kbps <= 0) return 'No limit';
  final mbps = mbpsFromKbps(kbps);
  final text = mbps == mbps.roundToDouble() ? '${mbps.round()}' : mbps.toStringAsFixed(1);
  return '$text Mbps';
}

/// Validation for the manual field. Returns null when the value is
/// usable, otherwise a human message. Empty means No limit, which is
/// handled by the caller, not by this function.
String? limitError(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final v = double.tryParse(trimmed);
  if (v == null) return 'Enter a number, for example 10.';
  if (v < 0) return 'Negative is not a valid limit. Use No limit for unlimited.';
  return null;
}

/// True when the value is above 1000 Mbps equivalent. The caller
/// shows a warning, it never silently clamps the value.
bool limitAboveRouterHint(int kbps) => kbps > 1000 * 1000;

/// Closest preset in Mbps, used only as a slider hint. The typed
/// value is authoritative and is never snapped to this.
int closestPresetMbps(int kbps) {
  const presets = [0, 5, 10, 20, 50, 100, 200, 500];
  final mbps = mbpsFromKbps(kbps).round();
  var best = presets.first;
  for (final p in presets) {
    if ((p - mbps).abs() < (best - mbps).abs()) best = p;
  }
  return best;
}

/// Preset values in Kbps, matching LimitEditor.steps in Mbps.
const List<int> presetKbps = [0, 5000, 10000, 20000, 50000, 100000, 200000, 500000];

/// True when [kbps] is exactly one of the presets.
bool isPresetKbps(int kbps) => presetKbps.contains(kbps);

/// True when the value needs the manual field: positive and not a preset.
bool limitNeedsManual(int kbps) => kbps > 0 && !isPresetKbps(kbps);

/// Index of the preset for the slider: exact preset, else closest preset.
int presetIndexForKbps(int kbps) {
  if (presetKbps.contains(kbps)) return presetKbps.indexOf(kbps);
  var best = 0;
  for (var i = 0; i < presetKbps.length; i++) {
    if ((presetKbps[i] - kbps).abs() < (presetKbps[best] - kbps).abs()) best = i;
  }
  return best;
}
