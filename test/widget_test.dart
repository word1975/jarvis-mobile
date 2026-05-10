import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    expect(find.text('Jarvis 远程控制'), findsOneWidget);
  });
}