import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../enums/vehicle_status.dart';
import '../enums/cnh_status.dart';
import '../enums/alert_type.dart';
import '../enums/event_type.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import 'fleet_models.dart';
import 'fleet_formatting.dart';
import 'fleet_cache.dart';

// Re-exporta tudo para manter compatibilidade com imports existentes
export '../enums/vehicle_status.dart';
export '../enums/cnh_status.dart';
export '../enums/alert_type.dart';
export '../enums/event_type.dart';
export 'fleet_models.dart';
export 'fleet_formatting.dart';

// ═══════════════════════════════════════════════════════
// GLOBAIS — delegam para FleetRepository
// ═══════════════════════════════════════════════════════

List<VehicleData> get frota => FleetRepository.instance.frota;
List<DriverData> get motoristas => FleetRepository.instance.motoristas;
List<MonthlyData> get dadosMensais => FleetRepository.instance.dadosMensais;
List<AlertItem> get frotaAlertas => FleetRepository.instance.frotaAlertas;
List<UpcomingEvent> get proximosEventos => FleetRepository.instance.proximosEventos;
List<VehicleData> get veiculosFinanciados => FleetRepository.instance.veiculosFinanciados;

VehicleData? getVehicleByPlate(String placa) => FleetRepository.instance.getVehicleByPlate(placa);
List<VehicleData> getVehiclesByDriver(String nome) => FleetRepository.instance.getVehiclesByDriver(nome);

Future<bool> updateVehicleStatus({required String placa, required VehicleStatus status}) =>
    FleetRepository.instance.updateVehicleStatus(placa: placa, status: status);

// ═══════════════════════════════════════════════════════
// FLEET REPOSITORY (ChangeNotifier — Provider)
// ═══════════════════════════════════════════════════════

