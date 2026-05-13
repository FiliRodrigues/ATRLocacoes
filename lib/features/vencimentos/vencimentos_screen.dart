import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/fleet_data.dart';
import '../../core/services/relatorio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';

import '../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../core/utils/export_csv_io.dart';

// ═══════════════════════════════════════════════════════════════════════
// Painel de Vencimentos Consolidado
// Agrega IPVA, Seguro, Licenciamento por veículo + CNH por motorista
// Semáforo: ≤7d vermelho · 8–30d amarelo · >30d verde
// ═══════════════════════════════════════════════════════════════════════

enum _VencTipo { ipva, seguro, licenciamento, cnh }

enum _VencStatus { vencido, critico, alerta, ok }

class _VencItem {
  final _VencTipo tipo;
  final String entidade;
  final String subtitulo;
  final DateTime vencimento;
  final _VencStatus status;
  final int diasRestantes;
  final String? recordId;
  final String? statusPagamento;
  final double? valorTotal;
  final String? tableName;

  const _VencItem({
    required this.tipo,
    required this.entidade,
    required this.subtitulo,
    required this.vencimento,
    required this.status,
    required this.diasRestantes,
    this.recordId,
    this.statusPagamento,
    this.valorTotal,
    this.tableName,
  });

  static _VencStatus _calcStatus(int dias) {
    if (dias < 0) return _VencStatus.vencido;
    if (dias <= 7) return _VencStatus.critico;
    if (dias <= 30) return _VencStatus.alerta;
    return _VencStatus.ok;
  }

