import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/pending_action.dart';
import 'ai_chat_screen_spinner.dart';

class PendingActionCard extends StatefulWidget {
  final PendingAction action;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onCancel;

  const PendingActionCard({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PendingActionCard> createState() => _PendingActionCardState();
}

class _PendingActionCardState extends State<PendingActionCard> {
  static const _toolLabels = {
    'list_vehicles': 'BUSCANDO VEÍCULOS',
    'get_vehicle_details': 'DETALHES DO VEÍCULO',
    'list_maintenances': 'BUSCANDO MANUTENÇÕES',
    'list_contracts': 'BUSCANDO CONTRATOS',
    'list_drivers': 'BUSCANDO MOTORISTAS',
    'get_financing_status': 'VERIFICANDO FINANCIAMENTOS',
    'get_costs_summary': 'CALCULANDO CUSTOS',
    'extract_invoice_data': 'LENDO NOTA FISCAL',
    'get_ipva': 'IPVA',
    'get_licenciamento': 'LICENCIAMENTO',
    'get_seguros': 'SEGUROS',
    'get_parcelas_seguro': 'PARCELAS SEGURO',
    'get_multas': 'MULTAS',
    'get_checklist_eventos': 'CHECKLIST',
    'get_ocorrencias': 'OCORRÊNCIAS',
    'get_abastecimentos': 'ABASTECIMENTOS',
    'get_regras_manutencao': 'REGRAS MANUTENÇÃO',
    'get_recebimentos': 'RECEBIMENTOS',
    'list_expenses': 'DESPESAS',
    'search_global': 'BUSCAR',
    'create_maintenance': 'REGISTRAR MANUTENÇÃO',
    'create_expense': 'REGISTRAR DESPESA',
    'create_maintenances_batch': 'REGISTRO EM LOTE',
    'update_vehicle_mileage': 'ATUALIZAR HODÔMETRO',
    'create_vehicle': 'CADASTRAR VEÍCULO',
    'update_vehicle': 'ATUALIZAR VEÍCULO',
    'delete_vehicle': 'EXCLUIR VEÍCULO',
    'update_maintenance': 'ATUALIZAR MANUTENÇÃO',
    'delete_maintenance': 'EXCLUIR MANUTENÇÃO',
    'update_expense': 'ATUALIZAR DESPESA',
    'delete_expense': 'EXCLUIR DESPESA',
    'create_abastecimento': 'REGISTRAR ABASTECIMENTO',
    'update_abastecimento': 'ATUALIZAR ABASTECIMENTO',
    'delete_abastecimento': 'EXCLUIR ABASTECIMENTO',
    'create_contract': 'CRIAR CONTRATO',
    'update_contract': 'ATUALIZAR CONTRATO',
    'delete_contract': 'EXCLUIR CONTRATO',
    'update_payment_status': 'ATUALIZAR PAGAMENTO',
    'create_regra_manutencao': 'CRIAR REGRA',
    'update_regra_manutencao': 'ATUALIZAR REGRA',
    'create_ocorrencia': 'REGISTRAR OCORRÊNCIA',
    'update_ocorrencia': 'RESOLVER OCORRÊNCIA',
    'create_recebimento': 'REGISTRAR RECEBIMENTO',
    'list_sala_atr_agendamentos': 'LISTAR AGENDAMENTOS',
    'get_sala_atr_agendamento': 'DETALHES AGENDAMENTO',
    'list_sala_atr_despesas': 'LISTAR DESPESAS SALA',
    'list_sala_atr_pacotes': 'LISTAR PACOTES',
    'check_disponibilidade_sala': 'VERIFICAR DISPONIBILIDADE',
    'relatorio_ocupacao_sala': 'RELATÓRIO OCUPAÇÃO',
    'create_sala_atr_agendamento': 'AGENDAR SALA ATR',
    'update_sala_atr_agendamento': 'ATUALIZAR AGENDAMENTO',
    'delete_sala_atr_agendamento': 'CANCELAR AGENDAMENTO',
    'create_sala_atr_despesa': 'REGISTRAR DESPESA SALA',
    'update_sala_atr_despesa': 'ATUALIZAR DESPESA SALA',
    'delete_sala_atr_despesa': 'DELETAR DESPESA SALA',
    'create_sala_atr_pacote': 'CRIAR PACOTE SESSÕES',
    'update_sala_atr_pacote': 'USAR SESSÃO PACOTE',
    'list_lazer_eventos': 'LISTAR EVENTOS LAZER',
    'list_lazer_despesas': 'LISTAR DESPESAS LAZER',
    'relatorio_lazer': 'RELATÓRIO LAZER',
    'create_lazer_evento': 'CRIAR EVENTO LAZER',
    'update_lazer_evento': 'ATUALIZAR EVENTO LAZER',
    'delete_lazer_evento': 'CANCELAR EVENTO LAZER',
    'create_lazer_despesa': 'REGISTRAR DESPESA LAZER',
    'update_lazer_despesa': 'ATUALIZAR DESPESA LAZER',
    'delete_lazer_despesa': 'DELETAR DESPESA LAZER',
    'delete_financiamento': 'DELETAR FINANCIAMENTO',
    'update_parcela_seguro': 'ATUALIZAR PARCELA SEGURO',
    'create_hodometro': 'REGISTRAR HODÔMETRO',
    'update_ipva': 'ATUALIZAR IPVA',
    'update_licenciamento': 'ATUALIZAR LICENCIAMENTO',
    'update_multa': 'ATUALIZAR MULTA',
    'validate_km_intervalo': 'VALIDAR KM MANUTENÇÃO',
    'create_checklist_evento': 'REGISTRAR CHECK-IN/OUT',
    'update_checklist_evento': 'ATUALIZAR CHECKLIST',
    'create_seguro': 'REGISTRAR SEGURO',
    'update_seguro': 'ATUALIZAR SEGURO',
    'create_financiamento': 'REGISTRAR FINANCIAMENTO',
    'update_financiamento': 'ATUALIZAR FINANCIAMENTO',
    'delete_ocorrencia': 'EXCLUIR OCORRÊNCIA',
    'delete_regra_manutencao': 'EXCLUIR REGRA',
    'delete_sala_atr_pacote': 'EXCLUIR PACOTE',
    'delete_recebimento': 'EXCLUIR RECEBIMENTO',
    'get_alertas_frota': 'ALERTAS DA FROTA',
    'get_contratos_proximos_vencer': 'CONTRATOS A VENCER',
  };

  static const _toolIcons = {
    'list_vehicles': LucideIcons.truck,
    'get_vehicle_details': LucideIcons.info,
    'list_maintenances': LucideIcons.wrench,
    'list_contracts': LucideIcons.fileText,
    'list_drivers': LucideIcons.users,
    'get_financing_status': LucideIcons.creditCard,
    'get_costs_summary': LucideIcons.barChart2,
    'extract_invoice_data': LucideIcons.scan,
    'get_ipva': LucideIcons.file,
    'get_licenciamento': LucideIcons.checkCircle,
    'get_seguros': LucideIcons.shieldAlert,
    'get_parcelas_seguro': LucideIcons.creditCard,
    'get_multas': LucideIcons.alertTriangle,
    'get_checklist_eventos': LucideIcons.clipboardList,
    'get_ocorrencias': LucideIcons.alertCircle,
    'get_abastecimentos': LucideIcons.fuel,
    'get_regras_manutencao': LucideIcons.wrench,
    'get_recebimentos': LucideIcons.dollarSign,
    'list_expenses': LucideIcons.receipt,
    'search_global': LucideIcons.search,
    'create_maintenance': LucideIcons.plusCircle,
    'create_expense': LucideIcons.receipt,
    'create_maintenances_batch': LucideIcons.layers,
    'update_vehicle_mileage': LucideIcons.gauge,
    'create_vehicle': LucideIcons.plusCircle,
    'update_vehicle': LucideIcons.pencil,
    'delete_vehicle': LucideIcons.trash2,
    'update_maintenance': LucideIcons.pencil,
    'delete_maintenance': LucideIcons.trash2,
    'update_expense': LucideIcons.pencil,
    'delete_expense': LucideIcons.trash2,
    'create_abastecimento': LucideIcons.fuel,
    'update_abastecimento': LucideIcons.pencil,
    'delete_abastecimento': LucideIcons.trash2,
    'create_contract': LucideIcons.clipboardList,
    'update_contract': LucideIcons.pencil,
    'delete_contract': LucideIcons.trash2,
    'update_payment_status': LucideIcons.creditCard,
    'create_regra_manutencao': LucideIcons.ruler,
    'update_regra_manutencao': LucideIcons.pencil,
    'create_ocorrencia': LucideIcons.alertTriangle,
    'update_ocorrencia': LucideIcons.checkSquare,
    'create_recebimento': LucideIcons.plus,
    'list_sala_atr_agendamentos': LucideIcons.calendar,
    'get_sala_atr_agendamento': LucideIcons.calendarCheck,
    'list_sala_atr_despesas': LucideIcons.receipt,
    'list_sala_atr_pacotes': LucideIcons.package,
    'check_disponibilidade_sala': LucideIcons.clock,
    'list_lazer_eventos': LucideIcons.calendar,
    'list_lazer_despesas': LucideIcons.receipt,
    'relatorio_lazer': LucideIcons.barChart3,
    'create_lazer_evento': LucideIcons.plusCircle,
    'update_lazer_evento': LucideIcons.edit3,
    'delete_lazer_evento': LucideIcons.trash2,
    'create_lazer_despesa': LucideIcons.plusSquare,
    'update_lazer_despesa': LucideIcons.pencil,
    'delete_lazer_despesa': LucideIcons.trash2,
    'delete_financiamento': LucideIcons.trash2,
    'update_parcela_seguro': LucideIcons.checkCircle2,
    'create_hodometro': LucideIcons.gauge,
    'update_ipva': LucideIcons.fileText,
    'update_licenciamento': LucideIcons.fileText,
    'update_multa': LucideIcons.alertTriangle,
    'validate_km_intervalo': LucideIcons.checkCircle,
    'create_checklist_evento': LucideIcons.clipboardCheck,
    'update_checklist_evento': LucideIcons.pencil,
    'create_seguro': LucideIcons.shieldCheck,
    'update_seguro': LucideIcons.pencil,
    'create_financiamento': LucideIcons.landmark,
    'update_financiamento': LucideIcons.pencil,
    'delete_ocorrencia': LucideIcons.trash2,
    'delete_regra_manutencao': LucideIcons.trash2,
    'delete_sala_atr_pacote': LucideIcons.trash2,
    'delete_recebimento': LucideIcons.trash2,
    'get_alertas_frota': LucideIcons.alertTriangle,
    'get_contratos_proximos_vencer': LucideIcons.calendarClock,
    'relatorio_ocupacao_sala': LucideIcons.barChart3,
    'create_sala_atr_agendamento': LucideIcons.plusCircle,
    'update_sala_atr_agendamento': LucideIcons.edit3,
    'delete_sala_atr_agendamento': LucideIcons.trash2,
    'create_sala_atr_despesa': LucideIcons.plusSquare,
    'update_sala_atr_despesa': LucideIcons.pencil,
    'delete_sala_atr_despesa': LucideIcons.trash2,
    'create_sala_atr_pacote': LucideIcons.gift,
    'update_sala_atr_pacote': LucideIcons.checkCircle2,
  };

  late Timer _timer;
  late Duration _remaining;
  bool _confirming = false;

  bool get _isPending => widget.action.status == PendingActionStatus.pendingConfirmation;

  @override
  void initState() {
    super.initState();
    _remaining = const Duration(minutes: 60);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 30);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = _toolIcons[widget.action.toolName] ?? LucideIcons.wrench;
    final label = _toolLabels[widget.action.toolName] ?? widget.action.toolName.toUpperCase();
    final duplicate = widget.action.isDuplicate;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: duplicate ? AppColors.statusWarning : AppColors.borderGlowDark,
          width: duplicate ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (duplicate)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                color: Color(0x1AFBBF24),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.statusWarning),
                  SizedBox(width: 6),
                  Text(
                    'Possível duplicidade',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusWarning,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: duplicate
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                colors: [
                  (duplicate ? AppColors.statusWarning : AppColors.atrOrange).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: duplicate ? AppColors.statusWarning : AppColors.atrOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              widget.action.preview,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
                height: 1.5,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                const Icon(LucideIcons.clock, size: 13, color: AppColors.textMutedDark),
                const SizedBox(width: 6),
                Text(
                  'Expira em ${_countdownText}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _countdownColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _confirming ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.atrOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _confirming
                            ? const Center(child: AiSpinner(size: 16))
                            : const Text(
                                'Confirmar',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: _confirming ? null : widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondaryDark,
                        side: const BorderSide(color: AppColors.borderGlowDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _buildFinalStatus(),
            ),
        ],
      ),
    )
        .animate()
        .fade(duration: 300.ms)
        .slide(begin: const Offset(0, 0.2), duration: 300.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.95, 0.95), duration: 300.ms, curve: Curves.easeOut);
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    await widget.onConfirm();
    if (!mounted) return;
    setState(() => _confirming = false);
  }

  String get _countdownText {
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _countdownColor {
    if (_remaining.inSeconds < 60) return AppColors.statusError;
    if (_remaining.inMinutes < 5) return AppColors.statusWarning;
    return AppColors.statusSuccess;
  }

  Widget _buildFinalStatus() {
    final success = widget.action.status == PendingActionStatus.confirmed ||
      widget.action.status == PendingActionStatus.executed;
    final failed = widget.action.status == PendingActionStatus.failed;
    final cancelled = widget.action.status == PendingActionStatus.cancelled;
    final bg = success ? AppColors.glowSuccess : AppColors.glowError;
    final color = success ? AppColors.statusSuccess : AppColors.statusError;
    final label = success
      ? 'Registrado com sucesso'
      : failed
        ? 'Falha na execução'
        : cancelled
          ? 'Cancelado'
          : 'Aguardando';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(success ? LucideIcons.checkCircle2 : LucideIcons.xCircle, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
