import 'package:dream_force/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires Google account creation before app navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const DreamForceApp());

    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Today'), findsNothing);

    // Navigation is reachable only after Google returns a real account.
    // The native account chooser is intentionally not exercised in a widget test.
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GOOGLE_SERVER_CLIENT_ID'), findsOneWidget);
  });
}
