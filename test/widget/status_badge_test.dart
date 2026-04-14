import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/widgets/status_badge.dart';

void main() {
  testWidgets('StatusBadge exibe texto e estrutura base', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(
            text: 'EM ROTA',
            type: BadgeType.success,
          ),
        ),
      ),
    );

    expect(find.text('EM ROTA'), findsOneWidget);
    expect(find.byType(FittedBox), findsOneWidget);
    expect(find.byType(Row), findsOneWidget);
  });
}
