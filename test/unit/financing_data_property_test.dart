import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/data/fleet_data.dart';

void main() {
  group('FinancingData property tests', () {
    test('invariantes financeiros se mantem em cenarios aleatorios', () {
      final rng = Random(42);

      for (var i = 0; i < 400; i++) {
        final valorTotal = 20000 + rng.nextDouble() * 480000;
        final percentualEntrada = rng.nextDouble() * 0.6;
        final totalParcelas = 1 + rng.nextInt(120);
        final parcelasPagas = rng.nextInt(totalParcelas + 1);
        final recebimentoMensal = 500 + rng.nextDouble() * 14500;
        final taxaJurosMensal = rng.nextDouble() * 0.04;

        final model = FinancingData(
          valorTotal: valorTotal,
          percentualEntrada: percentualEntrada,
          totalParcelas: totalParcelas,
          parcelasPagas: parcelasPagas,
          recebimentoMensal: recebimentoMensal,
          taxaJurosMensal: taxaJurosMensal,
          previsaoQuitacao: 'Teste',
        );

        expect(model.valorParcela.isFinite, isTrue);
        expect(model.valorParcela >= 0, isTrue);
        expect(model.parcelasRestantes, inInclusiveRange(0, totalParcelas));
        expect(model.progressoFinanciamento, inInclusiveRange(0, 1));

        expect(
          model.totalParcelasCompleto,
          closeTo(model.valorParcela * totalParcelas, 0.000001),
        );
        expect(
          model.totalPago + model.totalRestante,
          closeTo(model.totalParcelasCompleto, 0.000001),
        );
      }
    });

    test('parcelas pagas acima do total nao estouram o dominio', () {
      const model = FinancingData(
        valorTotal: 100000,
        percentualEntrada: 0.1,
        totalParcelas: 12,
        parcelasPagas: 50,
        recebimentoMensal: 2500,
        taxaJurosMensal: 0.01,
        previsaoQuitacao: 'Teste',
      );

      expect(model.parcelasRestantes, 0);
      expect(model.progressoFinanciamento, 1);
    });
  });
}
