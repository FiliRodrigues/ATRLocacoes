// ═══════════════════════════════════════════════════════════════════════
// Modelos para o módulo de combustível
// ═══════════════════════════════════════════════════════════════════════

enum TipoCombustivel { gasolina, etanol, diesel, gnv, eletrico }

class Abastecimento {
  final String id;
  final String veiculoPlaca;
  final DateTime data;
  final double litros;
  final double valorTotal;
  final double kmOdometro;
  final TipoCombustivel tipo;
  final String? posto;
  final String registradoPor;
  final String tenantId;
  final String? fotoUrl;

  const Abastecimento({
    required this.id,
    required this.veiculoPlaca,
    required this.data,
    required this.litros,
    required this.valorTotal,
    required this.kmOdometro,
    required this.tipo,
    this.posto,
    required this.registradoPor,
    required this.tenantId,
    this.fotoUrl,
  });

  double get precoPorLitro => litros > 0 ? valorTotal / litros : 0.0;

  Map<String, dynamic> toRow() => {
        'id': id,
        'veiculo_placa': veiculoPlaca,
        'data': data.toIso8601String(),
        'litros': litros,
        'valor_total': valorTotal,
        'km_odometro': kmOdometro,
        'tipo': tipo.name,
        'posto': posto,
        'registrado_por': registradoPor,
        'tenant_id': tenantId,
        if (fotoUrl != null) 'foto_url': fotoUrl,
      };

  factory Abastecimento.fromRow(Map<String, dynamic> row) => Abastecimento(
        id: row['id'] as String,
        veiculoPlaca: row['veiculo_placa'] as String,
        data: DateTime.tryParse(row['data']?.toString() ?? '') ?? DateTime.now(),
        litros: (row['litros'] as num).toDouble(),
        valorTotal: (row['valor_total'] as num).toDouble(),
        kmOdometro: (row['km_odometro'] as num).toDouble(),
        tipo: TipoCombustivel.values.firstWhere(
          (t) => t.name == (row['tipo'] as String),
          orElse: () => TipoCombustivel.gasolina,
        ),
        posto: row['posto'] as String?,
        registradoPor: row['registrado_por'] as String? ?? '',
        tenantId: row['tenant_id'] as String,
        fotoUrl: row['foto_url'] as String?,
      );
}

/// KPIs calculados por veículo a partir dos abastecimentos.
class CombustivelKpi {
  final String veiculoPlaca;
  final int totalAbastecimentos;
  final double totalLitros;
  final double totalGasto;
  final double kmMedia; // km/l médio
  final double custoKm; // R$/km
  final double precoMedioLitro;
  final DateTime? ultimoAbastecimento;

  const CombustivelKpi({
    required this.veiculoPlaca,
    required this.totalAbastecimentos,
    required this.totalLitros,
    required this.totalGasto,
    required this.kmMedia,
    required this.custoKm,
    required this.precoMedioLitro,
    this.ultimoAbastecimento,
  });
}
