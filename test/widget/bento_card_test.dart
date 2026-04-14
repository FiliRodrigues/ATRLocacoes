import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/widgets/bento_card.dart';

void main() {
  testWidgets('BentoCard renderiza child e executa onTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BentoCard(
            animationDelay: -1,
            onTap: () => tapped = true,
            child: const Text('Conteudo Bento'),
          ),
        ),
      ),
    );

    expect(find.text('Conteudo Bento'), findsOneWidget);
    expect(find.byType(BentoCard), findsOneWidget);

    await tester.tap(find.byType(BentoCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
