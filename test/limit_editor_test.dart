import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/limit_math.dart';

void main() {
  test('Mbps to Kbps uses hardware factor 1000', () {
    expect(kbpsFromValue(10, LimitUnit.mbps), 10000);
    expect(kbpsFromValue(5, LimitUnit.mbps), 5000);
    expect(kbpsFromValue(0, LimitUnit.mbps), 0);
  });

  test('KBps to Kbps uses factor 8', () {
    expect(kbpsFromValue(125, LimitUnit.kbps), 1000);
    expect(kbpsFromValue(1000, LimitUnit.kbps), 8000);
  });

  test('MBps to Kbps uses factor 8000', () {
    expect(kbpsFromValue(1, LimitUnit.mbpsByte), 8000);
    expect(kbpsFromValue(10, LimitUnit.mbpsByte), 80000);
  });

  test('No limit sends 0 and shows No limit', () {
    expect(kbpsFromValue(0, LimitUnit.mbps), 0);
    expect(limitSummary(0), 'No limit');
  });

  test('Negative values are rejected', () {
    expect(limitError('-5'), isNotNull);
    expect(limitError('-0.5'), isNotNull);
    expect(limitError('10'), isNull);
    expect(limitError(''), isNull);
    expect(limitError('abc'), isNotNull);
  });

  test('Manual value is not snapped to the nearest preset', () {
    // 12 Mbps is not a preset. The typed value stays 12000 Kbps,
    // while the slider hint is only the closest preset, 10 Mbps.
    expect(kbpsFromValue(12, LimitUnit.mbps), 12000);
    expect(closestPresetMbps(12000), 10);
    expect(kbpsFromValue(7, LimitUnit.mbps), 7000);
    expect(closestPresetMbps(7000), 5);
  });

  test('Summary is always in Mbps, never raw Kbps', () {
    expect(limitSummary(10000), '10 Mbps');
    expect(limitSummary(10500), '10.5 Mbps');
    expect(limitSummary(8000), '8 Mbps');
  });

  test('Above 1000 Mbps shows a warning, never a silent clamp', () {
    expect(limitAboveRouterHint(1000 * 1000), isFalse);
    expect(limitAboveRouterHint(1001 * 1000), isTrue);
  });

  test('Unit labels', () {
    expect(LimitUnit.mbps.label, 'Mbps');
    expect(LimitUnit.kbps.label, 'KBps');
    expect(LimitUnit.mbpsByte.label, 'MBps');
  });

  test('Manual field is needed only for non-preset values', () {
    expect(limitNeedsManual(0), isFalse);
    expect(limitNeedsManual(10000), isFalse);
    expect(limitNeedsManual(500000), isFalse);
    expect(limitNeedsManual(12000), isTrue);
    expect(limitNeedsManual(8000), isTrue);
    expect(isPresetKbps(20000), isTrue);
    expect(isPresetKbps(7000), isFalse);
  });

  test('Slider preset mapping is exact for presets and closest otherwise', () {
    expect(presetIndexForKbps(0), 0);
    expect(presetIndexForKbps(10000), 2);
    expect(presetIndexForKbps(500000), 7);
    expect(presetIndexForKbps(12000), 2);
    expect(presetIndexForKbps(7000), 1);
  });
}