class FleetRepository extends ChangeNotifier {
  FleetRepository._() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(loadFromSupabase());
      }
      if (data.event == AuthChangeEvent.signedOut) {
        _realtimeChannel?.unsubscribe();
        _realtimeChannel = null;
        _refreshTimer?.cancel();
        _refreshTimer = null;
        _frota.clear();
        notifyListeners();
      }
    });
  }

  static final FleetRepository instance = FleetRepository._();

  final List<VehicleData> _frota = [];
  final List<DriverData> _motoristas = [];
  final List<MonthlyData> _dadosMensais = [];
  final List<KmRegistro> _kmHistorico = [];
  List<AlertItem>? _cachedAlertas;
  int _version = 0;
  bool _isLoading = false;
  Future<void>? _loadFuture;
  String? _loadError;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Carrega a frota do Supabase, substituindo todos os dados locais.
  Future<void> loadFromSupabase() {
    _loadFuture ??= _doLoad().whenComplete(() => _loadFuture = null);
    return _loadFuture!;
  }

  Future<void> _doLoad() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final veiculos = await FleetSupabaseService.fetchVehicles();
      _frota
        ..clear()
        ..addAll(veiculos);
      _motoristas.clear();
      _recomputeDadosMensais();
      // Salva no cache offline após load bem-sucedido
      unawaited(FleetCache.saveFrota(List.unmodifiable(_frota)));
      if (_realtimeChannel == null) {
        _subscribeRealtime();
      }
      if (_refreshTimer == null) {
        _startPeriodicRefresh();
      }
    } catch (e, s) {
      _loadError = e.toString();
      assert(() { debugPrint('[ATR] loadFromSupabase ERRO: $e\n$s'); return true; }());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('atr-fleet-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'manutencoes',
          callback: (_) => unawaited(loadFromSupabase()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'veiculos',
          callback: (_) => unawaited(loadFromSupabase()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'despesas',
          callback: (_) => unawaited(loadFromSupabase()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'financiamentos',
          callback: (_) => unawaited(loadFromSupabase()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parcelas_financiamento',
          callback: (_) => unawaited(loadFromSupabase()),
        )
        .subscribe();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => unawaited(loadFromSupabase()),
    );
  }

  List<KmRegistro> get kmHistorico => List.unmodifiable(_kmHistorico);

  List<KmRegistro> kmHistoricoVeiculo(String placa) => _kmHistorico
      .where((r) => r.placa == placa)
      .toList()
    ..sort((a, b) => b.data.compareTo(a.data));

  int get version => _version;

  static const _months = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  void _recomputeDadosMensais() {
    _dadosMensais.clear();
    final now = DateTime.now();
    for (int offset = -6; offset <= 5; offset++) {
      final d = DateTime(now.year, now.month + offset);
      final mLabel = '${_months[d.month - 1]}/${(d.year % 100).toString().padLeft(2, '0')}';

      double receita = 0;
      double financiamento = 0;
      double manutencao = 0;

      for (final v in _frota) {
        final f = v.financiamento;
        if (f != null) {
          final realDoMes = f.recebidoNoMes(d.year, d.month);
          if (realDoMes != null && realDoMes > 0) {
            receita += realDoMes;
          } else if (f.recebimentoMensal > 0) {
            receita += f.recebimentoMensal;
          }
          financiamento += f.valorParcela;
        }
        manutencao += v.manutencoes
            .where((m) => m.data.month == d.month && m.data.year == d.year)
            .fold(0.0, (s, m) => s + m.custo);
      }

      _dadosMensais.add(MonthlyData(
        mes: mLabel,
        receita: receita,
        financiamento: financiamento,
        manutencao: manutencao,
      ));
    }
  }

  /// Popula o repositório com dados do cache offline antes do primeiro load do Supabase.
  void seedFromCache(List<VehicleData> vehicles) {
    if (_frota.isNotEmpty) return; // já carregado, não sobrescreve
    _frota.addAll(vehicles);
    _recomputeDadosMensais();
    notifyListeners();
  }

  @visibleForTesting
  void seedForTest(List<VehicleData> vehicles,
      {List<DriverData> drivers = const []}) {
    _frota
      ..clear()
      ..addAll(vehicles);
    _motoristas
      ..clear()
      ..addAll(drivers);
    _cachedAlertas = null;
  }

  @override
  void notifyListeners() {
    _version++;
    _cachedAlertas = null;
    super.notifyListeners();
  }

  List<VehicleData> get frota => List.unmodifiable(_frota);
  List<DriverData> get motoristas => List.unmodifiable(_motoristas);
  List<MonthlyData> get dadosMensais => List.unmodifiable(_dadosMensais);

  List<VehicleData> get veiculosFinanciados =>
      _frota.where((v) => v.isFinanciado).toList();

  VehicleData? getVehicleByPlate(String placa) {
    try {
      return _frota.firstWhere((v) => v.placa == placa);
    } catch (e) {
      AppLogger.warning('FleetRepository.getVehicleByPlate falhou para "$placa": $e');
      return null;
    }
  }

  List<VehicleData> getVehiclesByDriver(String nome) =>
      _frota.where((v) => v.motorista == nome).toList();

  bool addDriver({
    required String nome,
    required String telefone,
    required DateTime vencimentoCNH,
    int multas = 0,
    List<String> placasVeiculos = const <String>[],
  }) {
    final normalizedName = nome.trim();
    final normalizedPhone = telefone.trim();
    if (normalizedName.isEmpty || normalizedPhone.isEmpty) return false;

    final alreadyExists = _motoristas.any(
      (d) => d.telefone == normalizedPhone,
    );
    if (alreadyExists) return false;

    final hoje = DateTime.now();
    final daysToExpiry = vencimentoCNH.difference(hoje).inDays;
    final status = daysToExpiry < 0
        ? CnhStatus.vencida
        : (daysToExpiry <= 60 ? CnhStatus.vencendo : CnhStatus.ok);

    _motoristas.add(
      DriverData(
        nome: normalizedName,
        telefone: normalizedPhone,
        vencimentoCNH: vencimentoCNH,
        statusCNH: status,
        multas: max(multas, 0),
        placasVeiculos: placasVeiculos,
      ),
    );
    notifyListeners();
    return true;
  }

  Future<bool> updateVehicleStatus({
    required String placa,
    required VehicleStatus status,
  }) async {
    final index = _frota.indexWhere((v) => v.placa == placa);
    if (index == -1) return false;
    const map = {
      VehicleStatus.emRota: 'Operando ATR',
      VehicleStatus.reserva: 'Locado',
      VehicleStatus.emOficina: 'Em manutenção',
      VehicleStatus.parado: 'Parado',
    };
    try {
      await FleetSupabaseService.updateVehicleStatus(
        placa: placa,
        novasSituacao: map[status]!,
        alteradoPor: Supabase.instance.client.auth.currentUser?.email ?? 'sistema',
      );
    } catch (e) {
      AppLogger.error('FleetRepository.updateVehicleStatus falhou para "$placa"', e);
      return false;
    }
    _frota[index] = _frota[index].copyWith(status: status);
    notifyListeners();
    return true;
  }

  Future<String?> addVehicle({
    required String placa,
    required String modelo,
    required int ano,
    required String locadora,
    double kmPorMes = 3000,
    double? kmHodometro,
    String status = 'disponivel',
    double? valorVeiculo,
  }) async {
    try {
      final tenantId = Supabase.instance.client.auth.currentUser
          ?.appMetadata['tenant_id'] as String?;
      final insert = <String, dynamic>{
        'placa': placa.toUpperCase(),
        'modelo': modelo,
        'ano_fabricacao_modelo': ano.toString(),
        'km_inicial': kmHodometro?.toInt() ?? 0,
        'situacao_operacional': status,
        'tenant_id': tenantId,
        'data_compra': DateTime.now().toIso8601String(),
      };
      if (valorVeiculo != null) insert['valor_veiculo'] = valorVeiculo;
      final response = await Supabase.instance.client
          .from('veiculos')
          .insert(insert)
          .select('id')
          .single();
      await loadFromSupabase();
      return response['id'] as String?;
    } catch (e) {
      _loadError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> editVehicle({
    required String placa,
    String? novoModelo,
    int? novoAno,
    String? novaLocadora,
    double? kmPorMes,
    double? kmHodometro,
    double? valorVeiculo,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (novoModelo != null) updates['modelo'] = novoModelo;
      if (novoAno != null) updates['ano_fabricacao_modelo'] = novoAno.toString();
      if (kmHodometro != null) updates['km_atual'] = kmHodometro.toInt();
      if (valorVeiculo != null) updates['valor_veiculo'] = valorVeiculo;
      if (updates.isEmpty) return true;
      await Supabase.instance.client
          .from('veiculos')
          .update(updates)
          .eq('placa', placa);
      await loadFromSupabase();
      return true;
    } catch (e) {
      _loadError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteVehicle(String placa) async {
    try {
      await Supabase.instance.client
          .from('veiculos')
          .update({'situacao_operacional': 'Inativo'})
          .eq('placa', placa);
      await loadFromSupabase();
      return true;
    } catch (e) {
      _loadError = e.toString();
      notifyListeners();
      return false;
    }
  }

  bool updateVehicleKm({
    required String placa,
    required double km,
  }) {
    final index = _frota.indexWhere((v) => v.placa == placa);
    if (index == -1) return false;
    _frota[index] = _frota[index].copyWith(
      kmHodometro: km,
      ultimaAtualizacaoKm: DateTime.now(),
    );
    _kmHistorico.add(
      KmRegistro(placa: placa, km: km, data: DateTime.now()),
    );
    notifyListeners();
    return true;
  }

  List<AlertItem> get frotaAlertas {
    if (_cachedAlertas != null) return _cachedAlertas!;
    final a = <AlertItem>[];
    final hoje = DateTime.now();

    for (final d in _motoristas) {
      if (d.statusCNH == CnhStatus.vencida) {
        a.add(AlertItem(
          tipo: AlertType.danger,
          titulo: 'CNH Vencida',
          mensagem: '${d.nome} - CNH vencida em ${formatDate(d.vencimentoCNH)}. Regularizar imediatamente.',
        ));
      }
      if (d.statusCNH == CnhStatus.vencendo) {
        a.add(AlertItem(
          tipo: AlertType.warning,
          titulo: 'CNH Vencendo',
          mensagem: '${d.nome} - CNH vence em ${formatDate(d.vencimentoCNH)}. Agendar renovação.',
        ));
      }
    }

    for (final v in _frota) {
      if (v.kmParaProxRevisao < 2000) {
        a.add(AlertItem(
          tipo: AlertType.warning,
          titulo: 'Revisão Próxima',
          mensagem: '${v.placa} (${v.nome}) - Faltam ${formatKm(v.kmParaProxRevisao)} para próxima revisão.',
        ));
      }
      if (v.vencimentoSeguro.isBefore(hoje.add(const Duration(days: 15)))) {
        a.add(AlertItem(
          tipo: AlertType.danger,
          titulo: 'Seguro Expirando',
          mensagem: '${v.placa} - Seguro vence em ${formatDate(v.vencimentoSeguro)}. Renovação Urgente!',
        ));
      }
      if (v.vencimentoIPVA.isBefore(hoje.add(const Duration(days: 20)))) {
        a.add(AlertItem(
          tipo: AlertType.warning,
          titulo: 'IPVA Próximo',
          mensagem: '${v.placa} - IPVA vence em ${formatDate(v.vencimentoIPVA)}. Verificar pagamento.',
        ));
      }
    }

    for (final v in _frota.where((v) => v.isFinanciado)) {
      if (v.financiamento!.parcelasRestantes <= 7) {
        a.add(AlertItem(
          tipo: AlertType.info,
          titulo: 'Quitação Próxima',
          mensagem: '${v.placa} - Faltam apenas ${v.financiamento!.parcelasRestantes} parcelas. Previsão: ${v.financiamento!.previsaoQuitacao}.',
        ));
      }
    }
    for (final d in _motoristas) {
      if (d.multas > 0) {
        a.add(AlertItem(
          tipo: AlertType.warning,
          titulo: 'Multas Pendentes',
          mensagem: '${d.nome} - ${d.multas} multa(s) pendente(s).',
        ));
      }
    }
    _cachedAlertas = a;
    return a;
  }

  List<UpcomingEvent> get proximosEventos {
    final e = <UpcomingEvent>[];
    final sorted = [..._frota]
      ..sort((a, b) => a.kmParaProxRevisao.compareTo(b.kmParaProxRevisao));
    for (final v in sorted.take(3)) {
      final meses = (v.kmParaProxRevisao / v.kmPorMes).toStringAsFixed(1);
      e.add(UpcomingEvent(
        titulo: 'Revisão ${v.placa}',
        descricao: '${v.nome} - ~${formatKm(v.kmParaProxRevisao)} restantes',
        prazo: '~$meses meses',
        tipo: EventType.maintenance,
      ));
    }

    for (final v in _frota.where((v) => v.isFinanciado)) {
      e.add(UpcomingEvent(
        titulo: 'Parcela ${v.financiamento!.parcelasPagas + 1}/${v.financiamento!.totalParcelas}',
        descricao: '${v.placa} - ${formatCurrency(v.financiamento!.valorParcela)}',
        prazo: 'Este mês',
        tipo: EventType.payment,
      ));
    }
    return e;
  }
}
