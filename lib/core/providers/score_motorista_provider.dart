import 'package:flutter/foundation.dart';
import '../data/fleet_data.dart';
import '../data/score_motorista_models.dart';

// ═══════════════════════════════════════════════════════════════════════
// Provider de Score de Motoristas — cálculo síncrono puro
// ═══════════════════════════════════════════════════════════════════════

class ScoreMotoristaProvider extends ChangeNotifier {
  /// Calcula e retorna scores ordenados por pontuação decrescente.
  /// Chamado inline no build() da tela — sem I/O assíncrono.
  List<ScoreMotorista> calcularScores(FleetRepository fleet) {
    final hoje = DateTime.now();
    final scores = <ScoreMotorista>[];

    for (final motorista in fleet.motoristas) {
      // ── Pontos CNH ────────────────────────────────────────────────
      final int pontosCnh;
      final diasParaVencer = motorista.vencimentoCNH.difference(hoje).inDays;

      switch (motorista.statusCNH) {
        case CnhStatus.ok:
          pontosCnh = diasParaVencer > 90 ? 30 : 15;
        case CnhStatus.vencendo:
          pontosCnh = 10;
        case CnhStatus.vencida:
          pontosCnh = 0;
      }

      // ── Pontos Multas ─────────────────────────────────────────────
      final int pontosMultas;
      switch (motorista.multas) {
        case 0:
          pontosMultas = 40;
        case 1:
          pontosMultas = 30;
        case 2:
          pontosMultas = 15;
        default:
          pontosMultas = 0;
      }

      // ── Pontos KM ─────────────────────────────────────────────────
      // km médio mensal: média de kmPorMes dos veículos vinculados
      final veiculosVinculados = fleet.frota
          .where((v) => motorista.placasVeiculos.contains(v.placa))
          .toList();

      final double kmMedio;
      if (veiculosVinculados.isEmpty) {
        kmMedio = 0;
      } else {
        kmMedio = veiculosVinculados
                .fold(0.0, (s, v) => s + v.kmPorMes) /
            veiculosVinculados.length;
      }

      final int pontosKm;
      if (kmMedio >= 3000 && kmMedio <= 6000) {
        pontosKm = 30;
      } else if (kmMedio < 1000) {
        pontosKm = 10;
      } else if (kmMedio > 8000) {
        pontosKm = 15;
      } else {
        pontosKm = 20;
      }

      final total = pontosCnh + pontosMultas + pontosKm;

      scores.add(ScoreMotorista(
        nomeMotorista: motorista.nome,
        telefone: motorista.telefone,
        pontuacaoTotal: total,
        pontosCnh: pontosCnh,
        pontosMultas: pontosMultas,
        pontosKm: pontosKm,
        classificacao: ScoreMotorista.classificarPorPontos(total),
        placasVeiculos: motorista.placasVeiculos,
        statusCnh: motorista.statusCNH,
        multas: motorista.multas,
        kmMedioMensal: kmMedio,
      ));
    }

    scores.sort((a, b) => b.pontuacaoTotal.compareTo(a.pontuacaoTotal));
    return scores;
  }
}
