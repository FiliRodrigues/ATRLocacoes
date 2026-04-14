import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/data/fleet_data.dart';

void main() {
  group('FinancingData', () {
    const financing = FinancingData(
      valorTotal: 100000,
      percentualEntrada: 0.2,
      totalParcelas: 48,
      parcelasPagas: 12,
      recebimentoMensal: 3000,
      taxaJurosMensal: 0.01,
      previsaoQuitacao: 'Jan/2030',
    );

    test('calcula valorParcela com sistema Price', () {
      expect(financing.valorParcela, closeTo(2106.7068, 0.0001));
    });

    test('calcula totalJuros como total pago - principal', () {
      expect(financing.totalJuros, closeTo(21121.9281, 0.0001));
    });

    test('calcula progressoFinanciamento corretamente', () {
      expect(financing.progressoFinanciamento, closeTo(0.25, 0.0001));
    });

    test('calcula saldoMensal corretamente', () {
      expect(financing.saldoMensal, closeTo(893.2932, 0.0001));
    });

    test('calcula parcela linear quando taxa de juros e zero', () {
      const noInterest = FinancingData(
        valorTotal: 100000,
        percentualEntrada: 0.2,
        totalParcelas: 40,
        parcelasPagas: 5,
        recebimentoMensal: 3000,
        taxaJurosMensal: 0,
        previsaoQuitacao: 'Jan/2030',
      );

      expect(noInterest.valorParcela, closeTo(2000, 0.0001));
    });

    test('nao quebra com totalParcelas invalido', () {
      const invalidInstallments = FinancingData(
        valorTotal: 100000,
        percentualEntrada: 0.2,
        totalParcelas: 0,
        parcelasPagas: 0,
        recebimentoMensal: 3000,
        taxaJurosMensal: 0.01,
        previsaoQuitacao: 'N/A',
      );

      expect(invalidInstallments.valorParcela, 0);
      expect(invalidInstallments.progressoFinanciamento, 0);
    });
  });
}
