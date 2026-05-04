import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_app/core/data/fleet_data.dart';

/// Cria um veículo mínimo para uso em testes unitários.
VehicleData _makeTestVehicle(String placa) => VehicleData(
      nome: 'Teste $placa',
      placa: placa,
      motorista: 'Motorista Teste',
      telefoneMotorista: '11999999999',
      status: VehicleStatus.emRota,
      mesesEmServico: 12,
      kmPorMes: 2000,
      cor1: Colors.blue,
      cor2: Colors.blueAccent,
      manutencoes: const [],
      vencimentoIPVA: DateTime(2027),
      vencimentoSeguro: DateTime(2027),
      vencimentoLicenciamento: DateTime(2027),
      valorDeMercado: 50000,
      valorAquisicao: 60000,
      dataAquisicao: DateTime(2025),
    );

void main() {
  group('VehicleData', () {
    test('retorna sugestao de venda imediata com custo anual alto', () {
      final vehicle = VehicleData(
        nome: 'Teste',
        placa: 'TST-0001',
        motorista: 'Motorista',
        telefoneMotorista: '11999999999',
        status: VehicleStatus.emRota,
        mesesEmServico: 24,
        kmPorMes: 2000,
        cor1: Colors.blue,
        cor2: Colors.blueAccent,
        manutencoes: [
          MaintenanceEvent(
            data: DateTime(2026),
            tipo: 'Revisao',
            kmNoServico: 10000,
            custo: 50000,
            descricao: 'Manutencao pesada',
          ),
        ],
        vencimentoIPVA: DateTime(2027),
        vencimentoSeguro: DateTime(2027),
        vencimentoLicenciamento: DateTime(2027),
        valorDeMercado: 100000,
        valorAquisicao: 120000,
        dataAquisicao: DateTime(2024),
      );

      expect(
        vehicle.sugestaoVenda,
        'SUGESTÃO: VENDA IMEDIATA (Custo Altíssimo)',
      );
    });

    test('calcula kmParaProxRevisao corretamente', () {
      final vehicle = VehicleData(
        nome: 'Teste',
        placa: 'TST-0002',
        motorista: 'Motorista',
        telefoneMotorista: '11999999999',
        status: VehicleStatus.emRota,
        mesesEmServico: 11,
        kmPorMes: 2500,
        cor1: Colors.green,
        cor2: Colors.greenAccent,
        manutencoes: const [],
        vencimentoIPVA: DateTime(2027),
        vencimentoSeguro: DateTime(2027),
        vencimentoLicenciamento: DateTime(2027),
        valorDeMercado: 90000,
        valorAquisicao: 100000,
        dataAquisicao: DateTime(2025),
      );

      expect(vehicle.kmAtual, closeTo(27500, 0.001));
      expect(vehicle.kmParaProxRevisao, closeTo(2500, 0.001));
    });

    test('calcula lucroAbsoluto sem financiamento', () {
      final vehicle = VehicleData(
        nome: 'Teste',
        placa: 'TST-0003',
        motorista: 'Motorista',
        telefoneMotorista: '11999999999',
        status: VehicleStatus.emRota,
        mesesEmServico: 10,
        kmPorMes: 2000,
        cor1: Colors.orange,
        cor2: Colors.deepOrange,
        manutencoes: [
          MaintenanceEvent(
            data: DateTime(2026),
            tipo: 'Revisao',
            kmNoServico: 10000,
            custo: 500,
            descricao: 'Troca de oleo',
          ),
        ],
        vencimentoIPVA: DateTime(2027),
        vencimentoSeguro: DateTime(2027),
        vencimentoLicenciamento: DateTime(2027),
        valorDeMercado: 80000,
        valorAquisicao: 100000,
        dataAquisicao: DateTime(2025),
      );

      expect(vehicle.receitaTotalAcumulada, closeTo(20000, 0.001));
      expect(vehicle.custoTotalAcumulado, closeTo(500, 0.001));
      expect(vehicle.lucroAbsoluto, closeTo(19500, 0.001));
      expect(vehicle.roi, closeTo(19.5, 0.001));
    });

    test('retorna sugestao segura quando mesesEmServico e zero', () {
      final vehicle = VehicleData(
        nome: 'Teste',
        placa: 'TST-0004',
        motorista: 'Motorista',
        telefoneMotorista: '11999999999',
        status: VehicleStatus.emRota,
        mesesEmServico: 0,
        kmPorMes: 2500,
        cor1: Colors.blue,
        cor2: Colors.blueAccent,
        manutencoes: const [],
        vencimentoIPVA: DateTime(2027),
        vencimentoSeguro: DateTime(2027),
        vencimentoLicenciamento: DateTime(2027),
        valorDeMercado: 90000,
        valorAquisicao: 100000,
        dataAquisicao: DateTime(2025),
      );

      expect(vehicle.sugestaoVenda, 'CARRO SAUDÁVEL (Manter em Frota)');
    });

    test('atualiza status por helper sem mutacao direta', () {
      // Garante que o veículo de teste existe no repositório (independente do Supabase)
      FleetRepository.instance.seedForTest([_makeTestVehicle('VD-1234')]);

      final oldStatus = getVehicleByPlate('VD-1234')!.status;
      final changed = updateVehicleStatus(
        placa: 'VD-1234',
        status: VehicleStatus.emOficina,
      );

      final updatedStatus = getVehicleByPlate('VD-1234')!.status;
      expect(changed, isTrue);
      expect(updatedStatus, VehicleStatus.emOficina);

      // restaura para não vazar estado para outros testes
      updateVehicleStatus(placa: 'VD-1234', status: oldStatus);
    });

    test('FleetRepository notifica ouvintes ao atualizar status', () {
      FleetRepository.instance.seedForTest([_makeTestVehicle('VD-1234')]);

      final repository = FleetRepository.instance;
      final oldStatus = repository.getVehicleByPlate('VD-1234')!.status;
      var notified = false;

      void listener() {
        notified = true;
      }

      repository.addListener(listener);
      final changed = repository.updateVehicleStatus(
        placa: 'VD-1234',
        status: VehicleStatus.emOficina,
      );
      repository.removeListener(listener);

      expect(changed, isTrue);
      expect(notified, isTrue);

      repository.updateVehicleStatus(placa: 'VD-1234', status: oldStatus);
    });

    test('FleetRepository retorna false em placa inexistente', () {
      final repository = FleetRepository.instance;
      final changed = repository.updateVehicleStatus(
        placa: 'XXX-0000',
        status: VehicleStatus.emOficina,
      );

      expect(changed, isFalse);
    });

    test('FleetRepository cadastra motorista e bloqueia telefone duplicado',
        () {
      final repository = FleetRepository.instance;
      final before = repository.motoristas.length;

      final created = repository.addDriver(
        nome: 'Motorista Teste Repo',
        telefone: '(11) 97777-0001',
        vencimentoCNH: DateTime(2030),
      );
      final duplicate = repository.addDriver(
        nome: 'Outro Nome',
        telefone: '(11) 97777-0001',
        vencimentoCNH: DateTime(2031),
      );

      expect(created, isTrue);
      expect(duplicate, isFalse);
      expect(repository.motoristas.length, before + 1);
    });
  });
}
