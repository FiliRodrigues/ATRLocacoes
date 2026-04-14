/// Coluna do quadro Kanban de manutenções.
enum KanbanColumn {
  pendentes('Pendentes'),
  emOficina('Em Oficina'),
  concluidos('Concluídos');

  const KanbanColumn(this.label);

  /// Texto de exibição na UI.
  final String label;
}
