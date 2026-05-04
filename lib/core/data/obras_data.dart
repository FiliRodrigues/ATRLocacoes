import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════
// OBRAS DATA — Sistema de Sinalização Viária e Acessibilidade Urbana
// Jan a Abr 2026 | 5 cidades | 8 equipes
// ═══════════════════════════════════════════════════════════════════════

// ── Cidades e Equipes ──────────────────────────────────────────────────
const List<String> obrasCidades = [
  'Dourados',
  'Paulínia',
  'Jarinu',
  'Indaiatuba',
  'Salto',
];

const List<String> obrasEquipes = [
  'Equipe Alpha',
  'Equipe Beta',
  'Equipe Gamma',
  'Equipe Delta',
  'Equipe Épsilon',
  'Equipe Zeta',
  'Equipe Eta',
  'Equipe Theta',
];

// ── Locais por cidade ──────────────────────────────────────────────────
const Map<String, List<String>> obrasLocaisPorCidade = {
  'Dourados': [
    'Av. Marcelino Pires',
    'R. Joaquim Teixeira Alves',
    'Av. Dom João VI',
    'R. Cuiabá',
    'Av. Weimar Gonçalves Torres',
    'Rod. BR-163',
    'R. Presidente Vargas',
  ],
  'Paulínia': [
    'Av. Prefeito José Lozano Araújo',
    'R. São Paulo',
    'Av. Comendador Aladino Selmi',
    'R. das Palmeiras',
    'Rod. SP-332',
    'Av. Brasil',
  ],
  'Jarinu': [
    'R. Dr. Arnaldo Rodrigues',
    'Av. Governador Adhemar',
    'R. XV de Novembro',
    'Rod. SP-360',
    'R. Rui Barbosa',
  ],
  'Indaiatuba': [
    'Av. Eng. Fábio Roberto Barnabé',
    'R. Joaquim Boer',
    'Av. Santos Dumont',
    'R. Porto Alegre',
    'Rod. Dom Pedro I',
    'Av. Antonio Maluf',
    'R. Souza Aranha',
  ],
  'Salto': [
    'Av. Gal. Francisco Glicério',
    'R. João Pessoa',
    'Av. Nove de Julho',
    'Rod. SP-75',
    'R. Prudente de Morais',
    'Av. Brasil',
  ],
};

// ── Tipos de Serviço ───────────────────────────────────────────────────
const List<String> obrasServicos = [
  'Pintura Fria',
  'Pintura Quente',
  'Fresa',
  'Pintura de Guia',
  'Sinalização Vertical (Área)',
  'Sinalização Vertical (Qtd)',
  'Acessibilidade (Volume)',
  'Acessibilidade (Qtd)',
  'Semafórica',
  'Dispositivos Auxiliares',
];

// ── Itens de detalhamento ──────────────────────────────────────────────
const List<String> placasTipos = [
  'R-1 (Parada Obrigatória)',
  'R-2 (Dê a Preferência)',
  'A-20 (Travessia de Pedestres)',
  'A-20a (Escolares)',
  'R-19 (Proibido Estacionar)',
  'R-6a (Sentido Único)',
  'R-6b (Sentido Duplo)',
  'D-1 (Divisão de Pista)',
  'D-7 (Curva)',
  'ES-1 (Escola)',
];

const List<String> ferragesTipos = [
  'Poste de Alumínio 3m',
  'Poste de Aço Galvanizado 3m',
  'Suporte Duplo',
  'Parafuso M12',
  'Abraçadeira Inox',
  'Sapata de Concreto',
];

const List<String> acessTipos = [
  'Rampa de Acessibilidade',
  'Piso Tátil Direcional',
  'Piso Tátil Alerta',
  'Botoeira Sonora',
  'Corrimão',
];

const List<String> semaforicaTipos = [
  'Controlador de Tráfego',
  'Semáforo Veicular Bichromático',
  'Semáforo Pedestre LED',
  'Detector de Veículos',
  'Botoeira de Travessia',
];

const List<String> dispositivosTipos = [
  'Cone Sinalização',
  'Delineador Refletivo',
  'Tachão Bidirecional',
  'Gradil Metálico',
  'Cavalete',
  'Fita Sinalizadora',
];

const List<String> itemEspecificacoes = [
  'Faixa de Pedestre',
  'Linha de Borda',
  'Linha de Centro',
  'Faixa Amarela Dupla',
  'BOX Interseção',
  'Chevron',
  'Zebrado',
  'Degrau/Escada',
  'Palavra PARE',
  'Símbolo Cadeirante',
];

