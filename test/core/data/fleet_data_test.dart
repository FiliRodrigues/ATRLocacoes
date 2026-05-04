import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/data/fleet_data.dart';

void main() {
  group('VehicleData', () {
    test('calcula kmAtual corretamente', () {
      final vehicle = VehicleData(
        nome: 'Test Car',
        placa: 'ABC-1234',
        motorista: 'João',
        telefoneMotorista: '(11) 99999-9999',
        status: VehicleStatus.emRota,
        mesesEmServico: 12,
        kmPorMes: 1000,
        cor1: const Color(0xFF000000),
        cor2: const Color(0xFF000000),
        manutencoes: [],
        vencimentoIPVA: DateTime(2026, 12, 31),
        vencimentoSeguro: DateTime(2026, 12, 31),
        vencimentoLicenciamento: DateTime(2026, 12, 31),
        valorDeMercado: 50000,
        valorAquisicao: 60000,
        dataAquisicao: DateTime(2025, 4, 7),
      );

      expect(vehicle.kmAtual, 12000);
    });

    test('calcula custoTotalManutencao corretamente', () {
      final vehicle = VehicleData(
        nome: 'Test Car',
        placa: 'ABC-1234',
        motorista: 'João',
        telefoneMotorista: '(11) 99999-9999',
        status: VehicleStatus.emRota,
        mesesEmServico: 12,
        kmPorMes: 1000,
        cor1: const Color(0xFF000000),
        cor2: const Color(0xFF000000),
        manutencoes: [
          MaintenanceEvent(
            data: DateTime(2025),
            tipo: 'Revisão',
            kmNoServico: 10000,
            custo: 500,
            descricao: 'Teste',
          ),
          MaintenanceEvent(
            data: DateTime(2025, 6),
            tipo: 'Troca',
            kmNoServico: 20000,
            custo: 300,
            descricao: 'Teste 2',
          ),
        ],
        vencimentoIPVA: DateTime(2026, 12, 31),
        vencimentoSeguro: DateTime(2026, 12, 31),
        vencimentoLicenciamento: DateTime(2026, 12, 31),
        valorDeMercado: 50000,
        valorAquisicao: 60000,
        dataAquisicao: DateTime(2025, 4, 7),
      );

      expect(vehicle.custoTotalManutencao, 800);
      expect(vehicle.totalRevisoes, 2);
    });
  });

  group('FinancingData', () {
    test('calcula valorParcela corretamente', () {
      const financing = FinancingData(
        valorTotal: 100000,
        percentualEntrada: 0.2,
        totalParcelas: 60,
        parcelasPagas: 12,
        recebimentoMensal: 2000,
        taxaJurosMensal: 0.01,
        previsaoQuitacao: '2030',
      );

      expect(financing.valorEntrada, 20000);
      expect(financing.valorFinanciado, 80000);
      expect(financing.parcelasRestantes, 48);
      expect(financing.totalPago, closeTo(financing.valorParcela * 12, 1));
    });
  });

  group('Helpers', () {
    setUp(() {
      // Seed estático para testes de getVehicleByPlate (independente do Supabase)
      FleetRepository.instance.seedForTest([
        VehicleData(
          nome: 'Toyota Corolla XEi 2.0',
          placa: 'VD-1234',
          motorista: 'Motorista Teste',
          telefoneMotorista: '11999999999',
          status: VehicleStatus.emRota,
          mesesEmServico: 24,
          kmPorMes: 2000,
          cor1: const Color(0xFF000000),
          cor2: const Color(0xFF000000),
          manutencoes: const [],
          vencimentoIPVA: DateTime(2027),
          vencimentoSeguro: DateTime(2027),
          vencimentoLicenciamento: DateTime(2027),
          valorDeMercado: 80000,
          valorAquisicao: 95000,
          dataAquisicao: DateTime(2024),
        ),
      ]);
    });

    tearDown(() {
      FleetRepository.instance.seedForTest([]);
    });

    test('formatCurrency funciona', () {
      expect(formatCurrency(1234.56), 'R\$ 1.234,56');
      expect(formatCurrency(-500), '-R\$ 500,00');
    });

    test('formatKm funciona', () {
      expect(formatKm(1234.0), '1.234 km');
    });

    test('getVehicleByPlate funciona', () {
      final vehicle = getVehicleByPlate('VD-1234');
      expect(vehicle?.placa, 'VD-1234');
      expect(vehicle?.nome, 'Toyota Corolla XEi 2.0');
    });

    test('getVehicleByPlate retorna null para placa inexistente', () {
      final vehicle = getVehicleByPlate('INVALID');
      expect(vehicle, null);
    });
  });
}