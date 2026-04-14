/// Status operacional de um veículo da frota.
enum VehicleStatus {
  emRota('EM ROTA'),
  emOficina('EM OFICINA'),
  parado('PARADO'),
  reserva('RESERVA');

  const VehicleStatus(this.label);

  /// Texto de exibição na UI.
  final String label;
}
