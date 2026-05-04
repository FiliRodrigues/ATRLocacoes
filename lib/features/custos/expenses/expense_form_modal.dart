import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/theme/app_colors.dart';

/// Modal de formulário para criar/editar uma [DespesaItem].
///
/// Uso:
/// ```dart
/// final result = await ExpenseFormModal.show(context, item: existingItem);
/// if (result != null) { /* salvar */ }
/// ```
class ExpenseFormModal {
  ExpenseFormModal._(); // Impede instância direta.

  /// Tipos de despesa disponíveis no formulário.
  static const List<String> tiposDespesa = [
    'Combustível',
    'Abastecimento',
    'Pedágio',
    'Lavagem',
    'Multa',
    'Seguro',
    'IPVA',
    'Manutenção',
    'Outro',
  ];

  /// Exibe o modal e retorna um [DespesaItem] preenchido ou null se cancelado.
  static Future<DespesaItem?> show(
    BuildContext context, {
    DespesaItem? item,
    String? initialTipo,
  }) {
    final repo = FleetRepository.instance;
    final isEditing = item != null;

    // ── Controllers ──
    final motoristaCtrl = TextEditingController(text: item?.motorista ?? '');
    final descricaoCtrl = TextEditingController(text: item?.descricao ?? '');
    final valorCtrl = TextEditingController(
      text: item != null
          ? item.valor.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    final dataCtrl = TextEditingController(
      text: item != null ? formatDate(item.data) : '',
    );
    final odometroCtrl = TextEditingController(
      text: item != null && item.odometro > 0 ? item.odometro.toString() : '',
    );
    final litrosCtrl = TextEditingController(
      text: item != null && item.litros > 0
          ? item.litros.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    final nfCtrl = TextEditingController(text: item?.nf ?? '');

    // ── State local do modal ──
    String? placaSelecionada = item?.veiculoPlaca;
    String? tipoSelecionado = item?.tipo ?? initialTipo;
    DateTime? dataSelecionada = item?.data;
    bool pago = item?.pago ?? false;
    String nomeAnexo = item?.nomeAnexo ?? '';
    String? formError;
    final formKey = GlobalKey<FormState>();

    return showDialog<DespesaItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.atrOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? LucideIcons.edit2 : LucideIcons.plusCircle,
                      size: 20,
                      color: AppColors.atrOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Despesa' : 'Nova Despesa',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Veículo* ──
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Veículo *',
                            prefixIcon: Icon(LucideIcons.truck, size: 16),
                          ),
                          initialValue: placaSelecionada,
                          items: repo.frota
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.placa,
                                  child: Text('${v.placa} - ${v.nome}'),
                                ),
                              )
                              .toList(),
                          validator: (v) =>
                              v == null ? 'Selecione um veículo' : null,
                          onChanged: (placa) {
                            setModalState(() {
                              placaSelecionada = placa;
                              formError = null;
                              // Auto-preenche motorista ao selecionar veículo
                              if (placa != null) {
                                final vehicle = repo.frota.firstWhere(
                                  (v) => v.placa == placa,
                                  orElse: () => repo.frota.first,
                                );
                                motoristaCtrl.text = vehicle.motorista;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Motorista (auto-preenchido) ──
                        TextFormField(
                          controller: motoristaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Motorista',
                            prefixIcon: Icon(LucideIcons.user, size: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Tipo* + Data* ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Tipo *',
                                  prefixIcon: Icon(LucideIcons.tag, size: 16),
                                ),
                                initialValue: tipoSelecionado,
                                items: tiposDespesa
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t),
                                        ),)
                                    .toList(),
                                validator: (v) =>
                                    v == null ? 'Selecione o tipo' : null,
                                onChanged: (v) => setModalState(() {
                                  tipoSelecionado = v;
                                  formError = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: dataCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Data *',
                                  prefixIcon:
                                      Icon(LucideIcons.calendar, size: 16),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Selecione a data'
                                    : null,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate:
                                        dataSelecionada ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                    locale: const Locale('pt', 'BR'),
                                    builder: (bCtx, child) => Theme(
                                      data: Theme.of(bCtx).copyWith(
                                        colorScheme: Theme.of(bCtx)
                                            .colorScheme
                                            .copyWith(
                                              primary: AppColors.atrOrange,
                                            ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      dataSelecionada = picked;
                                      dataCtrl.text = formatDate(picked);
                                      formError = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Descrição (opcional) ──
                        TextFormField(
                          controller: descricaoCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descrição / Observação',
                            prefixIcon: Icon(LucideIcons.alignLeft, size: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: odometroCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Hodômetro (Km)',
                            prefixIcon: Icon(LucideIcons.gauge, size: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Valor* + NF ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: valorCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                decoration: const InputDecoration(
                                  labelText: 'Valor (R\$) *',
                                  prefixText: 'R\$ ',
                                  prefixIcon:
                                      Icon(LucideIcons.dollarSign, size: 16),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Informe o valor';
                                  }
                                  final parsed = _parseValor(v);
                                  if (parsed == null || parsed <= 0) {
                                    return 'Valor inválido';
                                  }
                                  return null;
                                },
                                onEditingComplete: () {
                                  // Formata como moeda ao perder foco
                                  final parsed = _parseValor(valorCtrl.text);
                                  if (parsed != null && parsed > 0) {
                                    valorCtrl.text = parsed
                                        .toStringAsFixed(2)
                                        .replaceAll('.', ',');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: nfCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Número NF',
                                  prefixIcon:
                                      Icon(LucideIcons.receipt, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_requiresLitros(tipoSelecionado)) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: litrosCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Litros (L) *',
                              prefixIcon: Icon(LucideIcons.droplets, size: 16),
                            ),
                            validator: (v) {
                              if (!_requiresLitros(tipoSelecionado)) {
                                return null;
                              }
                              if (v == null || v.trim().isEmpty) {
                                return 'Informe os litros';
                              }
                              final parsed = _parseValor(v);
                              if (parsed == null || parsed <= 0) {
                                return 'Litros inválidos';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── Switch Pago ──
                        Row(
                          children: [
                            Icon(
                              pago
                                  ? LucideIcons.checkCircle
                                  : LucideIcons.circle,
                              size: 18,
                              color: pago
                                  ? AppColors.statusSuccess
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pago ? 'Pago' : 'Pendente',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: pago
                                    ? AppColors.statusSuccess
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: pago,
                              activeThumbColor: AppColors.statusSuccess,
                              onChanged: (v) => setModalState(() => pago = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Anexo ──
                        GestureDetector(
                          onTap: () async {
                            final result = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setModalState(() => nomeAnexo = result.files.first.name);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: nomeAnexo.isEmpty
                                    ? AppColors.textSecondaryLight
                                        .withValues(alpha: 0.3)
                                    : AppColors.statusInfo,
                                width: nomeAnexo.isEmpty ? 1 : 1.5,
                              ),
                              color: nomeAnexo.isEmpty
                                  ? Colors.transparent
                                  : AppColors.statusInfo
                                      .withValues(alpha: 0.05),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  nomeAnexo.isEmpty
                                      ? LucideIcons.upload
                                      : LucideIcons.fileText,
                                  size: 18,
                                  color: nomeAnexo.isEmpty
                                      ? AppColors.textSecondaryLight
                                      : AppColors.statusInfo,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nomeAnexo.isEmpty
                                        ? 'Selecionar Arquivo'
                                        : nomeAnexo,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: nomeAnexo.isEmpty
                                          ? AppColors.textSecondaryLight
                                          : AppColors.statusInfo,
                                      fontWeight: nomeAnexo.isEmpty
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (nomeAnexo.isNotEmpty)
                                  GestureDetector(
                                    onTap: () =>
                                        setModalState(() => nomeAnexo = ''),
                                    child: Icon(
                                      LucideIcons.x,
                                      size: 16,
                                      color: AppColors.textSecondaryLight
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // ── Erro do formulário ──
                        if (formError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            formError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.atrOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text(
                    'Salvar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    final valor = _parseValor(valorCtrl.text);
                    if (valor == null || valor <= 0) {
                      setModalState(
                        () => formError = 'Valor deve ser maior que zero.',
                      );
                      return;
                    }

                    final litros = _requiresLitros(tipoSelecionado)
                        ? _parseValor(litrosCtrl.text)
                        : 0.0;
                    if (_requiresLitros(tipoSelecionado) &&
                        (litros == null || litros <= 0)) {
                      setModalState(() => formError = 'Informe os litros.');
                      return;
                    }

                    if (dataSelecionada == null) {
                      setModalState(() => formError = 'Selecione uma data.');
                      return;
                    }

                    final odometro =
                        int.tryParse(odometroCtrl.text.trim()) ?? 0;
                    final litrosValue = litros ?? 0.0;

                    final result = DespesaItem(
                      id: item?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      data: dataSelecionada!,
                      tipo: tipoSelecionado!,
                      veiculoPlaca: placaSelecionada!,
                      motorista: motoristaCtrl.text.trim(),
                      odometro: odometro,
                      litros: litrosValue,
                      valor: valor,
                      pago: pago,
                      descricao: descricaoCtrl.text.trim(),
                      nf: nfCtrl.text.trim(),
                      nomeAnexo: nomeAnexo,
                    );
                    Navigator.pop(ctx, result);
                  },
                ),
              ],
            );
          },
        ),
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!context.mounted) return;
        motoristaCtrl.dispose();
        descricaoCtrl.dispose();
        valorCtrl.dispose();
        dataCtrl.dispose();
        odometroCtrl.dispose();
        litrosCtrl.dispose();
        nfCtrl.dispose();
      });
    });
  }

  static bool _requiresLitros(String? tipo) {
    final normalized = tipo?.toLowerCase() ?? '';
    return normalized.contains('combust') || normalized.contains('abastec');
  }

  /// Converte string com vírgula/ponto para double.
  static double? _parseValor(String raw) {
    String cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '');
    // Remove "R$" se o usuário digitou
    cleaned = cleaned.replaceAll('R\$', '').trim();
    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Formato brasileiro: 1.234,56
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }
    return double.tryParse(cleaned);
  }
}