  factory _VencItem.fromRecord({
    required _VencTipo tipo,
    required Map<String, dynamic> record,
    required String entidade,
    required String subtitulo,
  }) {
    final vencimento = DateTime.tryParse((record['data_vencimento'] ?? '').toString()) ?? DateTime.now();
    final hoje = DateTime.now();
    final dias = vencimento.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
    return _VencItem(
      tipo: tipo,
      entidade: entidade,
      subtitulo: subtitulo,
      vencimento: vencimento,
      status: _calcStatus(dias),
      diasRestantes: dias,
      recordId: record['id'] as String?,
      statusPagamento: (record['status_pagamento'] as String?) ?? 'Pendente',
      valorTotal: (record['valor_total'] as num?)?.toDouble(),
      tableName: switch (tipo) {
        _VencTipo.ipva => 'ipva',
        _VencTipo.licenciamento => 'licenciamento',
        _VencTipo.seguro => 'seguros',
        _VencTipo.cnh => 'motoristas',
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

enum _Filtro { todos, critico, alerta, ok }

class VencimentosScreen extends StatefulWidget {
  const VencimentosScreen({super.key});

  @override
  State<VencimentosScreen> createState() => _VencimentosScreenState();
}

class _VencimentosScreenState extends State<VencimentosScreen> {
  _Filtro _filtro = _Filtro.todos;
  List<_VencItem> _dbItems = [];

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _fetchDbRecords();
  }

  Future<void> _fetchDbRecords() async {
    final tenantId = Supabase.instance.client.auth.currentUser
        ?.appMetadata['tenant_id'] as String?;
    if (tenantId == null) return;
    final results = await Future.wait([
      Supabase.instance.client
          .from('ipva')
          .select('id, veiculo_id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento')
          .eq('tenant_id', tenantId)
          .order('data_vencimento', ascending: true),
      Supabase.instance.client
          .from('licenciamento')
          .select('id, veiculo_id, ano_referencia, valor_total, data_vencimento, data_pagamento, status_pagamento')
          .eq('tenant_id', tenantId)
          .order('data_vencimento', ascending: true),
      Supabase.instance.client
          .from('seguros')
          .select('id, veiculo_id, ano_referencia, valor_apolice, data_renovacao, status_pagamento, veiculos(placa, marca, modelo)')
          .eq('tenant_id', tenantId)
          .order('data_renovacao', ascending: true),
      Supabase.instance.client
          .from('motoristas')
          .select('id, nome, vencimento_cnh, status_cnh')
          .eq('tenant_id', tenantId)
          .order('nome', ascending: true),
    ]);
    final ipvaRows = results[0] as List<dynamic>;
    final licRows = results[1] as List<dynamic>;
    final seguroRows = results[2] as List<dynamic>;
    final motoristaRows = results[3] as List<dynamic>;

    // Mapa veiculo_id -> {placa, nome} para ipva e licenciamento
    final veiculoIds = <String>{};
    for (final r in [...ipvaRows, ...licRows]) {
      veiculoIds.add(r['veiculo_id'] as String);
    }
    final veiculoMap = <String, Map<String, String>>{};
    if (veiculoIds.isNotEmpty) {
      final veicRows = await Supabase.instance.client
          .from('veiculos')
          .select('id, placa, marca, modelo')
          .inFilter('id', veiculoIds.toList())
          .eq('tenant_id', tenantId);
      for (final v in veicRows) {
        final marca = (v['marca'] as String? ?? '').trim();
        final modelo = (v['modelo'] as String? ?? '').trim();
        veiculoMap[v['id'] as String] = {
          'placa': (v['placa'] as String? ?? '').trim(),
          'nome': '$marca $modelo'.trim(),
        };
      }
    }
    if (!mounted) return;
    setState(() {
      _dbItems = [
        for (final r in ipvaRows)
          _VencItem.fromRecord(
            tipo: _VencTipo.ipva,
            record: r as Map<String, dynamic>,
            entidade: veiculoMap[r['veiculo_id'] as String]?['placa'] ?? '?',
            subtitulo: '${veiculoMap[r['veiculo_id'] as String]?['nome'] ?? '?'} | IPVA ${r['ano_referencia']}',
          ),
        for (final r in licRows)
          _VencItem.fromRecord(
            tipo: _VencTipo.licenciamento,
            record: r as Map<String, dynamic>,
            entidade: veiculoMap[r['veiculo_id'] as String]?['placa'] ?? '?',
            subtitulo: '${veiculoMap[r['veiculo_id'] as String]?['nome'] ?? '?'} | Licenciamento ${r['ano_referencia']}',
          ),
        for (final r in seguroRows)
          _buildSeguroItem(r as Map<String, dynamic>),
        for (final r in motoristaRows)
          _buildCnhItem(r as Map<String, dynamic>),
      ];
    });
  }

  _VencItem _buildSeguroItem(Map<String, dynamic> r) {
    final veiculo = r['veiculos'] as Map<String, dynamic>?;
    final placa = (veiculo?['placa'] as String? ?? '').trim();
    final marca = (veiculo?['marca'] as String? ?? '').trim();
    final modelo = (veiculo?['modelo'] as String? ?? '').trim();
    final nome = '$marca $modelo'.trim();
    final vencimento = DateTime.tryParse((r['data_renovacao'] ?? '').toString()) ?? DateTime.now();
    final hoje = DateTime.now();
    final dias = vencimento.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
    return _VencItem(
      tipo: _VencTipo.seguro,
      entidade: placa.isNotEmpty ? placa : '?',
      subtitulo: '${nome.isNotEmpty ? nome : '?'} | Seguro ${r['ano_referencia']}',
      vencimento: vencimento,
      status: _VencItem._calcStatus(dias),
      diasRestantes: dias,
      recordId: r['id'] as String?,
      statusPagamento: (r['status_pagamento'] as String?) ?? 'Pendente',
      valorTotal: (r['valor_apolice'] as num?)?.toDouble(),
      tableName: 'seguros',
    );
  }

  _VencItem _buildCnhItem(Map<String, dynamic> r) {
    final vencimento = DateTime.tryParse((r['vencimento_cnh'] ?? '').toString()) ?? DateTime.now();
    final hoje = DateTime.now();
    final dias = vencimento.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
    return _VencItem(
      tipo: _VencTipo.cnh,
      entidade: (r['nome'] as String? ?? '').trim(),
      subtitulo: 'CNH',
      vencimento: vencimento,
      status: _VencItem._calcStatus(dias),
      diasRestantes: dias,
      tableName: 'motoristas',
    );
  }

  Future<void> _togglePayment(_VencItem item) async {
    final novoStatus = item.statusPagamento == 'Pago' ? 'Pendente' : 'Pago';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.statusPagamento == 'Pago' ? 'Marcar como Pendente?' : 'Marcar como Pago?'),
        content: Text('Deseja alterar o status de ${item.entidade} — ${item.subtitulo} para $novoStatus?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;
    final tableName = item.tableName;
    final recordId = item.recordId;
    if (tableName == null || recordId == null) return;

    final updates = <String, dynamic>{'status_pagamento': novoStatus};
    final dataField = switch (tableName) {
      'seguros' => 'data_renovacao',
      'motoristas' => 'vencimento_cnh',
      _ => 'data_pagamento',
    };
    if (novoStatus == 'Pago') {
      updates[dataField] = DateTime.now().toIso8601String();
    } else {
      updates[dataField] = null;
    }
    await Supabase.instance.client.from(tableName).update(updates).eq('id', recordId);
    await _fetchDbRecords();
  }

  List<_VencItem> _buildItens() {
    final itens = <_VencItem>[];
    itens.addAll(_dbItems);
    itens.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));
    return itens;
  }

  List<_VencItem> _aplicarFiltro(List<_VencItem> todos) {
    return switch (_filtro) {
      _Filtro.todos => todos,
      _Filtro.critico =>
        todos.where((e) => e.status == _VencStatus.vencido || e.status == _VencStatus.critico).toList(),
      _Filtro.alerta => todos.where((e) => e.status == _VencStatus.alerta).toList(),
      _Filtro.ok => todos.where((e) => e.status == _VencStatus.ok).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todos = _buildItens();
    final filtrados = _aplicarFiltro(todos);

    final nVencido = todos.where((e) => e.status == _VencStatus.vencido).length;
    final nCritico = todos.where((e) => e.status == _VencStatus.critico).length;
    final nAlerta = todos.where((e) => e.status == _VencStatus.alerta).length;
    final nOk = todos.where((e) => e.status == _VencStatus.ok).length;

    return AppSidebar(
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: Column(
            children: [
              _buildHeader(context, isDark, nVencido + nCritico, todos),
              _buildSummaryRow(isDark, nVencido, nCritico, nAlerta, nOk, total: todos.length),
              _buildFilterBar(isDark, nVencido, nCritico, nAlerta, nOk),
              Expanded(
                child: filtrados.isEmpty
                    ? _buildEmpty(isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _VencCard(
                          item: filtrados[i],
                          isDark: isDark,
                          dateFmt: _dateFmt,
                          onTogglePayment: filtrados[i].recordId != null
                              ? () => _togglePayment(filtrados[i])
                              : null,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tipoLabel(_VencTipo tipo) => switch (tipo) {
        _VencTipo.ipva => 'IPVA',
        _VencTipo.seguro => 'Seguro',
        _VencTipo.licenciamento => 'Licenciamento',
        _VencTipo.cnh => 'CNH',
      };

  String _statusLabel(_VencItem e) {
    if (e.status == _VencStatus.vencido) return 'VENCIDO ha ${e.diasRestantes.abs()}d';
    if (e.status == _VencStatus.critico) return 'CRITICO - ${e.diasRestantes}d';
    if (e.status == _VencStatus.alerta) return 'Atencao - ${e.diasRestantes}d';
    return 'OK - ${e.diasRestantes}d';
  }

  Future<void> _exportPdf(List<_VencItem> itens) async {
    final rows = itens.map((e) => VencimentoPdfRow(
      tipo: _tipoLabel(e.tipo),
      entidade: e.entidade,
      subtitulo: e.subtitulo,
      vencimento: e.vencimento,
      diasRestantes: e.diasRestantes,
      valorTotal: e.valorTotal,
      statusPagamento: e.statusPagamento ?? '',
      status: _statusLabel(e),
    )).toList();

    try {
      final bytes = await RelatorioService.gerarPdfVencimentos(rows);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'vencimentos_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(List<_VencItem> itens) async {
    final buffer = StringBuffer();
    buffer.writeln(
      '"TIPO";"ENTIDADE";"SUBTITULO";"VENCIMENTO";"DIAS";"VALOR";"STATUS PGTO";"STATUS"',
    );

    for (final e in itens) {
      final valorStr = e.valorTotal != null
          ? e.valorTotal!.toStringAsFixed(2).replaceAll('.', ',')
          : '';
      buffer.writeln(
        '${_csvField(_tipoLabel(e.tipo))};${_csvField(e.entidade)};${_csvField(e.subtitulo)};${_csvField(_dateFmt.format(e.vencimento))};${_csvField(e.diasRestantes.toString())};${_csvField(valorStr)};${_csvField(e.statusPagamento ?? '')};${_csvField(_statusLabel(e))}',
      );
    }

    try {
      final fileName =
          'vencimentos_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportCsv(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exportado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Widget _buildHeader(BuildContext context, bool isDark, int nUrgentes, List<_VencItem> todos) {
    return AtrTopBar(
      title: 'Painel de Vencimentos',
      subtitle: 'IPVA · Seguro · Licenciamento · CNH — tudo em um só lugar',
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'csv') {
              _exportCsv(todos);
            } else if (value == 'pdf') {
              _exportPdf(todos);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'csv',
              child: Row(
                children: [
                  Icon(LucideIcons.fileSpreadsheet, size: 16),
                  SizedBox(width: 8),
                  Text('Exportar CSV'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(LucideIcons.fileText, size: 16),
                  SizedBox(width: 8),
                  Text('Exportar PDF'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.download,
                    size: 16, color: AppColors.textSecondaryLight),
                SizedBox(width: 8),
                Text(
                  'Exportar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (nUrgentes > 0 ? AppColors.statusError : AppColors.statusSuccess)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                LucideIcons.calendarClock,
                color: nUrgentes > 0 ? AppColors.statusError : AppColors.statusSuccess,
                size: 24,
              ),
            ),
            if (nUrgentes > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.statusError,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    '$nUrgentes',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    bool isDark,
    int nVencido,
    int nCritico,
    int nAlerta,
    int nOk, {
    required int total,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Vencidos',
              count: nVencido,
              color: AppColors.statusError,
              icon: LucideIcons.xCircle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Críticos (≤7d)',
              count: nCritico,
              color: Colors.deepOrange,
              icon: LucideIcons.alertTriangle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Atenção (≤30d)',
              count: nAlerta,
              color: AppColors.statusWarning,
              icon: LucideIcons.alertCircle,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Em dia',
              count: nOk,
              color: AppColors.statusSuccess,
              icon: LucideIcons.checkCircle2,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, int nVencido, int nCritico, int nAlerta, int nOk) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(_Filtro.todos, 'Todos', null, isDark),
            const SizedBox(width: 8),
            _filterChip(_Filtro.critico, 'Urgentes', nVencido + nCritico > 0 ? nVencido + nCritico : null, isDark,
                activeColor: AppColors.statusError),
            const SizedBox(width: 8),
            _filterChip(_Filtro.alerta, 'Atenção', nAlerta > 0 ? nAlerta : null, isDark,
                activeColor: AppColors.statusWarning),
            const SizedBox(width: 8),
            _filterChip(_Filtro.ok, 'Em dia', null, isDark, activeColor: AppColors.statusSuccess),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    _Filtro filtro,
    String label,
    int? count,
    bool isDark, {
    Color? activeColor,
  }) {
    final selected = _filtro == filtro;
    final color = activeColor ?? AppColors.atrOrange;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      selectedColor: color,
      onSelected: (_) => setState(() => _filtro = filtro),
      labelStyle: TextStyle(color: selected ? Colors.white : null),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendarCheck,
              size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            'Nenhum item neste filtro',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tile de resumo numérico
// ─────────────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: count > 0 ? color : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Card individual de vencimento
// ─────────────────────────────────────────────────────────────────────

class _VencCard extends StatelessWidget {
  final _VencItem item;
  final bool isDark;
  final DateFormat dateFmt;
  final VoidCallback? onTogglePayment;

  const _VencCard({required this.item, required this.isDark, required this.dateFmt, this.onTogglePayment});

  @override
  Widget build(BuildContext context) {
    final (icon, tipoLabel) = _tipoInfo(item.tipo);
    final (statusColor, statusLabel) = _statusInfo(item);
    final isPaymentRecord = item.recordId != null;
    final pago = item.statusPagamento == 'Pago';
    final paymentColor = pago ? AppColors.statusSuccess : AppColors.statusWarning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.entidade,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tipoLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.valorTotal != null)
                Text(
                  formatCurrency(item.valorTotal!),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              Text(
                dateFmt.format(item.vencimento),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: item.valorTotal != null ? AppColors.textSecondaryDark : null,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPaymentRecord) ...[
                    GestureDetector(
                      onTap: onTogglePayment,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: paymentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: paymentColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item.statusPagamento!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: paymentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, String) _tipoInfo(_VencTipo tipo) => switch (tipo) {
        _VencTipo.ipva => (LucideIcons.receipt, 'IPVA'),
        _VencTipo.seguro => (LucideIcons.shieldCheck, 'Seguro'),
        _VencTipo.licenciamento => (LucideIcons.clipboardList, 'Licenciamento'),
        _VencTipo.cnh => (LucideIcons.creditCard, 'CNH'),
      };

  (Color, String) _statusInfo(_VencItem e) {
    if (e.status == _VencStatus.vencido) {
      return (AppColors.statusError, 'VENCIDO há ${e.diasRestantes.abs()}d');
    }
    if (e.status == _VencStatus.critico) {
      return (Colors.deepOrange, 'CRÍTICO — ${e.diasRestantes}d');
    }
    if (e.status == _VencStatus.alerta) {
      return (AppColors.statusWarning, 'Atenção — ${e.diasRestantes}d');
    }
    return (AppColors.statusSuccess, '${e.diasRestantes}d restantes');
  }
}
