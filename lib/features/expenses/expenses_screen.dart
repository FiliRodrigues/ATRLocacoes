import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/data/fleet_data.dart';

class ExpenseItem {
  final String data;
  final String tipo;
  final String veiculo;
  final String motorista;
  final double valor;
  final bool pago;
  final bool temAnexo;

  ExpenseItem({required this.data, required this.tipo, required this.veiculo, required this.motorista, required this.valor, required this.pago, this.temAnexo = false});
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Gerar lista de despesas a partir das manutenções da frota + extras
    final List<ExpenseItem> despesas = [];
    
    for (final v in frota) {
      for (final m in v.manutencoes) {
        despesas.add(ExpenseItem(
          data: formatDate(m.data),
          tipo: m.tipo,
          veiculo: v.placa,
          motorista: v.motorista,
          valor: m.custo,
          pago: true,
          temAnexo: true,
        ));
      }
    }
    
    // Adicionar alguns mocks de combustível/pedágio para volume
    despesas.add(ExpenseItem(data: '05/04/2026', tipo: 'Combustível', veiculo: 'VD-1234', motorista: 'João Silva', valor: 250.0, pago: true, temAnexo: true));
    despesas.add(ExpenseItem(data: '04/04/2026', tipo: 'Pedágio', veiculo: 'TX-2041', motorista: 'Marcos Antônio', valor: 15.50, pago: true));
    despesas.add(ExpenseItem(data: '02/04/2026', tipo: 'Lavagem', veiculo: 'ARG-4H78', motorista: 'Roberto Carlos', valor: 80.0, pago: false));

    // Ordenar por data (aproximado por string aqui para o mock)
    despesas.sort((a, b) => b.data.compareTo(a.data));

    return AppSidebar(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(context),
                const SizedBox(height: 8),
                _buildHeader(context),
                const SizedBox(height: 32),
                BentoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTableHeader(context),
                      ...despesas.take(15).map((d) => Column(
                        children: [
                          _buildTableRow(context, d),
                          const Divider(height: 1),
                        ],
                      )),
                      _buildTableFooter(despesas.length),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    return Row(
      children: [
        Text('Home', style: TextStyle(color: AppColors.textSecondaryLight.withOpacity(0.6), fontSize: 12)),
        Icon(LucideIcons.chevronRight, size: 12, color: AppColors.textSecondaryLight.withOpacity(0.4)),
        const Text('Controle de Despesas', style: TextStyle(color: AppColors.atrOrange, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Controle de Despesas', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
            Text('Histórico completo de custos operacionais da frota.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: Theme.of(context).dividerTheme.color!)
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                    SizedBox(width: 12),
                    Expanded(child: TextField(decoration: InputDecoration(isDense: true, hintText: 'Buscar por placa ou motorista...', border: InputBorder.none, filled: false))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.atrOrange, 
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () => _showQuickExpenseModal(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Lançamento Rápido', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        )
      ],
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withOpacity(0.05), 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('DATA', style: TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('TIPO / DESCRIÇÃO', style: TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('VEÍCULO', style: TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('STATUS', style: TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5))),
          Expanded(flex: 1, child: Text('ANEXO', style: TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('VALOR', textAlign: TextAlign.right, style: TextStyle(color: AppColors.atrOrange, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5))),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, ExpenseItem d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(d.data, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            flex: 3, 
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: AppColors.atrOrange.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), 
                  child: Icon(d.tipo == 'Manutenção' || d.tipo == 'Revisão' ? LucideIcons.wrench : LucideIcons.receipt, size: 14, color: AppColors.atrOrange)
                ),
                const SizedBox(width: 12),
                Text(d.tipo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            flex: 2, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.veiculo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(d.motorista, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
              ],
            )
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(text: d.pago ? 'PAGO' : 'PENDENTE', type: d.pago ? BadgeType.success : BadgeType.warning))),
          Expanded(
            flex: 1, 
            child: d.temAnexo 
              ? Icon(LucideIcons.fileCheck, size: 18, color: AppColors.statusSuccess.withOpacity(0.7))
              : Icon(LucideIcons.fileMinus, size: 18, color: AppColors.textSecondaryLight.withOpacity(0.2)),
          ),
          Expanded(
            flex: 2, 
            child: Text(formatCurrency(d.valor), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.statusError)),
          ),
          const SizedBox(width: 16),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.moreHorizontal, size: 18, color: AppColors.textSecondaryLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.edit2, size: 14), SizedBox(width: 12), Text('Editar', style: TextStyle(fontSize: 13))])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 14, color: Colors.red), SizedBox(width: 12), Text('Excluir', style: TextStyle(fontSize: 13, color: Colors.red))])),
      ],
    );
  }

  Widget _buildTableFooter(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withOpacity(0.02),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total de $total registros encontrados', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(icon: const Icon(LucideIcons.chevronLeft, size: 18), onPressed: () {}),
              Container(
                width: 32, height: 32, 
                decoration: BoxDecoration(color: AppColors.atrOrange, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              IconButton(icon: const Icon(LucideIcons.chevronRight, size: 18), onPressed: () {}),
            ],
          )
        ],
      ),
    );
  }

  void _showQuickExpenseModal(BuildContext context, {bool isEdit = false}) {
     showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isEdit ? 'Editar Lançamento' : 'Novo Lançamento Rápido', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Veículo da Frota'),
                  items: frota.map((v) => DropdownMenuItem(value: v.placa, child: Text('${v.placa} - ${v.nome}'))).toList(),
                  onChanged: (v) {},
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: const [
                        DropdownMenuItem(value: 'Combustível', child: Text('Combustível')),
                        DropdownMenuItem(value: 'Manutenção', child: Text('Manutenção')),
                        DropdownMenuItem(value: 'Pedágio', child: Text('Pedágio')),
                        DropdownMenuItem(value: 'Lavagem', child: Text('Lavagem')),
                      ],
                      onChanged: (v) {},
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Data (DD/MM/AAAA)', suffixIcon: Icon(LucideIcons.calendar)))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(decoration: const InputDecoration(labelText: 'Valor (R\$)', prefixText: 'R\$ ')),
                const SizedBox(height: 16),
                TextFormField(maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição / Observação')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.atrOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Salvar Lançamento'),
            ),
          ],
        ),
      ),
    );
  }
}
