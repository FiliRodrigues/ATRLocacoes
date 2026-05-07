import '../enums/cnh_status.dart';

// ═══════════════════════════════════════════════════════════════════════
// Modelo de score calculado para um motorista
// ═══════════════════════════════════════════════════════════════════════

class ScoreMotorista {
  final String nomeMotorista;
  final String telefone;
  final int pontuacaoTotal;    // 0–100
  final int pontosCnh;         // 0–30
  final int pontosMultas;      // 0–40
  final int pontosKm;          // 0–30
  final String classificacao;  // 'Excelente' | 'Bom' | 'Regular' | 'Crítico'
  final List<String> placasVeiculos;
  final CnhStatus statusCnh;
  final int multas;
  final double kmMedioMensal;

  const ScoreMotorista({
    required this.nomeMotorista,
    required this.telefone,
    required this.pontuacaoTotal,
    required this.pontosCnh,
    required this.pontosMultas,
    required this.pontosKm,
    required this.classificacao,
    required this.placasVeiculos,
    required this.statusCnh,
    required this.multas,
    required this.kmMedioMensal,
  });

  static String classificarPorPontos(int pts) {
    if (pts >= 85) return 'Excelente';
    if (pts >= 65) return 'Bom';
    if (pts >= 45) return 'Regular';
    return 'Crítico';
  }
}