// ═══════════════════════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════════════════════

class ObrasRegistro {
  final DateTime data;
  final String cidade;
  final String equipe;
  final String local;
  final String servico;
  final String item;
  final double qtd;
  final double medida;
  final double hotspray;
  final double extrudado;

  const ObrasRegistro({
    required this.data,
    required this.cidade,
    required this.equipe,
    required this.local,
    required this.servico,
    required this.item,
    required this.qtd,
    required this.medida,
    this.hotspray = 0,
    this.extrudado = 0,
  });
}

class ObrasResumo {
  double pinturaFria = 0;
  double pinturaQuente = 0;
  double hotspray = 0;
  double extrudado = 0;
  double fresa = 0;
  double pinturaGuia = 0;
  double sinalVertArea = 0;
  int sinalVertQtd = 0;
  double acessVolume = 0;
  int acessQtd = 0;
  int semaforica = 0;
  int dispAuxiliares = 0;

  double get totalPintura => pinturaFria + pinturaQuente;
  double get totalArea => pinturaFria + pinturaQuente + fresa + sinalVertArea;
}

class EquipeRanking {
  final String equipe;
  final double volumeTotal;
  final double mediaDiaria;
  final int diasTrabalhados;
  final String servicoPrincipal;
  final int numServicos;
  final Map<String, double> porCidade;
  final Map<String, double> porServico;

  const EquipeRanking({
    required this.equipe,
    required this.volumeTotal,
    required this.mediaDiaria,
    required this.diasTrabalhados,
    required this.servicoPrincipal,
    required this.numServicos,
    required this.porCidade,
    required this.porServico,
  });
}

class LocalRanking {
  final String local;
  final String cidade;
  final double volumeTotal;

  const LocalRanking({
    required this.local,
    required this.cidade,
    required this.volumeTotal,
  });
}

class ObrasAnomalia {
  final String tipo; // 'success' | 'warning' | 'info'
  final String mensagem;
  final String? detalhe;

