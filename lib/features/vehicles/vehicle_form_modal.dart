import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/fleet_data.dart';
import '../../core/theme/app_colors.dart';

class VehicleFormModal {
  VehicleFormModal._();

  static const List<String> _locadorasFallback = [
    'ATR Locações',
    'Sala ATR',
    'Lazer',
    'Outros',
  ];

  static final RegExp _placaRegex = RegExp(r'^[A-Z]{3}[-\s]?\d{4}$|^[A-Z]{3}\d[A-Z]\d{2}$');

  static Future<List<String>> _carregarLocadoras() async {
    try {
      final tenantId = Supabase.instance.client.auth.currentUser
          ?.appMetadata['tenant_id'] as String?;
      if (tenantId == null) return _locadorasFallback;
      final resp = await Supabase.instance.client
          .from('locadoras')
          .select('nome')
          .eq('tenant_id', tenantId)
          .order('nome');
      final dbList = (resp as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['nome'] as String)
          .toList();
      final merged = <String>{..._locadorasFallback, ...dbList};
      return merged.toList()..sort();
    } catch (_) {
      return _locadorasFallback;
    }
  }

  static Future<void> show(
    BuildContext context, {
    VehicleData? vehicle,
  }) async {
    final isEditing = vehicle != null;
    final locadoras = await _carregarLocadoras();

    String modeloInicial = isEditing ? vehicle.nome : '';
    String anoInicial = '';
    String locadoraInicial = locadoras.first;
    String kmMesInicial = isEditing ? vehicle.kmPorMes.toStringAsFixed(0) : '3000';
    String kmHodometroInicial = isEditing && vehicle.kmHodometro != null
        ? vehicle.kmHodometro!.toStringAsFixed(0)
        : '';
    String valorVeiculoInicial = '';

    if (isEditing) {
      try {
        final row = await Supabase.instance.client
            .from('veiculos')
            .select('modelo, ano_fabricacao_modelo, km_atual, valor_veiculo')
            .eq('placa', vehicle.placa)
            .maybeSingle();
        if (row != null) {
          modeloInicial = (row['modelo'] as String?)?.trim().isNotEmpty == true
              ? (row['modelo'] as String).trim()
              : modeloInicial;
          final anoFabModelo = (row['ano_fabricacao_modelo'] as String?)?.trim();
          if (anoFabModelo != null && anoFabModelo.isNotEmpty) {
            anoInicial = anoFabModelo;
          }
          final kmAtualDb = (row['km_atual'] as num?)?.toDouble();
          if (kmAtualDb != null && kmAtualDb > 0) {
            kmHodometroInicial = kmAtualDb.toStringAsFixed(0);
          }
          final valorVeiculoDb = (row['valor_veiculo'] as num?)?.toDouble();
          if (valorVeiculoDb != null && valorVeiculoDb > 0) {
            valorVeiculoInicial = valorVeiculoDb.toStringAsFixed(2).replaceAll('.', ',');
          }
        }
      } catch (_) {
        // Mantém fallback com os dados já carregados no repositório.
      }
    }

    final placaCtrl = TextEditingController(text: isEditing ? vehicle.placa : '');
    final modeloCtrl = TextEditingController(text: modeloInicial);
    final anoCtrl = TextEditingController(text: anoInicial);
    final kmMesCtrl = TextEditingController(text: kmMesInicial);
    final kmHodometroCtrl = TextEditingController(text: kmHodometroInicial);
    final valorVeiculoCtrl = TextEditingController(text: valorVeiculoInicial);
    final formKey = GlobalKey<FormState>();
    String? locadoraSelecionada = locadoraInicial;
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> salvar() async {
            if (submitting) return;
            final valid = formKey.currentState?.validate() ?? false;
            if (!valid) return;

            final placa = placaCtrl.text.trim().toUpperCase();
            final modelo = modeloCtrl.text.trim();
            final ano = int.tryParse(anoCtrl.text.trim());
            final kmMes = _parseDouble(kmMesCtrl.text) ?? 3000;
            final kmHodometro = _parseDouble(kmHodometroCtrl.text);
            final valorVeiculo = _parseDouble(valorVeiculoCtrl.text);

            if (!isEditing && ano == null) {
              return;
            }

            setModalState(() => submitting = true);
            final repo = FleetRepository.instance;

            bool ok;
            if (isEditing) {
              ok = await repo.editVehicle(
                placa: vehicle.placa,
                novoModelo: modelo,
                novoAno: ano,
                novaLocadora: locadoraSelecionada,
                kmPorMes: kmMes,
                kmHodometro: kmHodometro,
                valorVeiculo: valorVeiculo,
              );
            } else {
              final id = await repo.addVehicle(
                placa: placa,
                modelo: modelo,
                ano: ano!,
                locadora: locadoraSelecionada ?? 'Outros',
                kmPorMes: kmMes,
                kmHodometro: kmHodometro,
                valorVeiculo: valorVeiculo,
              );
              ok = id != null;
            }

            if (!ctx.mounted) return;
            setModalState(() => submitting = false);

            if (ok) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEditing
                        ? 'Veículo atualizado com sucesso.'
                        : 'Veículo cadastrado com sucesso.',
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.statusError,
                  content: Text(
                    FleetRepository.instance.loadError ??
                        'Não foi possível salvar o veículo.',
                  ),
                ),
              );
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing ? LucideIcons.pencil : LucideIcons.plusCircle,
                  color: AppColors.atrOrange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(isEditing ? 'Editar Veículo' : 'Novo Veículo'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: placaCtrl,
                        readOnly: isEditing,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Placa',
                          prefixIcon: Icon(LucideIcons.badgeCheck, size: 16),
                        ),
                        onChanged: isEditing
                            ? null
                            : (value) {
                                final upper = value.toUpperCase();
                                if (upper == value) return;
                                placaCtrl.value = placaCtrl.value.copyWith(
                                  text: upper,
                                  selection: TextSelection.collapsed(offset: upper.length),
                                );
                              },
                        validator: (value) {
                          final v = (value ?? '').trim().toUpperCase();
                          if (v.isEmpty) return 'Placa é obrigatória';
                          if (!_placaRegex.hasMatch(v)) {
                            return 'Formato inválido (ex: ABC1D23)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modeloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Modelo',
                          prefixIcon: Icon(LucideIcons.car, size: 16),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Modelo é obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: anoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ano',
                          prefixIcon: Icon(LucideIcons.calendar, size: 16),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty && isEditing) return null;
                          if (text.isEmpty) return 'Ano é obrigatório';
                          if (text.length != 4) return 'Ano deve ter 4 dígitos';
                          final ano = int.tryParse(text);
                          final maxAno = DateTime.now().year + 1;
                          if (ano == null || ano < 2000 || ano > maxAno) {
                            return 'Ano inválido (2000 a $maxAno)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: locadoraSelecionada,
                        decoration: const InputDecoration(
                          labelText: 'Locadora',
                          prefixIcon: Icon(LucideIcons.building2, size: 16),
                        ),
                        items: locadoras
                            .map((locadora) => DropdownMenuItem<String>(
                                  value: locadora,
                                  child: Text(locadora),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => locadoraSelecionada = value);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Locadora é obrigatória';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: kmMesCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'KM/mês',
                          prefixIcon: Icon(LucideIcons.gauge, size: 16),
                        ),
                        validator: (value) {
                          final km = _parseDouble(value);
                          if (km == null || km <= 0) {
                            return 'Informe um KM/mês válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: kmHodometroCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'KM Hodômetro (opcional)',
                          prefixIcon: Icon(LucideIcons.gauge, size: 16),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          final km = _parseDouble(value);
                          if (km == null || km < 0) {
                            return 'Informe um KM válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: valorVeiculoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Valor do Veículo (R\$) - opcional',
                          prefixIcon: Icon(LucideIcons.dollarSign, size: 16),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          final v = _parseDouble(value);
                          if (v == null || v < 0) {
                            return 'Informe um valor válido';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: submitting ? null : salvar,
                child: Text(submitting ? 'Salvando...' : 'Salvar'),
              ),
            ],
          );
        },
      ),
    );

    placaCtrl.dispose();
    modeloCtrl.dispose();
    anoCtrl.dispose();
    kmMesCtrl.dispose();
    kmHodometroCtrl.dispose();
    valorVeiculoCtrl.dispose();
  }

  static double? _parseDouble(String? input) {
    if (input == null) return null;
    final normalized = input.trim().replaceAll('.', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}
