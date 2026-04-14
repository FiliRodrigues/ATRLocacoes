/// Prioridade de uma ordem de serviço de manutenção.
enum MaintenancePriority {
  alta('ALTA'),
  media('MÉDIA'),
  baixa('BAIXA'),
  ok('OK');

  const MaintenancePriority(this.label);

  /// Texto de exibição na UI.
  final String label;
}