  const ObrasAnomalia({
    required this.tipo,
    required this.mensagem,
    this.detalhe,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// GERAÇÃO DE DADOS
// ═══════════════════════════════════════════════════════════════════════

final List<ObrasRegistro> _cache = _gerarRegistros();
List<ObrasRegistro> get obrasRegistros => _cache;

List<ObrasRegistro> _gerarRegistros() {
  final rng = Random(42);
  final registros = <ObrasRegistro>[];
  final inicio = DateTime(2026);
  final fim = DateTime.now();

  final fatorCidade = {
    'Dourados': 1.15,
    'Paulínia': 1.10,
    'Jarinu': 0.98,
    'Indaiatuba': 0.85,
    'Salto': 0.70,
  };

  final equipesPorCidade = {
    'Dourados': ['Equipe Alpha', 'Equipe Beta'],
    'Paulínia': ['Equipe Gamma', 'Equipe Delta'],
    'Jarinu': ['Equipe Épsilon', 'Equipe Zeta'],
    'Indaiatuba': ['Equipe Eta', 'Equipe Alpha'],
    'Salto': ['Equipe Theta', 'Equipe Beta'],
  };

  final servicoPref = {
    'Equipe Alpha': 'Pintura Fria',
    'Equipe Beta': 'Pintura Fria',
    'Equipe Gamma': 'Pintura Quente',
    'Equipe Delta': 'Sinalização Vertical (Área)',
    'Equipe Épsilon': 'Pintura Fria',
    'Equipe Zeta': 'Acessibilidade (Volume)',
    'Equipe Eta': 'Pintura Quente',
    'Equipe Theta': 'Semafórica',
  };

  for (var dia = inicio;
      !dia.isAfter(fim);
      dia = dia.add(const Duration(days: 1))) {
    if (dia.weekday == DateTime.sunday) continue;

    for (final cidade in obrasCidades) {
      final locais = obrasLocaisPorCidade[cidade]!;
      final equipes = equipesPorCidade[cidade]!;

      for (final equipe in equipes) {
        final fc = fatorCidade[cidade]!;
        final sorte = rng.nextDouble();
        final diaChuva = sorte < 0.12;
        final diaManut = sorte >= 0.12 && sorte < 0.17;

        double fd;
        if (diaChuva) {
          fd = 0.05 + rng.nextDouble() * 0.15;
        } else if (diaManut) {
          fd = 0.0;
        } else {
          fd = 0.65 + rng.nextDouble() * 0.35;
        }
        if (dia.weekday == DateTime.saturday) fd *= 0.6;
        if (fd < 0.08) continue;

        final f = fc * fd;
        final local = locais[rng.nextInt(locais.length)];
        final pref = servicoPref[equipe]!;

        final numReg = 1 + rng.nextInt(3);
        final servicosEmUso = <String>{pref};
        while (servicosEmUso.length < numReg) {
          servicosEmUso.add(obrasServicos[rng.nextInt(obrasServicos.length)]);
        }

        for (final servico in servicosEmUso) {
          final item =
              itemEspecificacoes[rng.nextInt(itemEspecificacoes.length)];
          double qtd = 0;
          double medida = 0;
          double hotspray = 0;
          double extrudado = 0;

          switch (servico) {
            case 'Pintura Fria':
              medida = _r(rng, 25, 60) * f;
              qtd = 1;
              break;
            case 'Pintura Quente':
              final total = _r(rng, 8, 20) * f;
              final split = 0.4 + rng.nextDouble() * 0.3;
              hotspray = total * split;
              extrudado = total * (1 - split);
              medida = total;
              qtd = 1;
              break;
            case 'Fresa':
              medida = _r(rng, 0.5, 4.5) * f;
              qtd = 1;
              break;
            case 'Pintura de Guia':
              medida = _r(rng, 20, 80) * f;
              qtd = medida;
              break;
            case 'Sinalização Vertical (Área)':
              qtd = (_r(rng, 0.3, 2.0) * f).clamp(0.3, 50);
              medida = _r(rng, 0.1, 0.6) * f;
              break;
            case 'Sinalização Vertical (Qtd)':
              qtd = (_r(rng, 1, 5) * f).clamp(1, 30).roundToDouble();
              medida = qtd * (_r(rng, 0.08, 0.25));
              break;
            case 'Acessibilidade (Volume)':
              medida = _r(rng, 0.1, 0.8) * f;
              qtd = (_r(rng, 0.5, 3.0) * f).clamp(0.5, 20).roundToDouble();
              break;
            case 'Acessibilidade (Qtd)':
              qtd = (_r(rng, 0.5, 2.5) * f).clamp(0.5, 15).roundToDouble();
              medida = qtd * _r(rng, 0.05, 0.15);
              break;
            case 'Semafórica':
              qtd = (_r(rng, 1, 8) * f).clamp(1, 40).roundToDouble();
              medida = qtd;
              break;
            case 'Dispositivos Auxiliares':
              qtd = (_r(rng, 5, 25) * f).clamp(5, 100).roundToDouble();
              medida = qtd;
              break;
          }

          if (medida < 0.01 && qtd < 0.5) continue;

          registros.add(
            ObrasRegistro(
              data: dia,
              cidade: cidade,
              equipe: equipe,
              local: local,
              servico: servico,
              item: item,
              qtd: qtd,
              medida: medida,
              hotspray: hotspray,
              extrudado: extrudado,
            ),
          );
        }
      }
    }
  }
  return registros;
}

double _r(Random rng, double min, double max) =>
    min + rng.nextDouble() * (max - min);

// ═══════════════════════════════════════════════════════════════════════
// FUNÇÕES DE CONSULTA
// ═══════════════════════════════════════════════════════════════════════

List<ObrasRegistro> obrasRecs({
  String? cidade,
  String? equipe,
  String? servico,
  DateTime? dataFiltro,
  int? mes,
}) {
  return obrasRegistros.where((r) {
    if (cidade != null && r.cidade != cidade) return false;
    if (equipe != null && r.equipe != equipe) return false;
    if (servico != null && r.servico != servico) return false;
    if (mes != null && r.data.month != mes) return false;
    if (dataFiltro != null &&
        !(r.data.year == dataFiltro.year &&
            r.data.month == dataFiltro.month &&
            r.data.day == dataFiltro.day)) {
      return false;
    }
    return true;
  }).toList();
}

ObrasResumo obrasResumo({
  String? cidade,
  String? equipe,
  String? servico,
  int? mes,
}) {
  final r = ObrasResumo();
  for (final reg in obrasRecs(
    cidade: cidade,
    equipe: equipe,
    servico: servico,
    mes: mes,
  )) {
    switch (reg.servico) {
      case 'Pintura Fria':
        r.pinturaFria += reg.medida;
        break;
      case 'Pintura Quente':
        r.pinturaQuente += reg.medida;
        r.hotspray += reg.hotspray;
        r.extrudado += reg.extrudado;
        break;
      case 'Fresa':
        r.fresa += reg.medida;
        break;
      case 'Pintura de Guia':
        r.pinturaGuia += reg.medida;
        break;
      case 'Sinalização Vertical (Área)':
        r.sinalVertArea += reg.medida;
        break;
      case 'Sinalização Vertical (Qtd)':
        r.sinalVertQtd += reg.qtd.round();
        break;
      case 'Acessibilidade (Volume)':
        r.acessVolume += reg.medida;
        break;
      case 'Acessibilidade (Qtd)':
        r.acessQtd += reg.qtd.round();
        break;
      case 'Semafórica':
        r.semaforica += reg.qtd.round();
        break;
      case 'Dispositivos Auxiliares':
        r.dispAuxiliares += reg.qtd.round();
        break;
    }
  }
  return r;
}

double _recValue(ObrasRegistro r) {
  switch (r.servico) {
    case 'Sinalização Vertical (Qtd)':
    case 'Semafórica':
    case 'Dispositivos Auxiliares':
    case 'Acessibilidade (Qtd)':
      return r.qtd;
    default:
      return r.medida;
  }
}

List<MapEntry<DateTime, double>> obrasDiaPorServico({
  String? cidade,
  String? equipe,
  String? servico,
  int? mes,
}) {
  final recs =
      obrasRecs(cidade: cidade, equipe: equipe, servico: servico, mes: mes);
  final map = <String, double>{};
  for (final r in recs) {
    final key =
        '${r.data.year}-${r.data.month.toString().padLeft(2, '0')}-${r.data.day.toString().padLeft(2, '0')}';
    map[key] = (map[key] ?? 0) + _recValue(r);
  }
  return map.entries.map((e) {
    final parts = e.key.split('-');
    return MapEntry(
      DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      e.value,
    );
  }).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
}

List<EquipeRanking> obrasRanking({
  String? cidade,
  String? servico,
  bool porMedia = false,
  int? mes,
}) {
  final resultado = <EquipeRanking>[];
  for (final eq in obrasEquipes) {
    final recs =
        obrasRecs(cidade: cidade, equipe: eq, servico: servico, mes: mes);
    if (recs.isEmpty) continue;
    final dias = recs
        .map((r) => '${r.data.year}-${r.data.month}-${r.data.day}')
        .toSet()
        .length;
    double total = 0;
    final porServ = <String, double>{};
    final porCid = <String, double>{};
    for (final r in recs) {
      final val = _recValue(r);
      total += val;
      porServ[r.servico] = (porServ[r.servico] ?? 0) + val;
      porCid[r.cidade] = (porCid[r.cidade] ?? 0) + val;
    }
    final servPrincipal =
        porServ.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    resultado.add(
      EquipeRanking(
        equipe: eq,
        volumeTotal: total,
        mediaDiaria: dias > 0 ? total / dias : 0,
        diasTrabalhados: dias,
        servicoPrincipal: servPrincipal,
        numServicos: porServ.keys.length,
        porCidade: porCid,
        porServico: porServ,
      ),
    );
  }
  resultado.sort(
    (a, b) => porMedia
        ? b.mediaDiaria.compareTo(a.mediaDiaria)
        : b.volumeTotal.compareTo(a.volumeTotal),
  );
  return resultado;
}

List<LocalRanking> obrasLocaisRanking({
  String? cidade,
  String? equipe,
  int? mes,
}) {
  final map = <String, LocalRanking>{};
  for (final r in obrasRecs(cidade: cidade, equipe: equipe, mes: mes)) {
    final val = _recValue(r);
    final key = '${r.local}__${r.cidade}';
    if (map.containsKey(key)) {
      map[key] = LocalRanking(
        local: r.local,
        cidade: r.cidade,
        volumeTotal: map[key]!.volumeTotal + val,
      );
    } else {
      map[key] =
          LocalRanking(local: r.local, cidade: r.cidade, volumeTotal: val);
    }
  }
  return map.values.toList()
    ..sort((a, b) => b.volumeTotal.compareTo(a.volumeTotal));
}

List<DateTime> getDiasUteis({int? mes}) {
  final inicio = mes != null ? DateTime(2026, mes) : DateTime(2026);
  final DateTime fim;
  if (mes != null) {
    // último dia do mês (ou hoje se for o mês atual)
    final ultimoDia = DateTime(2026, mes + 1, 0);
    final hoje = DateTime.now();
    fim = ultimoDia.isBefore(hoje) ? ultimoDia : hoje;
  } else {
    fim = DateTime.now();
  }
  final dias = <DateTime>[];
  for (var d = inicio; !d.isAfter(fim); d = d.add(const Duration(days: 1))) {
    if (d.weekday != DateTime.sunday) dias.add(d);
  }
  return dias;
}

List<DateTime> getDiasSemProducao({String? cidade, String? equipe, int? mes}) {
  final diasComProd = obrasRecs(cidade: cidade, equipe: equipe, mes: mes)
      .map((r) => DateTime(r.data.year, r.data.month, r.data.day))
      .toSet();
  return getDiasUteis(mes: mes).where((d) => !diasComProd.contains(d)).toList();
}

List<DateTime> getDiasComPinturaAbaixo100({
  String? cidade,
  String? equipe,
  int? mes,
}) {
  final pintPorDia = <DateTime, double>{};
  for (final r in obrasRecs(cidade: cidade, equipe: equipe, mes: mes)) {
    if (r.servico != 'Pintura Fria' && r.servico != 'Pintura Quente') continue;
    final d = DateTime(r.data.year, r.data.month, r.data.day);
    pintPorDia[d] = (pintPorDia[d] ?? 0) + r.medida;
  }
  return pintPorDia.entries
      .where((e) => e.value > 0 && e.value < 100)
      .map((e) => e.key)
      .toList()
    ..sort();
}

List<DateTime> getDiasSemPintura({String? cidade, String? equipe, int? mes}) {
  final diasComProd = <DateTime>{};
  final diasComPintura = <DateTime>{};
  for (final r in obrasRecs(cidade: cidade, equipe: equipe, mes: mes)) {
    final d = DateTime(r.data.year, r.data.month, r.data.day);
    diasComProd.add(d);
    if (r.servico == 'Pintura Fria' || r.servico == 'Pintura Quente') {
      diasComPintura.add(d);
    }
  }
  return diasComProd.where((d) => !diasComPintura.contains(d)).toList()..sort();
}

List<ObrasAnomalia> obrasAlertas({String? cidade, String? equipe, int? mes}) {
  final alertas = <ObrasAnomalia>[];
  final recs = obrasRecs(cidade: cidade, equipe: equipe, mes: mes);
  if (recs.isEmpty) return alertas;

  final diasMedia = <DateTime, double>{};
  for (final r in recs) {
    if (r.servico != 'Pintura Fria' && r.servico != 'Pintura Quente') continue;
    final d = DateTime(r.data.year, r.data.month, r.data.day);
    diasMedia[d] = (diasMedia[d] ?? 0) + r.medida;
  }

  if (diasMedia.isNotEmpty) {
    final media = diasMedia.values.reduce((a, b) => a + b) / diasMedia.length;
    final maxVal = diasMedia.values.reduce((a, b) => a > b ? a : b);
    final maxDia = diasMedia.entries.firstWhere((e) => e.value == maxVal).key;
    if (maxVal >= media * 1.5) {
      alertas.add(
        ObrasAnomalia(
          tipo: 'success',
          mensagem: 'Recorde de pintura: ${maxVal.toStringAsFixed(0)} m²',
          detalhe:
              '${maxDia.day.toString().padLeft(2, '0')}/${maxDia.month.toString().padLeft(2, '0')}/${maxDia.year}',
        ),
      );
    }
    final diasBaixos = diasMedia.values.where((v) => v < media * 0.5).length;
    if (diasBaixos > 3) {
      alertas.add(
        ObrasAnomalia(
          tipo: 'warning',
          mensagem: '$diasBaixos dias com produção abaixo de 50% da média',
          detalhe: 'Média diária: ${media.toStringAsFixed(0)} m²',
        ),
      );
    }
  }

  final semProd = getDiasSemProducao(cidade: cidade, equipe: equipe, mes: mes);
  if (semProd.length > 5) {
    alertas.add(
      ObrasAnomalia(
        tipo: 'info',
        mensagem: '${semProd.length} dias úteis sem registro de produção',
        detalhe: cidade != null ? 'Em $cidade' : 'Consolidado geral',
      ),
    );
  }
  return alertas;
}

List<ObrasRegistro> obrasDetalheDia(
  DateTime dia, {
  String? cidade,
  String? equipe,
}) {
  return obrasRegistros.where((r) {
    if (r.data.year != dia.year ||
        r.data.month != dia.month ||
        r.data.day != dia.day) {
      return false;
    }
    if (cidade != null && r.cidade != cidade) return false;
    if (equipe != null && r.equipe != equipe) return false;
    return true;
  }).toList();
}

Map<String, Map<String, double>> obrasVerticalDetalhe({
  String? cidade,
  String? equipe,
}) {
  final recs = obrasRecs(
    cidade: cidade,
    equipe: equipe,
    servico: 'Sinalização Vertical (Qtd)',
  );
  final placas = <String, Map<String, double>>{};
  final rng = Random(7);
  for (final r in recs) {
    final tipo = placasTipos[rng.nextInt(placasTipos.length)];
    placas.putIfAbsent(tipo, () => {'qtd': 0, 'area': 0});
    placas[tipo]!['qtd'] = placas[tipo]!['qtd']! + r.qtd;
    placas[tipo]!['area'] = placas[tipo]!['area']! + r.medida;
  }
  return placas;
}

Map<String, double> obrasFerragens({String? cidade, String? equipe}) {
  final recs = obrasRecs(
    cidade: cidade,
    equipe: equipe,
    servico: 'Sinalização Vertical (Qtd)',
  );
  final map = <String, double>{};
  final rng = Random(11);
  for (final r in recs) {
    final ferro = ferragesTipos[rng.nextInt(ferragesTipos.length)];
    map[ferro] = (map[ferro] ?? 0) + r.qtd * (0.5 + rng.nextDouble());
  }
  return map;
}

Map<String, Map<String, double>> obrasAcessDetalhe({
  String? cidade,
  String? equipe,
}) {
  final recs = obrasRecs(
    cidade: cidade,
    equipe: equipe,
    servico: 'Acessibilidade (Volume)',
  );
  final map = <String, Map<String, double>>{};
  final rng = Random(13);
  for (final r in recs) {
    final tipo = acessTipos[rng.nextInt(acessTipos.length)];
    map.putIfAbsent(tipo, () => {'qtd': 0, 'volume': 0});
    map[tipo]!['qtd'] = map[tipo]!['qtd']! + r.qtd;
    map[tipo]!['volume'] = map[tipo]!['volume']! + r.medida;
  }
  return map;
}

Map<String, double> obrasSemaforicaDetalhe({String? cidade, String? equipe}) {
  final recs = obrasRecs(cidade: cidade, equipe: equipe, servico: 'Semafórica');
  final map = <String, double>{};
  final rng = Random(17);
  for (final r in recs) {
    final tipo = semaforicaTipos[rng.nextInt(semaforicaTipos.length)];
    map[tipo] = (map[tipo] ?? 0) + r.qtd;
  }
  return map;
}

Map<String, double> obrasDispositivosDetalhe({String? cidade, String? equipe}) {
  final recs = obrasRecs(
    cidade: cidade,
    equipe: equipe,
    servico: 'Dispositivos Auxiliares',
  );
  final map = <String, double>{};
  final rng = Random(19);
  for (final r in recs) {
    final tipo = dispositivosTipos[rng.nextInt(dispositivosTipos.length)];
    map[tipo] = (map[tipo] ?? 0) + r.qtd;
  }
  return map;
}

// Gerencial - Custos de producao (dados ficticios para visualizacao)
const int gerencialDiasMes = 30;
const double gerencialJantarPorPessoaDia = 34;

const List<String> gerencialCidades = ['Cidade X', 'Cidade Y', 'Cidade Z'];

const Map<String, double> gerencialHotelMedioPorPessoaDia = {
  'Cidade X': 220,
  'Cidade Y': 260,
  'Cidade Z': 290,
};

class GerencialEquipe {
  final String nome;
  final int funcionarios;
  final double folhaMensal;

  const GerencialEquipe({
    required this.nome,
    required this.funcionarios,
    required this.folhaMensal,
  });

  double get custoSalarialDia => folhaMensal / gerencialDiasMes;
  double get custoJantarDia => funcionarios * gerencialJantarPorPessoaDia;
}

const List<GerencialEquipe> gerencialEquipes = [
  GerencialEquipe(nome: 'Julio', funcionarios: 9, folhaMensal: 45000),
  GerencialEquipe(nome: 'Valdir', funcionarios: 6, folhaMensal: 38000),
  GerencialEquipe(nome: 'Marcelo', funcionarios: 4, folhaMensal: 30000),
];

class GerencialAlocacao {
  final String equipe;
  final String cidade;
  final int diasTrabalhados;

  const GerencialAlocacao({
    required this.equipe,
    required this.cidade,
    required this.diasTrabalhados,
  });
}

const Map<int, List<GerencialAlocacao>> _gerencialAlocacoesPorMes = {
  1: [
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade X', diasTrabalhados: 12),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Y', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Z', diasTrabalhados: 8),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade X', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Y', diasTrabalhados: 12),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Z', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade X', diasTrabalhados: 8),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Y', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Z', diasTrabalhados: 13),
  ],
  2: [
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade X', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Y', diasTrabalhados: 11),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Z', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade X', diasTrabalhados: 8),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Y', diasTrabalhados: 13),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Z', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade X', diasTrabalhados: 11),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Y', diasTrabalhados: 8),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Z', diasTrabalhados: 11),
  ],
  3: [
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade X', diasTrabalhados: 11),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Y', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Z', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade X', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Y', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Z', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade X', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Y', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Z', diasTrabalhados: 11),
  ],
  4: [
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade X', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Y', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Julio', cidade: 'Cidade Z', diasTrabalhados: 11),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade X', diasTrabalhados: 11),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Y', diasTrabalhados: 9),
    GerencialAlocacao(equipe: 'Valdir', cidade: 'Cidade Z', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade X', diasTrabalhados: 10),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Y', diasTrabalhados: 11),
    GerencialAlocacao(equipe: 'Marcelo', cidade: 'Cidade Z', diasTrabalhados: 9),
  ],
};

