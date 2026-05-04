// REGRAS FINAIS (Parte 2)
// NÃO altere: custos_screen.dart, custos_provider.dart, maintenance_tab.dart, fleet_data.dart
// Se precisar de stubs temporários para compilar, use // TODO: remover após merge Parte 1
// Resetar _paginaAtual sempre que filtro mudar
// Rodar flutter analyze ao final e corrigir todos os warnings
// Verificar packages em pubspec.yaml ANTES de importar pdf/printing

// TODO: remover stub de imports após merge Parte 1
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/data/custos_models.dart';
import '../custos_provider.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/status_badge.dart';

import '../widgets/custos_filter_bar.dart';
import 'expense_form_modal.dart';

import '../../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../../core/utils/export_csv_io.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  // ── Filtros ──
  String? _veiculoSelecionado;
  String? _tipoSelecionado;
  DateTimeRange? _periodoSelecionado;
  bool? _statusPago;

  // ── Ordenação ──
  String _colunaOrdenacao = 'data';
  bool _ordemAscendente = false;

  // ── Paginação ──
  int _paginaAtual = 0;
  static const int _itensPorPagina = 15;

  List<DespesaItem> _despesasFiltradas(CustosProvider provider) {
    var lista = provider.despesas.toList();

    // Filtro: Veículo
    if (_veiculoSelecionado != null) {
      lista =
          lista.where((d) => d.veiculoPlaca == _veiculoSelecionado).toList();
    }

    // Filtro: Tipo
    if (_tipoSelecionado != null) {
      lista = lista.where((d) => d.tipo == _tipoSelecionado).toList();
    }

    // Filtro: Período
    if (_periodoSelecionado != null) {
      lista = lista.where((d) {
        // Zera as horas para comparar apenas os dias
        final dData = DateTime(d.data.year, d.data.month, d.data.day);
        final start = DateTime(_periodoSelecionado!.start.year,
            _periodoSelecionado!.start.month, _periodoSelecionado!.start.day);
        final end = DateTime(_periodoSelecionado!.end.year,
            _periodoSelecionado!.end.month, _periodoSelecionado!.end.day);

        return dData.isAtSameMomentAs(start) ||
            dData.isAtSameMomentAs(end) ||
            (dData.isAfter(start) && dData.isBefore(end));
      }).toList();
    }

    // Filtro: Status (Pago/Pendente)
    if (_statusPago != null) {
      lista = lista.where((d) => d.pago == _statusPago).toList();
    }

    // Ordenação
    lista.sort((a, b) {
      int result = 0;
      if (_colunaOrdenacao == 'data') {
        result = a.data.compareTo(b.data);
      } else if (_colunaOrdenacao == 'valor') {
        result = a.valor.compareTo(b.valor);
      }
      return _ordemAscendente ? result : -result;
    });

    return lista;
  }

  void _onFiltroChanged() {
    setState(() {
      _paginaAtual = 0; // Resetar sempre que filtro mudar
    });
  }

  void _mudarOrdenacao(String coluna) {
    setState(() {
      if (_colunaOrdenacao == coluna) {
        _ordemAscendente = !_ordemAscendente;
      } else {
        _colunaOrdenacao = coluna;
        _ordemAscendente = false; // Padrão: decrescente para data/valor
      }
      _paginaAtual = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuta o provider para atualizar a lista automaticamente
    final provider = context.watch<CustosProvider>();

    final todasDespesas = _despesasFiltradas(provider);
    final totalPaginas = (todasDespesas.length / _itensPorPagina).ceil();

    // Evita _paginaAtual out of bounds
    if (_paginaAtual >= totalPaginas && totalPaginas > 0) {
      _paginaAtual = totalPaginas - 1;
    }

    final startIndex = _paginaAtual * _itensPorPagina;
    final endIndex = (startIndex + _itensPorPagina > todasDespesas.length)
        ? todasDespesas.length
        : startIndex + _itensPorPagina;

    final despesasPaginadas = todasDespesas.sublist(
      startIndex,
      endIndex < startIndex ? startIndex : endIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, todasDespesas),
        const SizedBox(height: 24),

        // ── Filtros ──
        CustosFilterBar(
          veiculoSelecionado: _veiculoSelecionado,
          tipoSelecionado: _tipoSelecionado,
          periodoSelecionado: _periodoSelecionado,
          statusPago: _statusPago,
          showPagoFilter: true,
          placasDisponiveis:
              FleetRepository.instance.frota.map((v) => v.placa).toList(),
          tiposDisponiveis: ExpenseFormModal.tiposDespesa,
          onVeiculoChanged: (v) {
            _veiculoSelecionado = v;
            _onFiltroChanged();
          },
          onTipoChanged: (t) {
            _tipoSelecionado = t;
            _onFiltroChanged();
          },
          onPeriodoChanged: (p) {
            _periodoSelecionado = p;
            _onFiltroChanged();
          },
          onStatusPagoChanged: (s) {
            _statusPago = s;
            _onFiltroChanged();
          },
          onLimparFiltros: () {
            _veiculoSelecionado = null;
            _tipoSelecionado = null;
            _periodoSelecionado = null;
            _statusPago = null;
            _onFiltroChanged();
          },
        ),
        const SizedBox(height: 24),

        // ── Tabela ──
        BentoCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTableHeader(context),
              if (despesasPaginadas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: Text(
                      'Nenhuma despesa encontrada com os filtros atuais.',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                ...despesasPaginadas.map(
                  (d) => Column(
                    children: [
                      _buildTableRow(context, d),
                      const Divider(height: 1),
                    ],
                  ),
                ),
              if (todasDespesas.isNotEmpty)
                _buildTableFooter(todasDespesas.length, totalPaginas),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<DespesaItem> currentList) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Despesas Operacionais',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestão de custos e comprovantes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            // Botão Exportar
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'csv') {
                  _exportCsv(currentList);
                } else if (value == 'pdf') {
                  _exportPdf(currentList);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            const SizedBox(width: 12),
            // Lançamento Rápido
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.atrOrange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final newItem = await ExpenseFormModal.show(context);
                if (newItem != null && context.mounted) {
                  context.read<CustosProvider>().addDespesa(newItem);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Despesa adicionada com sucesso!')),
                  );
                }
              },
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Lançamento Rápido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // DATA (Clicável)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _mudarOrdenacao('data'),
              child: Row(
                children: [
                  const Text(
                    'DATA',
                    style: TextStyle(
                      color: AppColors.atrOrange,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_colunaOrdenacao == 'data') ...[
                    const SizedBox(width: 4),
                    Icon(
                      _ordemAscendente
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 14,
                      color: AppColors.atrOrange,
                    ),
                  ]
                ],
              ),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'TIPO / DESCRIÇÃO',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'VEÍCULO',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'STATUS',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'ANEXO',
              style: TextStyle(
                color: AppColors.atrOrange,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // VALOR (Clicável)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _mudarOrdenacao('valor'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_colunaOrdenacao == 'valor') ...[
                    Icon(
                      _ordemAscendente
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 14,
                      color: AppColors.atrOrange,
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Text(
                    'VALOR',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.atrOrange,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48), // Espaço para as actions
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, DespesaItem d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              formatDate(d.data),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    d.tipo == 'Manutenção' || d.tipo == 'Revisão'
                        ? LucideIcons.wrench
                        : LucideIcons.receipt,
                    size: 14,
                    color: AppColors.atrOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.tipo,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (d.descricao.isNotEmpty)
                        Text(
                          d.descricao,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (d.nf.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.receipt,
                              size: 10,
                              color: AppColors.atrOrange,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'NF ${d.nf}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.atrOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.veiculoPlaca,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  d.motorista,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                text: d.pago ? 'PAGO' : 'PENDENTE',
                type: d.pago ? BadgeType.success : BadgeType.warning,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                if (d.nomeAnexo.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Visualização de anexo disponível em breve'),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: d.nomeAnexo.isNotEmpty
                    ? Tooltip(
                        message: d.nomeAnexo,
                        child: const Icon(
                          LucideIcons.fileText,
                          size: 18,
                          color: AppColors.statusInfo,
                        ),
                      )
                    : Icon(
                        LucideIcons.fileMinus,
                        size: 18,
                        color:
                            AppColors.textSecondaryLight.withValues(alpha: 0.2),
                      ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCurrency(d.valor),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.statusError,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildActions(context, d),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, DespesaItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(
        LucideIcons.moreHorizontal,
        size: 18,
        color: AppColors.textSecondaryLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) async {
        if (val == 'edit') {
          final updated = await ExpenseFormModal.show(context, item: item);
          if (updated != null && context.mounted) {
            context.read<CustosProvider>().updateDespesa(updated);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Despesa atualizada com sucesso!')),
            );
          }
        } else if (val == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Excluir Despesa'),
              content:
                  Text('Excluir despesa de ${formatCurrency(item.valor)}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Excluir'),
                ),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            context.read<CustosProvider>().deleteDespesa(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Despesa excluída.')),
            );
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(LucideIcons.edit2, size: 14),
              SizedBox(width: 12),
              Text('Editar', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(LucideIcons.trash2, size: 14, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Excluir',
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableFooter(int total, int totalPaginas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.atrOrange.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total de $total registros encontrados',
            style: const TextStyle(
              color: AppColors.textSecondaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (totalPaginas > 1)
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  onPressed: _paginaAtual > 0
                      ? () => setState(() => _paginaAtual--)
                      : null,
                ),
                Text(
                  '${_paginaAtual + 1} de $totalPaginas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 18),
                  onPressed: _paginaAtual < totalPaginas - 1
                      ? () => setState(() => _paginaAtual++)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Funções de Exportação ──

  Future<void> _exportCsv(List<DespesaItem> itens) async {
    final buffer = StringBuffer();
    // Cabeçalho
    buffer.writeln(
      '"DATA";"TIPO";"DESCRIÇÃO";"NF";"VEÍCULO";"MOTORISTA";"STATUS";"VALOR"',
    );

    for (final i in itens) {
      final dateStr = formatDate(i.data);
      final pagoStr = i.pago ? 'Pago' : 'Pendente';
      final valorStr = i.valor.toStringAsFixed(2).replaceAll('.', ',');
      buffer.writeln(
        '${_csvField(dateStr)};${_csvField(i.tipo)};${_csvField(i.descricao)};${_csvField(i.nf)};${_csvField(i.veiculoPlaca)};${_csvField(i.motorista)};${_csvField(pagoStr)};${_csvField(valorStr)}',
      );
    }

    try {
      final fileName =
          'despesas_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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

  Future<void> _exportPdf(List<DespesaItem> itens) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Relatório de Despesas Operacionais',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Data', 'Tipo', 'Veículo', 'Status', 'Valor'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              data: itens.map((i) {
                return [
                  formatDate(i.data),
                  i.tipo,
                  i.veiculoPlaca,
                  i.pago ? 'Pago' : 'Pendente',
                  formatCurrency(i.valor),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 24),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: ${formatCurrency(itens.fold(0.0, (sum, item) => sum + item.valor))}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ];
        },
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'despesas_relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
