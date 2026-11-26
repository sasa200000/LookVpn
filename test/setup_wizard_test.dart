import 'package:mili_vpn/state/app_state.dart';
import 'package:mili_vpn/ui/setup_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWizard(WidgetTester tester) async {
    // A small phone (360×800 dp) to catch overflows.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: const MaterialApp(home: SetupWizard()),
      ),
    );
  }

  testWidgets('step 1 asks about a Cloudflare account, No shows sign-up steps', (tester) async {
    await pumpWizard(tester);
    expect(find.text('Cloudflare'), findsOneWidget);
    expect(find.text('Welcome to MiliConfig'), findsOneWidget);

    await tester.tap(find.text('No, sign me up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your Cloudflare account'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MiliConfig'), findsOneWidget);
  });

  testWidgets('Yes goes to the token step, Back returns', (tester) async {
    await pumpWizard(tester);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('API token'), findsOneWidget);
    expect(find.text('Create an API token'), findsOneWidget);

    // Next without a token shows an error instead of calling Cloudflare.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Paste your API token first'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Cloudflare'), findsOneWidget);
  });
}
