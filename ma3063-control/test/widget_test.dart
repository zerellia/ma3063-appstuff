import 'package:flutter_test/flutter_test.dart';
import 'package:ma3063_control/main.dart';

void main() {
  testWidgets('Login screen shows MA3063 Control', (tester) async {
    await tester.pumpWidget(const MaApp());
    expect(find.text('MA3063 Control'), findsWidgets);
  });
}
