import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// Barra de filtros reutilizável para a aba de despesas/custos.
///
/// Recebe callbacks e valores atuais; não mantém estado próprio (stateless).
/// Layout responsivo via [Wrap] com spacing=12 e runSpacing=8.
class CustosFilterBar extends StatelessWidget {
  /// Placa do veículo selecionado (null = "Todos").
  final String? veiculoSelecionado;

  /// Tipo de despesa selecionado (null = "Todos").
  final String? tipoSelecionado;

  /// Range de datas selecionado (null = "Qualquer data").
  final DateTimeRange? periodoSelecionado;

  /// Status de pagamento: null = "Todos", true = "Pagos", false = "Pendentes".
  final bool? statusPago;

  /// Se true, exibe o dropdown de status pago/pendente.
  final bool showPagoFilter;

  /// Lista de placas disponíveis para o dropdown de veículos.
  final List<String> placasDisponiveis;

  /// Lista de tipos de despesa disponíveis.
  final List<String> tiposDisponiveis;

  // ── Callbacks ──
  final ValueChanged<String?> onVeiculoChanged;
  final ValueChanged<String?> onTipoChanged;
  final ValueChanged<DateTimeRange?> onPeriodoChanged;
  final ValueChanged<bool?> onStatusPagoChanged;
  final VoidCallback onLimparFiltros;

  const CustosFilterBar({
    super.key,
    required this.veiculoSelecionado,
    required this.tipoSelecionado,
    required this.periodoSelecionado,
    required this.statusPago,
    required this.showPagoFilter,
    required this.placasDisponiveis,
    required this.tiposDisponiveis,
    required this.onVeiculoChanged,
    required this.onTipoChanged,
    required this.onPeriodoChanged,
    required this.onStatusPagoChanged,
    required this.onLimparFiltros,
  });

  /// Retorna true se qualquer filtro estiver ativo.
  bool get _temFiltroAtivo =>
      veiculoSelecionado != null ||
      tipoSelecionado != null ||
      periodoSelecionado != null ||
      (showPagoFilter && statusPago != null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // ── Dropdown Veículo ──
        _buildDropdown<String?>(
          context: context,
          isDark: isDark,
          icon: LucideIcons.truck,
          hint: 'Veículo',
          value: veiculoSelecionado,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            ...placasDisponiveis.map(
              (p) => DropdownMenuItem<String?>(value: p, child: Text(p)),
            ),
          ],
          onChanged: onVeiculoChanged,
        ),

        // ── Dropdown Tipo ──
        _buildDropdown<String?>(
          context: context,
          isDark: isDark,
          icon: LucideIcons.tag,
          hint: 'Tipo',
          value: tipoSelecionado,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            ...tiposDisponiveis.map(
              (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
            ),
          ],
          onChanged: onTipoChanged,
        ),

        // ── Botão Período ──
        _buildPeriodoButton(context, isDark),

        // ── Dropdown Status Pago (condicional) ──
        if (showPagoFilter)
          _buildDropdown<bool?>(
            context: context,
            isDark: isDark,
            icon: LucideIcons.checkCircle,
            hint: 'Status',
            value: statusPago,
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('Todos')),
              DropdownMenuItem<bool?>(value: true, child: Text('Pagos')),
              DropdownMenuItem<bool?>(value: false, child: Text('Pendentes')),
            ],
            onChanged: onStatusPagoChanged,
          ),

        // ── Botão Limpar Filtros (visível se algum filtro ativo) ──
        if (_temFiltroAtivo)
          TextButton.icon(
            onPressed: onLimparFiltros,
            icon: Icon(
              LucideIcons.x,
              size: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            label: Text(
              'Limpar Filtros',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Cria um dropdown estilizado com ícone prefixo.
  Widget _buildDropdown<T>({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String hint,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceElevatedDark
            : AppColors.surfaceElevatedLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.atrOrange),
          const SizedBox(width: 8),
          Flexible(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                hint: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                isExpanded: true,
                isDense: true,
                icon: const Icon(LucideIcons.chevronDown, size: 14),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                dropdownColor: isDark
                    ? AppColors.surfaceElevatedDark
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botão de período que abre o DateRangePicker do Material.
  Widget _buildPeriodoButton(BuildContext context, bool isDark) {
    final temPeriodo = periodoSelecionado != null;
    final label = temPeriodo
        ? '${_formatShortDate(periodoSelecionado!.start)} – ${_formatShortDate(periodoSelecionado!.end)}'
        : 'Qualquer data';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: periodoSelecionado,
          locale: const Locale('pt', 'BR'),
          builder: (ctx, child) {
            return Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: Theme.of(ctx).colorScheme.copyWith(
                      primary: AppColors.atrOrange,
                    ),
              ),
              child: child!,
            );
          },
        );
        onPeriodoChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: temPeriodo
              ? AppColors.atrOrange.withValues(alpha: 0.08)
              : (isDark
                  ? AppColors.surfaceElevatedDark
                  : AppColors.surfaceElevatedLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: temPeriodo
                ? AppColors.atrOrange.withValues(alpha: 0.4)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 14,
              color: temPeriodo ? AppColors.atrOrange : AppColors.atrOrange,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: temPeriodo ? FontWeight.w600 : FontWeight.normal,
                color: temPeriodo
                    ? AppColors.atrOrange
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formata data curta: dd/MM.
  String _formatShortDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
