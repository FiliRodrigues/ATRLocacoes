import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/data/locacao_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'locacao_provider.dart';
import 'widgets/checklist_form_sheet.dart';
import 'widgets/ocorrencia_form_sheet.dart';
import 'widgets/contrato_form_sheet.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFmt = DateFormat('dd/MM/yyyy');
final _datetimeFmt = DateFormat('dd/MM/yyyy HH:mm');

class ContratoDetalheScreen extends StatefulWidget {
  final String contratoId;
  const ContratoDetalheScreen({super.key, required this.contratoId});

  @override
  State<ContratoDetalheScreen> createState() => _ContratoDetalheScreenState();
}

class _ContratoDetalheScreenState extends State<ContratoDetalheScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocacaoProvider>().carregarChecklist(widget.contratoId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LocacaoProvider>();
    final contrato = provider.contratos
        .where((c) => c.id == widget.contratoId)
        .firstOrNull;

    if (contrato == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contrato')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.atrNavyBlue : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contrato.numero,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,),),
            Text(contrato.clienteNome,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,),),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ContratoFormSheet(contrato: contrato),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.atrOrange,
          unselectedLabelColor:
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          indicatorColor: AppColors.atrOrange,
          tabs: const [
            Tab(text: 'Resumo'),
            Tab(text: 'Checklist'),
            Tab(text: 'Ocorrências'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ResumoTab(contrato: contrato, isDark: isDark, provider: provider),
          _ChecklistTab(contrato: contrato, isDark: isDark, provider: provider),
          _OcorrenciasTab(contrato: contrato, isDark: isDark, provider: provider),
        ],
      ),
    );
  }
}

// ── ABA: RESUMO ───────────────────────────────────────

class _ResumoTab extends StatelessWidget {
  final Contrato contrato;
  final bool isDark;
  final LocacaoProvider provider;
  const _ResumoTab({required this.contrato, required this.isDark, required this.provider});

