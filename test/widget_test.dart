import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const OneMinuteApp());
    expect(find.text('One Minute'), findsOneWidget);
  });
}
