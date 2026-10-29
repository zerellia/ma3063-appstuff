import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/labels.dart';

void main() {
  test('tmp_free_kb converts kilobytes to MB with one decimal', () {
    expect(formatTmpFreeSpace(1024), 'Free /tmp space (connector): 1.0 MB');
    expect(formatTmpFreeSpace(1536), 'Free /tmp space (connector): 1.5 MB');
    expect(formatTmpFreeSpace(0), 'Free /tmp space (connector): 0.0 MB');
    expect(formatTmpFreeSpace('2048'), 'Free /tmp space (connector): 2.0 MB');
  });

  test('missing or bad tmp_free_kb keeps the unknown behaviour', () {
    expect(formatTmpFreeSpace(null), 'Free size: unknown');
    expect(formatTmpFreeSpace('bad'), 'Free size: unknown');
    expect(formatTmpFreeSpace(-1), 'Free size: unknown');
  });

  test('connector string never claims the stock size', () {
    expect(formatTmpFreeSpace(1024), contains('(connector)'));
    expect(formatTmpFreeSpace(1024), isNot(contains('Free size:')));
  });
}
