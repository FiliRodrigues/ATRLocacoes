import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ═══════════════════════════════════════════════════════════════════════
// Modelos de entrada para geração de relatório
// ═══════════════════════════════════════════════════════════════════════

class RelatorioFrotaData {
  final DateTime de;
  final DateTime ate;
  final List<RelatorioVeiculoRow> veiculos;
  final double totalManutencao;
  final double totalDespesas;
  final double totalCombustivel;
  final double totalGeral;

  const RelatorioFrotaData({
    required this.de,
    required this.ate,
    required this.veiculos,
    required this.totalManutencao,
    required this.totalDespesas,
    required this.totalCombustivel,
    required this.totalGeral,
  });
}

class RelatorioVeiculoRow {
  final String placa;
  final String nome;
  final double custoManutencao;
  final double custoDespesas;
  final double custoCombustivel;
  final double totalVeiculo;
  final int abastecimentos;
  final double kmMedia; // km/l médio, 0.0 se sem dados

  const RelatorioVeiculoRow({
    required this.placa,
    required this.nome,
    required this.custoManutencao,
    required this.custoDespesas,
    required this.custoCombustivel,
    required this.totalVeiculo,
    required this.abastecimentos,
    required this.kmMedia,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// Modelos de entrada para PDFs de vencimentos / veiculo / custos
// ═══════════════════════════════════════════════════════════════════════

class VencimentoPdfRow {
  final String tipo; // IPVA, Seguro, Licenciamento, CNH
  final String entidade; // placa ou nome
  final String subtitulo;
  final DateTime vencimento;
  final int diasRestantes;
  final double? valorTotal;
  final String statusPagamento;
  final String status; // VENCIDO, CRITICO, etc.

  const VencimentoPdfRow({
    required this.tipo,
    required this.entidade,
    required this.subtitulo,
    required this.vencimento,
    required this.diasRestantes,
    this.valorTotal,
    required this.statusPagamento,
    required this.status,
  });
}

class VeiculoPdfData {
  final String placa;
  final String nome;
  final String motorista;
  final double kmAtual;
  final double custoTotalManutencao;
  final int totalRevisoes;
  final List<VeiculoManutencaoPdfRow> manutencoes;

  const VeiculoPdfData({
    required this.placa,
    required this.nome,
    required this.motorista,
    required this.kmAtual,
    required this.custoTotalManutencao,
    required this.totalRevisoes,
    required this.manutencoes,
  });
}

class VeiculoManutencaoPdfRow {
  final String titulo;
  final String tipo;
  final DateTime data;
  final String fornecedor;
  final double custo;
  final int km;
  final String prioridade;
  final bool isPreventiva;

  const VeiculoManutencaoPdfRow({
    required this.titulo,
    required this.tipo,
    required this.data,
    required this.fornecedor,
    required this.custo,
    required this.km,
    required this.prioridade,
    required this.isPreventiva,
  });
}

class CustoPdfRow {
  final String veiculoPlaca;
  final String veiculoNome;
  final double manutencao;
  final double despesas;
  final double combustivel;
  final double total;

  const CustoPdfRow({
    required this.veiculoPlaca,
    required this.veiculoNome,
    required this.manutencao,
    required this.despesas,
    required this.combustivel,
    required this.total,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// Serviço estático de geração de PDF
// ═══════════════════════════════════════════════════════════════════════

class RelatorioService {
  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dateTimeFmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

  static const _navy = PdfColor.fromInt(0xFF1A2332);
  static const _orange = PdfColor.fromInt(0xFFFF8C42);

  static Future<Uint8List> gerarRelatorioPDF(RelatorioFrotaData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(ctx, data),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          _buildResumo(data),
          pw.SizedBox(height: 24),
          _buildTabela(data),
        ],
      ),
    );

    return doc.save();
  }

  // ── Cabeçalho ──────────────────────────────────────────────────────

  static pw.Widget _buildHeader(pw.Context ctx, RelatorioFrotaData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ATR Gestão de Frotas',
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 18,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Relatório de Custos da Frota',
                  style: pw.TextStyle(
                    fontSize: 13,
                    color: _orange,
                    font: pw.Font.helveticaBold(),
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Período: ${_dateFmt.format(data.de)} – ${_dateFmt.format(data.ate)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Emissão: ${_dateTimeFmt.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(color: _navy, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── Rodapé ─────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gerado automaticamente pelo sistema ATR em ${_dateTimeFmt.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  // ── Resumo executivo ───────────────────────────────────────────────

  static pw.Widget _buildResumo(RelatorioFrotaData data) {
    return pw.Row(
      children: [
        _resumoBox('Manutenção', _brl.format(data.totalManutencao), PdfColors.red200, PdfColors.red800),
        pw.SizedBox(width: 8),
        _resumoBox('Despesas', _brl.format(data.totalDespesas), PdfColors.amber200, PdfColors.amber800),
        pw.SizedBox(width: 8),
        _resumoBox('Combustível', _brl.format(data.totalCombustivel), PdfColors.orange200, PdfColors.orange800),
        pw.SizedBox(width: 8),
        _resumoBox('Total Geral', _brl.format(data.totalGeral), PdfColors.blue200, PdfColors.blue800),
      ],
    );
  }

  static pw.Widget _resumoBox(
    String label,
    String value,
    PdfColor bg,
    PdfColor textColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: textColor),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 11,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabela por veículo ─────────────────────────────────────────────

  static pw.Widget _buildTabela(RelatorioFrotaData data) {
    final cellStyle = pw.TextStyle(fontSize: 9);
    final boldCell = pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold());

    pw.Widget cell(String text, {bool bold = false, pw.Alignment align = pw.Alignment.centerLeft}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Align(
          alignment: align,
          child: pw.Text(text, style: bold ? boldCell : cellStyle),
        ),
      );
    }

    pw.Widget headerCell(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9, color: PdfColors.white)),
      );
    }

    final rows = <pw.TableRow>[
      // Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          headerCell('Veículo'),
          headerCell('Placa'),
          headerCell('Manutenção'),
          headerCell('Despesas'),
          headerCell('Combustível'),
          headerCell('Total'),
          headerCell('km/l'),
        ],
      ),
      // Dados
      ...data.veiculos.asMap().entries.map((entry) {
        final i = entry.key;
        final v = entry.value;
        final isOdd = i % 2 == 1;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isOdd ? PdfColors.grey100 : PdfColors.white,
          ),
          children: [
            cell(v.nome),
            cell(v.placa),
            cell(_brl.format(v.custoManutencao), align: pw.Alignment.centerRight),
            cell(_brl.format(v.custoDespesas), align: pw.Alignment.centerRight),
            cell(_brl.format(v.custoCombustivel), align: pw.Alignment.centerRight),
            cell(_brl.format(v.totalVeiculo), bold: true, align: pw.Alignment.centerRight),
            cell(v.kmMedia > 0 ? '${v.kmMedia.toStringAsFixed(1)}' : '—', align: pw.Alignment.center),
          ],
        );
      }),
      // Total
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EDF6)),
        children: [
          cell('TOTAL', bold: true),
          cell(''),
          cell(_brl.format(data.totalManutencao), bold: true, align: pw.Alignment.centerRight),
          cell(_brl.format(data.totalDespesas), bold: true, align: pw.Alignment.centerRight),
          cell(_brl.format(data.totalCombustivel), bold: true, align: pw.Alignment.centerRight),
          cell(_brl.format(data.totalGeral), bold: true, align: pw.Alignment.centerRight),
          cell(''),
        ],
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.6),
        4: const pw.FlexColumnWidth(1.6),
        5: const pw.FlexColumnWidth(1.6),
        6: const pw.FlexColumnWidth(0.9),
      },
      children: rows,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PDF de Vencimentos
  // ═══════════════════════════════════════════════════════════════════

  static Future<Uint8List> gerarPdfVencimentos(List<VencimentoPdfRow> rows) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildSimpleHeader('Painel de Vencimentos', 'IPVA · Seguro · Licenciamento · CNH'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          _buildVencimentosTable(rows),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildVencimentosTable(List<VencimentoPdfRow> rows) {
    final cellStyle = pw.TextStyle(fontSize: 9);
    final boldCell = pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold());

    pw.Widget cell(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: bold ? boldCell : cellStyle),
      );
    }

    pw.Widget headerCell(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9, color: PdfColors.white)),
      );
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          headerCell('Tipo'),
          headerCell('Entidade'),
          headerCell('Detalhe'),
          headerCell('Vencimento'),
          headerCell('Dias'),
          headerCell('Valor'),
          headerCell('Status PG'),
          headerCell('Status'),
        ],
      ),
      ...rows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final isOdd = i % 2 == 1;
        final statusColor = r.status.contains('VENCIDO')
            ? PdfColors.red400
            : r.status.contains('CRITICO')
                ? PdfColors.deepOrange400
                : r.status.contains('Atencao')
                    ? PdfColors.amber600
                    : PdfColors.green400;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: isOdd ? PdfColors.grey100 : PdfColors.white),
          children: [
            cell(r.tipo),
            cell(r.entidade),
            cell(r.subtitulo),
            cell(_dateFmt.format(r.vencimento)),
            cell('${r.diasRestantes}d'),
            cell(r.valorTotal != null ? _brl.format(r.valorTotal) : ''),
            cell(r.statusPagamento),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(r.status, style: pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold(), color: statusColor)),
            ),
          ],
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(1.6),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1.4),
        6: const pw.FlexColumnWidth(1.2),
        7: const pw.FlexColumnWidth(1.4),
      },
      children: tableRows,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PDF de Veiculo (Dossie)
  // ═══════════════════════════════════════════════════════════════════

  static Future<Uint8List> gerarPdfVeiculo(VeiculoPdfData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildSimpleHeader('Dossie do Veiculo — ${data.placa}', '${data.nome} · ${data.motorista} · ${NumberFormat('#,###', 'pt_BR').format(data.kmAtual)} km'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _buildVeiculoResumo(data),
          pw.SizedBox(height: 24),
          _buildVeiculoManutencoesTable(data.manutencoes),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildVeiculoResumo(VeiculoPdfData data) {
    return pw.Row(
      children: [
        _resumoBox('Custo Manutencao', _brl.format(data.custoTotalManutencao), PdfColors.red200, PdfColors.red800),
        pw.SizedBox(width: 8),
        _resumoBox('Revisoes', '${data.totalRevisoes}', PdfColors.blue200, PdfColors.blue800),
        pw.SizedBox(width: 8),
        _resumoBox('KM Atual', NumberFormat('#,###', 'pt_BR').format(data.kmAtual), PdfColors.orange200, PdfColors.orange800),
      ],
    );
  }

  static pw.Widget _buildVeiculoManutencoesTable(List<VeiculoManutencaoPdfRow> manutencoes) {
    final cellStyle = pw.TextStyle(fontSize: 9);
    final boldCell = pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold());

    pw.Widget cell(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: bold ? boldCell : cellStyle),
      );
    }

    pw.Widget headerCell(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9, color: PdfColors.white)),
      );
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          headerCell('Titulo'),
          headerCell('Tipo'),
          headerCell('Data'),
          headerCell('Fornecedor'),
          headerCell('Custo'),
          headerCell('KM'),
          headerCell('Prioridade'),
        ],
      ),
      ...manutencoes.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value;
        final isOdd = i % 2 == 1;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: isOdd ? PdfColors.grey100 : PdfColors.white),
          children: [
            cell(m.titulo),
            cell(m.isPreventiva ? 'Preventiva' : 'Corretiva'),
            cell(_dateFmt.format(m.data)),
            cell(m.fornecedor),
            cell(_brl.format(m.custo)),
            cell(m.km > 0 ? '${NumberFormat('#,###').format(m.km)}' : ''),
            cell(m.prioridade),
          ],
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(1.2),
      },
      children: tableRows,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PDF de Custos
  // ═══════════════════════════════════════════════════════════════════

  static Future<Uint8List> gerarPdfCustos(List<CustoPdfRow> rows) async {
    final doc = pw.Document();
    final totalManut = rows.fold(0.0, (s, r) => s + r.manutencao);
    final totalDesp = rows.fold(0.0, (s, r) => s + r.despesas);
    final totalComb = rows.fold(0.0, (s, r) => s + r.combustivel);
    final totalGeral = rows.fold(0.0, (s, r) => s + r.total);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildSimpleHeader('Relatorio de Custos', 'Por veiculo'),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              _resumoBox('Manutencao', _brl.format(totalManut), PdfColors.red200, PdfColors.red800),
              pw.SizedBox(width: 8),
              _resumoBox('Despesas', _brl.format(totalDesp), PdfColors.amber200, PdfColors.amber800),
              pw.SizedBox(width: 8),
              _resumoBox('Combustivel', _brl.format(totalComb), PdfColors.orange200, PdfColors.orange800),
              pw.SizedBox(width: 8),
              _resumoBox('Total Geral', _brl.format(totalGeral), PdfColors.blue200, PdfColors.blue800),
            ],
          ),
          pw.SizedBox(height: 24),
          _buildCustosTable(rows),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildCustosTable(List<CustoPdfRow> rows) {
    final cellStyle = pw.TextStyle(fontSize: 9);
    final boldCell = pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold());

    pw.Widget cell(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: bold ? boldCell : cellStyle),
      );
    }

    pw.Widget headerCell(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9, color: PdfColors.white)),
      );
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          headerCell('Veiculo'),
          headerCell('Placa'),
          headerCell('Manutencao'),
          headerCell('Despesas'),
          headerCell('Combustivel'),
          headerCell('Total'),
        ],
      ),
      ...rows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final isOdd = i % 2 == 1;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: isOdd ? PdfColors.grey100 : PdfColors.white),
          children: [
            cell(r.veiculoNome),
            cell(r.veiculoPlaca),
            cell(_brl.format(r.manutencao)),
            cell(_brl.format(r.despesas)),
            cell(_brl.format(r.combustivel)),
            cell(_brl.format(r.total), bold: true),
          ],
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(1.8),
        5: const pw.FlexColumnWidth(1.8),
      },
      children: tableRows,
    );
  }

  // ── Header simples ──────────────────────────────────────────────────

  static pw.Widget _buildSimpleHeader(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ATR Gestao de Frotas',
          style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 14, color: _navy),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, color: _orange, font: pw.Font.helveticaBold()),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Divider(color: _navy, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }
}