class GerencialEquipeCidadeResumo {
  final String equipe;
  final String cidade;
  final int funcionarios;
  final int diasTrabalhados;
  final double custoSalarialDia;
  final double custoJantarDia;
  final double custoHotelDia;
  final double custoSalarialMes;
  final double custoJantarMes;
  final double custoHotelMes;

  const GerencialEquipeCidadeResumo({
    required this.equipe,
    required this.cidade,
    required this.funcionarios,
    required this.diasTrabalhados,
    required this.custoSalarialDia,
    required this.custoJantarDia,
    required this.custoHotelDia,
    required this.custoSalarialMes,
    required this.custoJantarMes,
    required this.custoHotelMes,
  });

  double get custoTotalDia => custoSalarialDia + custoJantarDia + custoHotelDia;
  double get custoTotalMes => custoSalarialMes + custoJantarMes + custoHotelMes;
}

class GerencialEquipeResumo {
  final String equipe;
  final int funcionarios;
  final int diasAlocados;
  final double custoSalarialMes;
  final double custoJantarMes;
  final double custoHotelMes;

  const GerencialEquipeResumo({
    required this.equipe,
    required this.funcionarios,
    required this.diasAlocados,
    required this.custoSalarialMes,
    required this.custoJantarMes,
    required this.custoHotelMes,
  });

