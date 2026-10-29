import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/choice_widgets.dart';

void main() {
  testWidgets('Manual field is hidden until the Manual chip is tapped', (tester) async {
    var kbps = 10000;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LimitEditor(kbps: kbps, onChanged: (v) => kbps = v)),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('Manual'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('20 Mbps'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(kbps, 20000);
  });

  testWidgets('A non-preset value opens with the manual field visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LimitEditor(kbps: 12000, onChanged: _noop)),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
  });
}

void _noop(int _) {}
