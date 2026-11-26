import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mili_vpn/ui/bettbox_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  testWidgets('selected tab label is visible beside its icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          bottomNavigationBar: BettboxFloatingNavBar(
            selectedIndex: 0,
            onChanged: (_) {},
            items: const [
              (
                icon: Symbols.space_dashboard_rounded,
                label: 'Dashboard',
              ),
              (icon: Symbols.radar_rounded, label: 'Scanner'),
              (icon: Symbols.tune_rounded, label: 'Settings'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.text('Dashboard');
    expect(label, findsOneWidget);
    expect(tester.getSize(label).width, greaterThan(0));

    final labelCenter = tester.getCenter(label);
    final iconCenter = tester.getCenter(
      find.byIcon(Symbols.space_dashboard_rounded),
    );
    expect((labelCenter.dy - iconCenter.dy).abs(), lessThan(2));
  });
}