  double get custoTotalMes => custoSalarialMes + custoJantarMes + custoHotelMes;
  double get custoMedioDia => diasAlocados > 0 ? custoTotalMes / diasAlocados : 0;
}

class GerencialCidadeResumo {
  final String cidade;
  final int diasAlocados;
  final double custoSalarialMes;
  final double custoJantarMes;
  final double custoHotelMes;

  const GerencialCidadeResumo({
    required this.cidade,
    required this.diasAlocados,
    required this.custoSalarialMes,
    required this.custoJantarMes,
    required this.custoHotelMes,
  });

  double get custoTotalMes => custoSalarialMes + custoJantarMes + custoHotelMes;
}

List<int> _mesesGerencial(int? mes) {
  if (mes != null) return [mes];
  final meses = _gerencialAlocacoesPorMes.keys.toList()..sort();
  return meses;
}

GerencialEquipe _getEquipeGerencial(String nome) {
  return gerencialEquipes.firstWhere((e) => e.nome == nome);
}

List<GerencialEquipeCidadeResumo> gerencialCustosEquipeCidade({int? mes}) {
  final acumulado = <String, GerencialEquipeCidadeResumo>{};
  for (final m in _mesesGerencial(mes)) {
    final alocacoes = _gerencialAlocacoesPorMes[m];
    if (alocacoes == null) continue;

    for (final aloc in alocacoes) {
      final equipe = _getEquipeGerencial(aloc.equipe);
      final hotelPessoaDia = gerencialHotelMedioPorPessoaDia[aloc.cidade] ?? 250;
      final custoHotelDia = equipe.funcionarios * hotelPessoaDia;
      final key = '${aloc.equipe}__${aloc.cidade}';

      final atual = acumulado[key];
      final custoSalarialMes = equipe.custoSalarialDia * aloc.diasTrabalhados;
      final custoJantarMes = equipe.custoJantarDia * aloc.diasTrabalhados;
      final custoHotelMes = custoHotelDia * aloc.diasTrabalhados;

      if (atual == null) {
        acumulado[key] = GerencialEquipeCidadeResumo(
          equipe: aloc.equipe,
          cidade: aloc.cidade,
          funcionarios: equipe.funcionarios,
          diasTrabalhados: aloc.diasTrabalhados,
          custoSalarialDia: equipe.custoSalarialDia,
          custoJantarDia: equipe.custoJantarDia,
          custoHotelDia: custoHotelDia,
          custoSalarialMes: custoSalarialMes,
          custoJantarMes: custoJantarMes,
          custoHotelMes: custoHotelMes,
        );
      } else {
        acumulado[key] = GerencialEquipeCidadeResumo(
          equipe: atual.equipe,
          cidade: atual.cidade,
          funcionarios: atual.funcionarios,
          diasTrabalhados: atual.diasTrabalhados + aloc.diasTrabalhados,
          custoSalarialDia: atual.custoSalarialDia,
          custoJantarDia: atual.custoJantarDia,
          custoHotelDia: atual.custoHotelDia,
          custoSalarialMes: atual.custoSalarialMes + custoSalarialMes,
          custoJantarMes: atual.custoJantarMes + custoJantarMes,
          custoHotelMes: atual.custoHotelMes + custoHotelMes,
        );
      }
    }
  }

  final itens = acumulado.values.toList()
    ..sort((a, b) => b.custoTotalMes.compareTo(a.custoTotalMes));
  return itens;
}

