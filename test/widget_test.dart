import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/main.dart';

void main() {
  testWidgets('App renders main navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const HalaPhApp());
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
