import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:fleet_app/core/widgets/bento_card.dart';
import 'package:fleet_app/core/widgets/status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('StatusBadge variantes visuais', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'badges',
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatusBadge(text: 'EM ROTA', type: BadgeType.success),
            StatusBadge(text: 'ATENCAO', type: BadgeType.warning),
            StatusBadge(text: 'ATRASADO', type: BadgeType.error),
            StatusBadge(text: 'INFO', type: BadgeType.info),
          ],
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      surfaceSize: const Size(720, 220),
      wrapper: materialAppWrapper(theme: ThemeData.light()),
    );

    await tester.pump(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'goldens/status_badge_variantes');
  });

  testGoldens('BentoCard claro e escuro', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'light',
        Theme(
          data: ThemeData.light(),
          child: const ColoredBox(
            color: Color(0xFFF6F8FC),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 560,
                child: BentoCard(
                  animationDelay: -1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Resumo da Frota'),
                      StatusBadge(text: 'ATIVO', type: BadgeType.success),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      )
      ..addScenario(
        'dark',
        Theme(
          data: ThemeData.dark(),
          child: const ColoredBox(
            color: Color(0xFF0A0F1C),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 560,
                child: BentoCard(
                  animationDelay: -1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Resumo da Frota'),
                      StatusBadge(text: 'ATIVO', type: BadgeType.success),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      surfaceSize: const Size(760, 460),
      wrapper: materialAppWrapper(theme: ThemeData.light()),
    );

    await tester.pump(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'goldens/bento_card_temas');
  });
}