List<GerencialEquipeResumo> gerencialResumoPorEquipe({int? mes}) {
  final mapa = <String, GerencialEquipeResumo>{};
  for (final item in gerencialCustosEquipeCidade(mes: mes)) {
    final atual = mapa[item.equipe];
    if (atual == null) {
      mapa[item.equipe] = GerencialEquipeResumo(
        equipe: item.equipe,
        funcionarios: item.funcionarios,
        diasAlocados: item.diasTrabalhados,
        custoSalarialMes: item.custoSalarialMes,
        custoJantarMes: item.custoJantarMes,
        custoHotelMes: item.custoHotelMes,
      );
    } else {
      mapa[item.equipe] = GerencialEquipeResumo(
        equipe: atual.equipe,
        funcionarios: atual.funcionarios,
        diasAlocados: atual.diasAlocados + item.diasTrabalhados,
        custoSalarialMes: atual.custoSalarialMes + item.custoSalarialMes,
        custoJantarMes: atual.custoJantarMes + item.custoJantarMes,
        custoHotelMes: atual.custoHotelMes + item.custoHotelMes,
      );
    }
  }

  final itens = mapa.values.toList()
    ..sort((a, b) => b.custoTotalMes.compareTo(a.custoTotalMes));
  return itens;
}

List<GerencialCidadeResumo> gerencialResumoPorCidade({int? mes}) {
  final mapa = <String, GerencialCidadeResumo>{};
  for (final item in gerencialCustosEquipeCidade(mes: mes)) {
    final atual = mapa[item.cidade];
    if (atual == null) {
      mapa[item.cidade] = GerencialCidadeResumo(
        cidade: item.cidade,
        diasAlocados: item.diasTrabalhados,
        custoSalarialMes: item.custoSalarialMes,
        custoJantarMes: item.custoJantarMes,
        custoHotelMes: item.custoHotelMes,
      );
    } else {
      mapa[item.cidade] = GerencialCidadeResumo(
        cidade: atual.cidade,
        diasAlocados: atual.diasAlocados + item.diasTrabalhados,
        custoSalarialMes: atual.custoSalarialMes + item.custoSalarialMes,
        custoJantarMes: atual.custoJantarMes + item.custoJantarMes,
        custoHotelMes: atual.custoHotelMes + item.custoHotelMes,
      );
    }
  }

  final itens = mapa.values.toList()
    ..sort((a, b) => b.custoTotalMes.compareTo(a.custoTotalMes));
  return itens;
}
