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
}
