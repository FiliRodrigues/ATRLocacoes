import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/data/custos_models.dart';
import '../../../core/data/fleet_data.dart';
import '../../../core/enums/kanban_column.dart';
import '../../../core/enums/maintenance_priority.dart';
import '../../../core/theme/app_colors.dart';

class MaintenanceFormModal {
  static Future<ManutencaoItem?> show(
    BuildContext context, {
    required FleetRepository fleet,
    ManutencaoItem? item,
  }) {
    final formKey = GlobalKey<FormState>();

    final tituloCtrl = TextEditingController(text: item?.titulo ?? '');
    final descricaoCtrl = TextEditingController(text: item?.descricao ?? '');
    final dataCtrl = TextEditingController(
      text: item != null ? formatDate(item.data) : '',
    );
    final kmCtrl = TextEditingController(
      text: item != null && (item.odometro > 0 || item.kmNoServico > 0)
          ? (item.odometro > 0 ? item.odometro : item.kmNoServico).toString()
          : '',
    );
    final conclusaoCtrl = TextEditingController(
      text: item?.dataConclusao != null ? formatDate(item!.dataConclusao!) : '',
    );
    final custoCtrl = TextEditingController(
      text: item != null && item.custo > 0 ? item.custo.toStringAsFixed(2) : '',
    );
    final fornecedorCtrl = TextEditingController(text: item?.fornecedor ?? '');
    final numeroOSCtrl = TextEditingController(text: item?.numeroOS ?? '');

    String? veiculoPlaca = item?.veiculoPlaca;
    String veiculoNome = item?.veiculoNome ?? '';
    String? tipoSelecionado = item?.tipo;
    DateTime? dataSelecionada = item?.data;
    DateTime? dataConclusaoSelecionada = item?.dataConclusao;
    MaintenancePriority prioridade = item?.prioridade == MaintenancePriority.ok
        ? MaintenancePriority.baixa
        : (item?.prioridade ?? MaintenancePriority.media);
    KanbanColumn coluna = item?.coluna ?? KanbanColumn.pendentes;
    bool isPreventiva = item?.isPreventiva ?? true;

    return showDialog<ManutencaoItem>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> selecionarData() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: dataSelecionada ?? now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  dataSelecionada = picked;
                  dataCtrl.text = formatDate(picked);
                });
              }
            }

            Future<void> selecionarDataConclusao() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: dataConclusaoSelecionada ?? dataSelecionada ?? now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  dataConclusaoSelecionada = picked;
                  conclusaoCtrl.text = formatDate(picked);
                });
              }
            }

            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item == null ? 'Nova Ordem de Servico' : 'Editar OS',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: veiculoPlaca,
                          items: fleet.frota
                              .map(
                                (v) => DropdownMenuItem<String>(
                                  value: v.placa,
                                  child: Text('${v.nome} - ${v.placa}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            final veiculo =
                                fleet.getVehicleByPlate(value ?? '');
                            setState(() {
                              veiculoPlaca = value;
                              veiculoNome =
                                  veiculo?.nome.split(' ').first ?? '';
                            });
                          },
                          decoration:
                              const InputDecoration(labelText: 'Veiculo'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Selecione um veiculo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: tituloCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Titulo da OS'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Titulo obrigatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: tipoSelecionado,
                          items: const [
                            'Revisao Periodica',
                            'Troca de Oleo',
                            'Pneus',
                            'Freios',
                            'Eletrica',
                            'Funilaria',
                            'Outro',
                          ]
                              .map(
                                (t) => DropdownMenuItem<String>(
                                  value: t,
                                  child: Text(t),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => tipoSelecionado = value),
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tipo obrigatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descricaoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descricao (opcional)',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dataCtrl,
                          readOnly: true,
                          onTap: selecionarData,
                          decoration:
                              const InputDecoration(labelText: 'Data Agendada'),
                          validator: (value) {
                            if (dataSelecionada == null) {
                              return 'Data obrigatoria';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: kmCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Hodometro Atual (Km)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Tipo de Servico'),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Preventiva'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Corretiva'),
                            ),
                          ],
                          selected: {isPreventiva},
                          onSelectionChanged: (selection) {
                            setState(() => isPreventiva = selection.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: custoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Custo Estimado R\$ (opcional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Prioridade'),
                        const SizedBox(height: 8),
                        SegmentedButton<MaintenancePriority>(
                          segments: const [
                            ButtonSegment<MaintenancePriority>(
                              value: MaintenancePriority.alta,
                              label: Text('Alta'),
                            ),
                            ButtonSegment<MaintenancePriority>(
                              value: MaintenancePriority.media,
                              label: Text('Media'),
                            ),
                            ButtonSegment<MaintenancePriority>(
                              value: MaintenancePriority.baixa,
                              label: Text('Baixa'),
                            ),
                          ],
                          selected: {prioridade},
                          onSelectionChanged: (selection) {
                            setState(() => prioridade = selection.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fornecedorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Fornecedor / Oficina (opcional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: numeroOSCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Numero OS (opcional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<KanbanColumn>(
                          initialValue: coluna,
                          items: const [
                            DropdownMenuItem(
                              value: KanbanColumn.pendentes,
                              child: Text('Pendente'),
                            ),
                            DropdownMenuItem(
                              value: KanbanColumn.emOficina,
                              child: Text('Em Oficina'),
                            ),
                            DropdownMenuItem(
                              value: KanbanColumn.concluidos,
                              child: Text('Concluido'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              coluna = value;
                              if (coluna != KanbanColumn.concluidos) {
                                dataConclusaoSelecionada = null;
                                conclusaoCtrl.clear();
                              }
                            });
                          },
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                        ),
                        if (coluna == KanbanColumn.concluidos) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: conclusaoCtrl,
                            readOnly: true,
                            onTap: selecionarDataConclusao,
                            decoration: const InputDecoration(
                              labelText: 'Data de Conclusao',
                            ),
                            validator: (value) {
                              if (coluna == KanbanColumn.concluidos &&
                                  dataConclusaoSelecionada == null) {
                                return 'Data de conclusao obrigatoria';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.atrOrange,
                              ),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                final veiculo =
                                    fleet.getVehicleByPlate(veiculoPlaca ?? '');
                                final parsedCusto = double.tryParse(
                                      custoCtrl.text
                                          .trim()
                                          .replaceAll(',', '.'),
                                    ) ??
                                    0.0;
                                final parsedOdometro =
                                    int.tryParse(kmCtrl.text.trim()) ?? 0;
                                final nomeAnexoAtual = item?.nomeAnexo ?? '';
                                final dataConclusaoFinal =
                                  coluna == KanbanColumn.concluidos
                                    ? (dataConclusaoSelecionada ??
                                      dataSelecionada)
                                    : null;
                                final result = ManutencaoItem(
                                  id: item?.id ??
                                      DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString(),
                                  veiculoPlaca: veiculoPlaca!,
                                  veiculoNome: veiculoNome.isNotEmpty
                                      ? veiculoNome
                                      : (veiculo?.nome.split(' ').first ?? ''),
                                  titulo: tituloCtrl.text.trim(),
                                  descricao: descricaoCtrl.text.trim(),
                                  tipo: tipoSelecionado!,
                                  data: dataSelecionada!,
                                  kmNoServico: parsedOdometro,
                                  odometro: parsedOdometro,
                                  custo: parsedCusto,
                                  prioridade: prioridade,
                                  coluna: coluna,
                                  fornecedor: fornecedorCtrl.text.trim(),
                                  numeroOS: numeroOSCtrl.text.trim(),
                                  nomeAnexo: nomeAnexoAtual,
                                  isPreventiva: isPreventiva,
                                    dataConclusao: dataConclusaoFinal,
                                );
                                Navigator.of(context).pop(result);
                              },
                              child: const Text('Salvar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      tituloCtrl.dispose();
      descricaoCtrl.dispose();
      dataCtrl.dispose();
      kmCtrl.dispose();
      conclusaoCtrl.dispose();
      custoCtrl.dispose();
      fornecedorCtrl.dispose();
      numeroOSCtrl.dispose();
    });
  }
}