  @override
  Widget build(BuildContext context) {
    final ocorrencias = provider.ocorrenciasDoContrato(contrato.id);
    final impactoTotal = ocorrencias.fold(0.0, (s, o) => s + o.impactoFinanceiro);
    final saldoLiquido = contrato.valorMensal - impactoTotal;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _InfoCard(
          isDark: isDark,
          title: 'Dados do Contrato',
          children: [
            _InfoRow('Número', contrato.numero, isDark),
            _InfoRow('Cliente', contrato.clienteNome, isDark),
            _InfoRow('CNPJ', contrato.clienteCnpj, isDark),
            _InfoRow('Contato', contrato.clienteContato, isDark),
            _InfoRow('Veículo', contrato.veiculoPlaca, isDark),
            _InfoRow('Início', _dateFmt.format(contrato.dataInicio), isDark),
            _InfoRow('Fim', _dateFmt.format(contrato.dataFim), isDark),
            _InfoRow('Duração', '${contrato.duracaoMeses} meses', isDark),
            _InfoRow('SLA KM/mês', '${contrato.slaKmMes} km', isDark),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          isDark: isDark,
          title: 'Resumo Financeiro',
          children: [
            _InfoRow('Valor Mensal', _brl.format(contrato.valorMensal), isDark),
            _InfoRow('Total Contrato', _brl.format(contrato.valorTotalContrato), isDark),
            _InfoRow('Impacto Ocorrências', _brl.format(impactoTotal), isDark,
                valueColor: impactoTotal > 0 ? AppColors.statusError : null,),
            _InfoRow('Saldo Líquido', _brl.format(saldoLiquido), isDark,
                valueColor: saldoLiquido < 0 ? AppColors.statusError : AppColors.statusSuccess,),
          ],
        ),
        if (contrato.observacoes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            isDark: isDark,
            title: 'Observações',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(contrato.observacoes,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── ABA: CHECKLIST ────────────────────────────────────

class _ChecklistTab extends StatelessWidget {
  final Contrato contrato;
  final bool isDark;
  final LocacaoProvider provider;
  const _ChecklistTab({required this.contrato, required this.isDark, required this.provider});

  @override
  Widget build(BuildContext context) {
    final lista = provider.checklistDoContrato(contrato.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: lista.isEmpty
          ? Center(
              child: Text('Nenhum evento registrado',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,),),)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _ChecklistCard(
                evento: lista[i],
                isDark: isDark,
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ChecklistFormSheet(contratoId: contrato.id),
        ),
        backgroundColor: AppColors.atrOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Registrar Evento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final ChecklistEvento evento;
  final bool isDark;
  const _ChecklistCard({required this.evento, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isCheckIn = evento.tipo == ChecklistTipo.checkIn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isCheckIn ? AppColors.statusSuccess : AppColors.statusWarning)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCheckIn ? LucideIcons.logIn : LucideIcons.logOut,
              size: 20,
              color: isCheckIn ? AppColors.statusSuccess : AppColors.statusWarning,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento.tipo.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isCheckIn
                        ? AppColors.statusSuccess
                        : AppColors.statusWarning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KM: ${evento.kmOdometro}  ·  Combustível: ${evento.combustivelPct}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                if (evento.kmPercorridos != null)
                  Text(
                    'KM percorridos: ${evento.kmPercorridos}',
                    style: const TextStyle(fontSize: 12, color: AppColors.atrOrange),
                  ),
                if (evento.observacoes.isNotEmpty)
                  Text(evento.observacoes,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,),),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _datetimeFmt.format(evento.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,),
              ),
              if (evento.fotos.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(LucideIcons.image, size: 12),
                  const SizedBox(width: 4),
                  Text('${evento.fotos.length}',
                      style: const TextStyle(fontSize: 11),),
                ],),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── ABA: OCORRÊNCIAS ─────────────────────────────────

class _OcorrenciasTab extends StatelessWidget {
  final Contrato contrato;
  final bool isDark;
  final LocacaoProvider provider;
  const _OcorrenciasTab({required this.contrato, required this.isDark, required this.provider});

  @override
  Widget build(BuildContext context) {
    final lista = provider.ocorrenciasDoContrato(contrato.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: lista.isEmpty
          ? Center(
              child: Text('Nenhuma ocorrência registrada',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,),),)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _OcorrenciaCard(
                ocorrencia: lista[i],
                isDark: isDark,
                onUpdate: (atualizada) =>
                    context.read<LocacaoProvider>().atualizarOcorrencia(atualizada),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => OcorrenciaFormSheet(contratoId: contrato.id),
        ),
        backgroundColor: AppColors.statusError,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Ocorrência',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),),
      ),
    );
  }
}

class _OcorrenciaCard extends StatelessWidget {
  final Ocorrencia ocorrencia;
  final bool isDark;
  final Future<void> Function(Ocorrencia) onUpdate;
  const _OcorrenciaCard({
    required this.ocorrencia,
    required this.isDark,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ocorrencia.tipo.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ocorrencia.tipo.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ocorrencia.tipo.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ocorrencia.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ocorrencia.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ocorrencia.status.color,
                  ),
                ),
              ),
              const Spacer(),
              if (ocorrencia.status == OcorrenciaStatus.aberta)
                TextButton(
                  onPressed: () => _resolverOcorrencia(context),
                  child: const Text('Resolver'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ocorrencia.descricao,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _LabelValue('Data', _dateFmt.format(ocorrencia.dataOcorrencia)),
              const SizedBox(width: 20),
              _LabelValue('Estimado', _brl.format(ocorrencia.valorEstimado)),
              const SizedBox(width: 20),
              _LabelValue(
                  'Impacto', _brl.format(ocorrencia.impactoFinanceiro),
                  color: ocorrencia.impactoFinanceiro > 0
                      ? AppColors.statusError
                      : null,),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolverOcorrencia(BuildContext context) async {
    final valorCtrl = TextEditingController(
      text: ocorrencia.valorEstimado.toStringAsFixed(2),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolver Ocorrência'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o valor final e o impacto financeiro no contrato:'),
            const SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor Final (R\$)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final valorFinal = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final username = context.read<AuthService>().currentUser?.username ?? 'desconhecido';
    final atualizada = ocorrencia.copyWith(
      status: OcorrenciaStatus.resolvida,
      valorFinal: valorFinal,
      impactoFinanceiro: valorFinal,
      resolvidoPor: username,
      dataResolucao: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await onUpdate(atualizada);
  }
}

// ── Helpers de UI ──────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.isDark, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.atrOrange,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, this.isDark, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,),),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ??
                    (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
              ),),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _LabelValue(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),),
      ],
    );
  }
}
