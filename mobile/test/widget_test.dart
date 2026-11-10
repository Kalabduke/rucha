import 'package:flutter_test/flutter_test.dart';
import 'package:rucha_mobile/main.dart';

void main() {
  testWidgets('Rucha App boots up', (WidgetTester tester) async {
    await tester.pumpWidget(const RuchaApp());
    expect(find.text('RUCHA'), findsOneWidget);
  });
}
