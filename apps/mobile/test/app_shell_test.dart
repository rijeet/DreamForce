import 'package:dream_force/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Dream Force navigation and opens activity chooser', (
    tester,
  ) async {
    await tester.pumpWidget(const DreamForceApp());

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose activity'));
    await tester.pumpAndSettle();

    expect(find.text('Choose activity'), findsOneWidget);
  });
}
