import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/navigation/app_router.dart';
import '../../core/widgets/atr_page_background.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/module_defs.dart';
import '../../core/widgets/sidebar_models.dart';
import '../../core/widgets/atr_top_bar.dart';
import '../../core/widgets/bookable_area_shared.dart';
import '../../core/services/auth_service.dart';

import '../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../core/utils/export_csv_io.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS INTERNOS (mapeiam lazer_eventos e lazer_despesas do Supabase)
// ─────────────────────────────────────────────────────────────────────────────
class _EventoItem {
  final String id;
  final String nome;
  final String tipo;
  final DateTime data;
  final String? local;
  final int? quantidadePessoas;
  final double receitaTotal;
  final double custoTotal;
  final String status;
  final String? observacoes;

  const _EventoItem({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.data,
    this.local,
    this.quantidadePessoas,
    required this.receitaTotal,
    required this.custoTotal,
    required this.status,
    this.observacoes,
  });

  factory _EventoItem.fromMap(Map<String, dynamic> m) => _EventoItem(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? '',
        tipo: m['tipo'] as String? ?? '',
        data: DateTime.parse(m['data'] as String),
        local: m['local'] as String?,
        quantidadePessoas: m['quantidade_pessoas'] as int?,
        receitaTotal: (m['receita_total'] as num?)?.toDouble() ?? 0,
        custoTotal: (m['custo_total'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? 'Planejado',
        observacoes: m['observacoes'] as String?,
      );

  // ── Getters que espelham a nomenclatura antiga (ReservaLazer) ──
  String get cliente => nome;
  String get tipoEvento => tipo;
  double get valor => receitaTotal;
  String get statusReserva => status;
  String get statusLimpeza =>
      status == 'realizada' ? 'concluido' : 'pendente';
}

class _DespesaItem {
  final String id;
  final String? eventoId;
  final String descricao;
  final double valor;
  final DateTime data;
  final String categoria;
  final bool pago;

  const _DespesaItem({
    required this.id,
    this.eventoId,
    required this.descricao,
    required this.valor,
    required this.data,
    required this.categoria,
    required this.pago,
  });

  factory _DespesaItem.fromMap(Map<String, dynamic> m) => _DespesaItem(
        id: m['id'].toString(),
        eventoId: m['evento_id'] as String?,
        descricao: m['descricao'] as String? ?? '',
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
        data: DateTime.parse(m['data'] as String),
        categoria: m['categoria'] as String? ?? 'outros',
        pago: m['pago'] as bool? ?? false,
      );

  String get status => pago ? 'pago' : 'pendente';
}

// ─────────────────────────────────────────────────────────────────────────────
// TIPOS DE EVENTO E CATEGORIAS (dropdowns)
// ─────────────────────────────────────────────────────────────────────────────
const _tiposEvento = [
  'Aniversário',
  'Churrasco',
  'Confraternização',
  'Casamento',
  'Festa Infantil',
  'Evento Corporativo',
  'Reunião Familiar',
];

const _categoriasDespesa = ['limpeza', 'manutenção', 'energia', 'outros'];

const _statusEvento = ['Planejado', 'Confirmada', 'Realizada', 'Cancelada'];

// ── Status helpers ─────────────────────────────────────────────────────────
Widget _badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

Widget _statusReserva(String status) {
  switch (status) {
    case 'Confirmada':
    case 'confirmada':
      return _badge('Confirmada', AppColors.statusInfo);
    case 'Realizada':
    case 'realizada':
      return _badge('Realizada', AppColors.statusSuccess);
    case 'Cancelada':
    case 'cancelada':
      return _badge('Cancelada', AppColors.statusError);
    case 'Planejado':
      return _badge('Planejado', AppColors.statusInfo);
    default:
      return _badge('Pendente', AppColors.statusWarning);
  }
}

Widget _statusLimpeza(String status) {
  if (status == 'concluido') {
    return _badge('Concluída', AppColors.statusSuccess);
  }
  return _badge('Pendente', AppColors.statusWarning);
}

// ═══════════════════════════════════════════════════════════════════════════
// ÁREA DE LAZER — 3 abas: Dashboard, Despesas, Agendamentos
// ═══════════════════════════════════════════════════════════════════════════
class LazerScreen extends StatefulWidget {
  const LazerScreen({super.key});

  @override
  State<LazerScreen> createState() => _LazerScreenState();
}

class _LazerScreenState extends State<LazerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _mesFiltro = DateTime(DateTime.now().year, DateTime.now().month);
  List<_EventoItem> _eventos = [];
  List<_DespesaItem> _despesas = [];
  bool _isLoading = true;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Tenant ──────────────────────────────────────────────────────────────
  String? get _tid =>
      _tenantId ??
      (Supabase.instance.client.auth.currentUser?.appMetadata ?? {})['tenant_id']
          as String?;

  // ── Data loading ────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    final tid = _tid;
    if (tid == null) {
      setState(() => _isLoading = false);
      return;
    }
    _tenantId = tid;
    try {
      final results = await Future.wait([
        _loadEventos(),
        _loadAllDespesas(),
      ]);
      setState(() {
        _eventos = results[0] as List<_EventoItem>;
        _despesas = results[1] as List<_DespesaItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  Future<List<_EventoItem>> _loadEventos() async {
    final resp = await Supabase.instance.client
        .from('lazer_eventos')
        .select('*')
        .eq('tenant_id', _tid!)
        .order('data', ascending: false);
    return (resp as List<dynamic>)
        .map((j) => _EventoItem.fromMap(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<_DespesaItem>> _loadAllDespesas() async {
    final resp = await Supabase.instance.client
        .from('lazer_despesas')
        .select('*')
        .eq('tenant_id', _tid!);
    return (resp as List<dynamic>)
        .map((j) => _DespesaItem.fromMap(j as Map<String, dynamic>))
        .toList();
  }

  // ── CRUD Eventos ────────────────────────────────────────────────────────
  Future<void> _criarEvento() async {
    final result = await _showEventoForm();
    if (result == null) return;
    try {
      await Supabase.instance.client.from('lazer_eventos').insert({
        'nome': result['nome'],
        'tipo': result['tipo'],
        'data': result['data'],
        'local': result['local'] ?? '',
        'quantidade_pessoas': result['quantidade_pessoas'],
        'receita_total': result['receita_total'],
        'custo_total': result['custo_total'],
        'status': result['status'],
        'observacoes': result['observacoes'],
        'tenant_id': _tid!,
      });
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao criar evento: $e')));
      }
    }
  }

  Future<void> _editarEvento(_EventoItem evento) async {
    final result = await _showEventoForm(evento: evento);
    if (result == null) return;
    try {
      await Supabase.instance.client
          .from('lazer_eventos')
          .update({
            'nome': result['nome'],
            'tipo': result['tipo'],
            'data': result['data'],
            'local': result['local'] ?? '',
            'quantidade_pessoas': result['quantidade_pessoas'],
            'receita_total': result['receita_total'],
            'custo_total': result['custo_total'],
            'status': result['status'],
            'observacoes': result['observacoes'],
          })
          .eq('id', evento.id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar evento: $e')));
      }
    }
  }

  Future<void> _excluirEvento(_EventoItem evento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Excluir evento?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${evento.nome}"?\nDespesas vinculadas também serão removidas.',
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      // Remove despesas vinculadas e depois o evento
      await Supabase.instance.client
          .from('lazer_despesas')
          .delete()
          .eq('evento_id', evento.id);
      await Supabase.instance.client
          .from('lazer_eventos')
          .delete()
          .eq('id', evento.id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir evento: $e')));
      }
    }
  }

  // ── CRUD Despesas ───────────────────────────────────────────────────────
  Future<void> _adicionarDespesa() async {
    final result = await _showDespesaForm();
    if (result == null) return;
    try {
      await Supabase.instance.client.from('lazer_despesas').insert({
        'evento_id': result['evento_id'],
        'descricao': result['descricao'],
        'valor': result['valor'],
        'data': result['data'],
        'categoria': result['categoria'],
        'pago': result['pago'],
        'tenant_id': _tid!,
      });
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao adicionar despesa: $e')));
      }
    }
  }

  Future<void> _toggleDespesaPago(_DespesaItem d) async {
    try {
      await Supabase.instance.client
          .from('lazer_despesas')
          .update({'pago': !d.pago}).eq('id', d.id);
      // Atualiza localmente para evitar reload completo
      setState(() {
        _despesas = _despesas.map((item) {
          if (item.id == d.id) {
            return _DespesaItem(
              id: item.id,
              eventoId: item.eventoId,
              descricao: item.descricao,
              valor: item.valor,
              data: item.data,
              categoria: item.categoria,
              pago: !item.pago,
            );
          }
          return item;
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao alterar status: $e')));
      }
    }
  }

  // ── Forms ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _showEventoForm({_EventoItem? evento}) async {
    final nomeCtrl = TextEditingController(text: evento?.nome ?? '');
    final tipoCtrl = TextEditingController(text: evento?.tipo ?? _tiposEvento[0]);
    final localCtrl = TextEditingController(text: evento?.local ?? '');
    final qtdCtrl =
        TextEditingController(text: evento?.quantidadePessoas?.toString() ?? '');
    final receitaCtrl =
        TextEditingController(text: evento?.receitaTotal.toString() ?? '0');
    final custoCtrl =
        TextEditingController(text: evento?.custoTotal.toString() ?? '0');
    final obsCtrl = TextEditingController(text: evento?.observacoes ?? '');
    DateTime dataSel =
        evento?.data ?? DateTime.now().add(const Duration(days: 7));
    String statusSel = evento?.status ?? 'Planejado';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputStyle = TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight);
    final labelStyle = TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: Text(
              evento == null ? 'Novo Evento' : 'Editar Evento',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _formField('Nome *', nomeCtrl, inputStyle),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _tiposEvento.contains(tipoCtrl.text)
                        ? tipoCtrl.text
                        : _tiposEvento[0],
                    dropdownColor: AppColors.surfaceElevatedDark,
                    style: inputStyle,
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: AppColors.surfaceElevatedDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _tiposEvento
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: inputStyle)))
                        .toList(),
                    onChanged: (v) => tipoCtrl.text = v ?? _tiposEvento[0],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dataSel,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: AppColors.atrOrange),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialog(() => dataSel = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data *',
                        labelStyle: labelStyle,
                        filled: true,
                        fillColor: AppColors.surfaceElevatedDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.borderDark),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(dataSel),
                        style: inputStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _formField('Local', localCtrl, inputStyle),
                  const SizedBox(height: 10),
                  _formField('Quantidade de Pessoas', qtdCtrl, inputStyle,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _formField('Receita Total (R\$)', receitaCtrl, inputStyle,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                  _formField('Custo Total (R\$)', custoCtrl, inputStyle,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _statusEvento.contains(statusSel)
                        ? statusSel
                        : 'Planejado',
                    dropdownColor: AppColors.surfaceElevatedDark,
                    style: inputStyle,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: AppColors.surfaceElevatedDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _statusEvento
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(s, style: inputStyle)))
                        .toList(),
                    onChanged: (v) =>
                        setDialog(() => statusSel = v ?? 'Planejado'),
                  ),
                  const SizedBox(height: 10),
                  _formField('Observações', obsCtrl, inputStyle, maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.textSecondaryDark)),
              ),
              TextButton(
                onPressed: () {
                  if (nomeCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, {
                    'nome': nomeCtrl.text.trim(),
                    'tipo': tipoCtrl.text,
                    'data': DateFormat('yyyy-MM-dd').format(dataSel),
                    'local': localCtrl.text.trim().isEmpty
                        ? null
                        : localCtrl.text.trim(),
                    'quantidade_pessoas': int.tryParse(qtdCtrl.text.trim()),
                    'receita_total':
                        double.tryParse(receitaCtrl.text.trim()) ?? 0,
                    'custo_total':
                        double.tryParse(custoCtrl.text.trim()) ?? 0,
                    'status': statusSel,
                    'observacoes': obsCtrl.text.trim().isEmpty
                        ? null
                        : obsCtrl.text.trim(),
                  });
                },
                child: Text(evento == null ? 'Criar' : 'Salvar',
                    style: const TextStyle(
                        color: AppColors.atrOrange,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        });
      },
    );

    nomeCtrl.dispose();
    tipoCtrl.dispose();
    localCtrl.dispose();
    qtdCtrl.dispose();
    receitaCtrl.dispose();
    custoCtrl.dispose();
    obsCtrl.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _showDespesaForm() async {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: _categoriasDespesa[0]);
    String? eventoIdSel = _eventos.isNotEmpty ? _eventos.first.id : null;
    DateTime dataSel = DateTime.now();
    bool pagoSel = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputStyle = TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight);
    final labelStyle = TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Text(
              'Nova Despesa',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_eventos.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _eventos.any((e) => e.id == eventoIdSel)
                          ? eventoIdSel
                          : _eventos.first.id,
                      dropdownColor: AppColors.surfaceElevatedDark,
                      style: inputStyle,
                      decoration: InputDecoration(
                        labelText: 'Evento *',
                        labelStyle: labelStyle,
                        filled: true,
                        fillColor: AppColors.surfaceElevatedDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.borderDark),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: _eventos
                          .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                '${e.nome} — ${DateFormat('dd/MM/yy').format(e.data)}',
                                style: inputStyle,
                                overflow: TextOverflow.ellipsis,
                              )))
                          .toList(),
                      onChanged: (v) =>
                          setDialog(() => eventoIdSel = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _formField('Descrição *', descCtrl, inputStyle),
                  const SizedBox(height: 10),
                  _formField('Valor (R\$) *', valorCtrl, inputStyle,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dataSel,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: AppColors.atrOrange),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialog(() => dataSel = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data *',
                        labelStyle: labelStyle,
                        filled: true,
                        fillColor: AppColors.surfaceElevatedDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.borderDark),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(dataSel),
                        style: inputStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _categoriasDespesa.contains(catCtrl.text)
                        ? catCtrl.text
                        : _categoriasDespesa[0],
                    dropdownColor: AppColors.surfaceElevatedDark,
                    style: inputStyle,
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: AppColors.surfaceElevatedDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: _categoriasDespesa
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: inputStyle)))
                        .toList(),
                    onChanged: (v) => catCtrl.text = v ?? _categoriasDespesa[0],
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: pagoSel,
                    onChanged: (v) => setDialog(() => pagoSel = v ?? false),
                    title:
                        const Text('Pago', style: TextStyle(color: Colors.white)),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.atrOrange,
                    contentPadding: EdgeInsets.zero,
                    checkColor: Colors.white,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.textSecondaryDark)),
              ),
              TextButton(
                onPressed: () {
                  if (descCtrl.text.trim().isEmpty) return;
                  final val = double.tryParse(valorCtrl.text.trim()) ?? 0;
                  Navigator.pop(ctx, {
                    'evento_id': eventoIdSel,
                    'descricao': descCtrl.text.trim(),
                    'valor': val,
                    'data': DateFormat('yyyy-MM-dd').format(dataSel),
                    'categoria': catCtrl.text,
                    'pago': pagoSel,
                  });
                },
                child: const Text('Adicionar',
                    style: TextStyle(
                        color: AppColors.atrOrange,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        });
      },
    );

    descCtrl.dispose();
    valorCtrl.dispose();
    catCtrl.dispose();
    return result;
  }

  Widget _formField(String label, TextEditingController ctrl, TextStyle style,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: style,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: label.length > 25 ? 11 : 13),
        filled: true,
        fillColor: AppColors.surfaceElevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  void _setMes(int delta) {
    setState(() {
      _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + delta);
    });
  }

  Future<void> _exportEventosCsv() async {
    final evtMes = _eventos
        .where((e) => e.data.month == _mesFiltro.month && e.data.year == _mesFiltro.year)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    final dateFmt = DateFormat('dd/MM/yyyy');
    final buffer = StringBuffer();
    buffer.writeln('"NOME";"TIPO";"DATA";"LOCAL";"PESSOAS";"RECEITA";"CUSTO";"STATUS"');

    for (final e in evtMes) {
      final receitaStr = e.receitaTotal.toStringAsFixed(2).replaceAll('.', ',');
      final custoStr = e.custoTotal.toStringAsFixed(2).replaceAll('.', ',');
      final pessoasStr = e.quantidadePessoas?.toString() ?? '';
      buffer.writeln(
        '${_csvField(e.nome)};${_csvField(e.tipo)};${_csvField(dateFmt.format(e.data))};${_csvField(e.local ?? '')};${_csvField(pessoasStr)};${_csvField(receitaStr)};${_csvField(custoStr)};${_csvField(e.status)}',
      );
    }

    try {
      final fileName = 'eventos_lazer_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportCsv(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exportado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e')),
        );
      }
    }
  }

  Future<void> _exportDespesasCsv() async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final buffer = StringBuffer();
    buffer.writeln('"DESCRICAO";"VALOR";"DATA";"CATEGORIA";"PAGO"');

    for (final d in _despesas) {
      final valorStr = d.valor.toStringAsFixed(2).replaceAll('.', ',');
      buffer.writeln(
        '${_csvField(d.descricao)};${_csvField(valorStr)};${_csvField(dateFmt.format(d.data))};${_csvField(d.categoria)};${_csvField(d.pago ? 'Sim' : 'Nao')}',
      );
    }

    try {
      final fileName = 'despesas_lazer_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportCsv(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exportado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e')),
        );
      }
    }
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mesAbrev = DateFormat('MMM/yyyy', 'pt_BR').format(_mesFiltro).toUpperCase();
    final currentUser = context.read<AuthService>().currentUser;
    final availableModules = currentUser == null ? <ModuleDef>[] : buildAvailableModules(currentUser);
    final sidebarItems = <SidebarItemDef>[
      SidebarItemDef(
        icon: LucideIcons.layoutDashboard,
        title: 'Dashboard',
        route: AppRoutes.lazer,
        feature: 'lazer',
        isActiveOverride: _tabController.index == 0,
        onTap: () => _tabController.animateTo(0),
      ),
      SidebarItemDef(
        icon: LucideIcons.receipt,
        title: 'Despesas',
        route: AppRoutes.lazer,
        feature: 'lazer',
        isActiveOverride: _tabController.index == 1,
        onTap: () => _tabController.animateTo(1),
      ),
      SidebarItemDef(
        icon: LucideIcons.calendarDays,
        title: 'Agendamentos',
        route: AppRoutes.lazer,
        feature: 'lazer',
        isActiveOverride: _tabController.index == 2,
        onTap: () => _tabController.animateTo(2),
      ),
      SidebarItemDef(
        icon: LucideIcons.barChart3,
        title: 'Consolidado',
        route: AppRoutes.lazer,
        feature: 'lazer',
        isActiveOverride: _tabController.index == 3,
        onTap: () => _tabController.animateTo(3),
      ),
    ];

    return AppSidebar(
      moduleName: 'Lazer',
      moduleIcon: LucideIcons.dumbbell,
      items: sidebarItems,
      availableModules: availableModules,
      child: Scaffold(
        body: AtrPageBackground(
          grid: true,
          child: Column(
            children: [
              AtrTopBar(
                title: 'Área de Lazer',
                subtitle: 'Gestão de Reservas',
                actions: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceHoverDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLightHex),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft, size: 18),
                          onPressed: () => _setMes(-1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            mesAbrev,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.chevronRight, size: 18),
                          onPressed: () => _setMes(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                color: isDark ? AppColors.atrNavyDarker : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.atrOrange,
                  unselectedLabelColor: isDark ? AppColors.textSecondaryDark : Colors.black54,
                  indicatorColor: AppColors.atrOrange,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(icon: Icon(LucideIcons.layoutDashboard, size: 18), text: 'Dashboard'),
                    Tab(icon: Icon(LucideIcons.receipt, size: 18), text: 'Despesas'),
                    Tab(icon: Icon(LucideIcons.calendarDays, size: 18), text: 'Agendamentos'),
                    Tab(icon: Icon(LucideIcons.barChart3, size: 18), text: 'Consolidado'),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.atrOrange))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _LazerDashboard(
                            eventos: _eventos,
                            despesas: _despesas,
                            mes: _mesFiltro,
                            isDark: isDark,
                          ),
                          _LazerDespesas(
                            eventos: _eventos,
                            despesas: _despesas,
                            mes: _mesFiltro,
                            isDark: isDark,
                            onAddDespesa: _adicionarDespesa,
                            onTogglePago: _toggleDespesaPago,
                            onExportCsv: _exportDespesasCsv,
                          ),
                          _LazerAgendamentos(
                            eventos: _eventos,
                            mes: _mesFiltro,
                            isDark: isDark,
                            onAddEvento: _criarEvento,
                            onEditEvento: _editarEvento,
                            onDeleteEvento: _excluirEvento,
                            onExportCsv: _exportEventosCsv,
                          ),
                          _LazerConsolidado(
                            eventos: _eventos,
                            despesas: _despesas,
                            ano: _mesFiltro.year,
                            isDark: isDark,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 0 — DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class _LazerDashboard extends StatelessWidget {
  final List<_EventoItem> eventos;
  final List<_DespesaItem> despesas;
  final DateTime mes;
  final bool isDark;
  const _LazerDashboard({
    required this.eventos,
    required this.despesas,
    required this.mes,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = mes.month;
    final a = mes.year;

    // ── Métricas do mês ──
    final evtMes = eventos
        .where((e) => e.data.month == m && e.data.year == a)
        .toList();
    final receita = evtMes
        .where((e) =>
            e.statusReserva == 'realizada' || e.statusReserva == 'Realizada')
        .fold(0.0, (s, e) => s + e.receitaTotal);
    final despMes = despesas
        .where((d) => d.data.month == m && d.data.year == a)
        .fold(0.0, (s, d) => s + d.valor);
    final lucro = receita - despMes;

    // Ocupação de fins de semana
    int totalFds = 0;
    int ocupados = 0;
    for (var d = DateTime(a, m);
        d.month == m;
        d = d.add(const Duration(days: 1))) {
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        totalFds++;
        final tem = eventos.any((e) =>
            e.data.year == d.year &&
            e.data.month == d.month &&
            e.data.day == d.day &&
            e.statusReserva != 'cancelada' &&
            e.statusReserva != 'Cancelada');
        if (tem) ocupados++;
      }
    }
    final ocupacao = totalFds == 0 ? 0.0 : (ocupados / totalFds) * 100;

    final realizadas = evtMes
        .where((e) =>
            e.statusReserva == 'realizada' || e.statusReserva == 'Realizada')
        .length;
    final confirmadas = evtMes
        .where((e) =>
            e.statusReserva == 'confirmada' ||
            e.statusReserva == 'Confirmada' ||
            e.statusReserva == 'Planejado')
        .length;
    final limpPend = evtMes
        .where((e) =>
            e.statusLimpeza == 'pendente' &&
            e.statusReserva != 'cancelada' &&
            e.statusReserva != 'Cancelada')
        .length;

    final proximas = eventos
        .where((e) =>
            e.statusReserva == 'confirmada' ||
            e.statusReserva == 'Confirmada' ||
            e.statusReserva == 'Planejado')
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    final proximasLimitadas = proximas.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs ──
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 48) / 4;
              return Row(
                children: [
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Receita do Mês',
                      value: fmt.format(receita),
                      icon: LucideIcons.trendingUp,
                      iconColor: AppColors.statusSuccess,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 0.ms),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Despesas',
                      value: fmt.format(despMes),
                      icon: LucideIcons.trendingDown,
                      iconColor: AppColors.statusError,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 60.ms),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Lucro Líquido',
                      value: fmt.format(lucro),
                      icon: LucideIcons.dollarSign,
                      iconColor:
                          lucro >= 0 ? AppColors.statusSuccess : AppColors.statusError,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 120.ms),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: '% Ocupação FDS',
                      value: '${ocupacao.toStringAsFixed(1)}%',
                      icon: LucideIcons.activity,
                      iconColor: AppColors.atrOrange,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 180.ms),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // ── Resumo de reservas ──
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 32) / 3;
              return Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: w,
                        child: BookableAreaKpiCard(
                          label: 'Realizadas',
                          value: '$realizadas',
                          icon: LucideIcons.checkCircle,
                          iconColor: AppColors.statusSuccess,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: w,
                        child: BookableAreaKpiCard(
                          label: 'Confirmadas',
                          value: '$confirmadas',
                          icon: LucideIcons.calendarCheck,
                          iconColor: AppColors.statusInfo,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: w,
                        child: BookableAreaKpiCard(
                          label: 'Limpezas Pendentes',
                          value: '$limpPend',
                          icon: LucideIcons.sparkles,
                          iconColor: AppColors.statusWarning,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Próximas Reservas',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (proximasLimitadas.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhuma reserva futura confirmada',
              icon: LucideIcons.calendarOff,
              isDark: isDark,
            )
          else
            ...proximasLimitadas
                .map((r) => _ReservaRow(evento: r, isDark: isDark)),
        ],
      ),
    );
  }
}

class _ReservaRow extends StatelessWidget {
  final _EventoItem evento;
  final bool isDark;
  const _ReservaRow({required this.evento, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFmt = DateFormat('dd/MM (EEE)', 'pt_BR');
    final bg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              dateFmt.format(evento.data),
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              evento.cliente,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              evento.tipoEvento,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              fmt.format(evento.valor),
              style: const TextStyle(
                color: AppColors.statusSuccess,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          _statusReserva(evento.statusReserva),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 1 — DESPESAS
// ═══════════════════════════════════════════════════════════════════════════
class _LazerDespesas extends StatelessWidget {
  final List<_EventoItem> eventos;
  final List<_DespesaItem> despesas;
  final DateTime mes;
  final bool isDark;
  final VoidCallback onAddDespesa;
  final void Function(_DespesaItem) onTogglePago;
  final VoidCallback onExportCsv;
  const _LazerDespesas({
    required this.eventos,
    required this.despesas,
    required this.mes,
    required this.isDark,
    required this.onAddDespesa,
    required this.onTogglePago,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = mes.month;
    final a = mes.year;
    final dsps =
        despesas.where((d) => d.data.month == m && d.data.year == a).toList();
    final total = dsps.fold(0.0, (s, d) => s + d.valor);
    final pendente = dsps
        .where((d) => d.status == 'pendente')
        .fold(0.0, (s, d) => s + d.valor);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Total de Despesas',
                  value: fmt.format(total),
                  icon: LucideIcons.receipt,
                  iconColor: AppColors.statusError,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Lançamentos',
                  value: '${dsps.length}',
                  icon: LucideIcons.fileText,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'A Pagar',
                  value: fmt.format(pendente),
                  icon: LucideIcons.alertCircle,
                  iconColor: AppColors.statusWarning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Lançamentos',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onExportCsv,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.download, size: 14, color: AppColors.textSecondaryLight),
                      SizedBox(width: 6),
                      Text('CSV',
                          style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAddDespesa,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.atrOrange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 14, color: AppColors.atrOrange),
                      SizedBox(width: 6),
                      Text('Adicionar',
                          style: TextStyle(
                              color: AppColors.atrOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dsps.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhuma despesa neste mês',
              icon: LucideIcons.inbox,
              isDark: isDark,
            )
          else
            _DespesasTable(
              despesas: dsps,
              fmt: fmt,
              isDark: isDark,
              onTogglePago: onTogglePago,
            ),
        ],
      ),
    );
  }
}

class _DespesasTable extends StatelessWidget {
  final List<_DespesaItem> despesas;
  final NumberFormat fmt;
  final bool isDark;
  final void Function(_DespesaItem) onTogglePago;
  const _DespesasTable({
    required this.despesas,
    required this.fmt,
    required this.isDark,
    required this.onTogglePago,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;

    final catColors = <String, Color>{
      'energia': AppColors.statusWarning,
      'limpeza': AppColors.statusInfo,
      'manutenção': AppColors.atrOrange,
      'outros': AppColors.textSecondaryDark,
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                BookableAreaTableCol('Data', flex: 2),
                BookableAreaTableCol('Descrição', flex: 4),
                BookableAreaTableCol('Categoria', flex: 2),
                BookableAreaTableCol('Valor', flex: 2),
                BookableAreaTableCol('Status', flex: 2),
              ],
            ),
          ),
          ...despesas.asMap().entries.map((e) {
            final d = e.value;
            final rowBg = e.key % 2 == 1
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02))
                : Colors.transparent;
            final catColor =
                catColors[d.categoria] ?? AppColors.textSecondaryDark;
            final statusColor = d.status == 'pago'
                ? AppColors.statusSuccess
                : AppColors.statusWarning;
            return Container(
              color: rowBg,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('dd/MM/yy').format(d.data),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      d.descricao,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      d.categoria,
                      style: TextStyle(
                        color: catColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmt.format(d.valor),
                      style: const TextStyle(
                        color: AppColors.statusError,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => onTogglePago(d),
                      child: _badge(
                        d.status == 'pago' ? 'Pago' : 'Pendente',
                        statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 2 — AGENDAMENTOS
// ═══════════════════════════════════════════════════════════════════════════
class _LazerAgendamentos extends StatefulWidget {
  final List<_EventoItem> eventos;
  final DateTime mes;
  final bool isDark;
  final VoidCallback onAddEvento;
  final void Function(_EventoItem) onEditEvento;
  final void Function(_EventoItem) onDeleteEvento;
  final VoidCallback onExportCsv;
  const _LazerAgendamentos({
    required this.eventos,
    required this.mes,
    required this.isDark,
    required this.onAddEvento,
    required this.onEditEvento,
    required this.onDeleteEvento,
    required this.onExportCsv,
  });

  @override
  State<_LazerAgendamentos> createState() => _LazerAgendamentosState();
}

class _LazerAgendamentosState extends State<_LazerAgendamentos> {
  String _statusFiltro = 'todos';
  String _ordenacao = 'data';
  bool _ordemAscendente = true;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final m = widget.mes.month;
    final a = widget.mes.year;
    final isDark = widget.isDark;

    var evtMes = widget.eventos
        .where((e) => e.data.month == m && e.data.year == a)
        .toList();
    if (_statusFiltro != 'todos') {
      evtMes = evtMes.where((r) => r.statusReserva.toLowerCase() == _statusFiltro).toList();
    }
    // Ordenacao
    evtMes.sort((x, y) {
      int result;
      switch (_ordenacao) {
        case 'nome':
          result = x.nome.toLowerCase().compareTo(y.nome.toLowerCase());
          break;
        case 'valor':
          result = x.receitaTotal.compareTo(y.receitaTotal);
          break;
        default: // data
          result = x.data.compareTo(y.data);
      }
      return _ordemAscendente ? result : -result;
    });

    final todasMes = widget.eventos
        .where((e) => e.data.month == m && e.data.year == a)
        .toList();
    final totalMes = todasMes
        .where((r) =>
            r.statusReserva == 'realizada' || r.statusReserva == 'Realizada')
        .fold(0.0, (s, r) => s + r.valor);
    final canceladas = todasMes
        .where(
            (r) => r.statusReserva == 'cancelada' || r.statusReserva == 'Cancelada')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Reservas no Mês',
                  value: '${todasMes.length}',
                  icon: LucideIcons.calendarDays,
                  iconColor: AppColors.statusInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Receita Realizada',
                  value: fmt.format(totalMes),
                  icon: LucideIcons.dollarSign,
                  iconColor: AppColors.statusSuccess,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BookableAreaKpiCard(
                  label: 'Cancelamentos',
                  value: '$canceladas',
                  icon: LucideIcons.xCircle,
                  iconColor: AppColors.statusError,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              ...['todos', 'planejado', 'confirmada', 'realizada', 'cancelada'].map(
                (s) => BookableAreaFilterChip(
                  label: s[0].toUpperCase() + s.substring(1),
                  active: _statusFiltro == s,
                  isDark: isDark,
                  onTap: () => setState(() => _statusFiltro = s),
                ),
              ),
              const Spacer(),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: DropdownButton<String>(
                  value: _ordenacao,
                  underline: const SizedBox.shrink(),
                  dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimaryLight),
                  icon: Icon(
                    _ordemAscendente ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                    size: 12,
                    color: AppColors.atrOrange,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'data', child: Text('Data')),
                    DropdownMenuItem(value: 'nome', child: Text('Nome')),
                    DropdownMenuItem(value: 'valor', child: Text('Valor')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      if (_ordenacao == v) {
                        _ordemAscendente = !_ordemAscendente;
                      } else {
                        _ordenacao = v;
                        _ordemAscendente = true;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onExportCsv,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.download, size: 14, color: AppColors.textSecondaryLight),
                      SizedBox(width: 6),
                      Text('CSV',
                          style: TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onAddEvento,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.atrOrange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 14, color: AppColors.atrOrange),
                      SizedBox(width: 6),
                      Text('Novo Evento',
                          style: TextStyle(
                              color: AppColors.atrOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${evtMes.length} registro(s)',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (evtMes.isEmpty)
            BookableAreaEmptyState(
              message: 'Nenhuma reserva encontrada',
              icon: LucideIcons.calendarOff,
              isDark: isDark,
            )
          else
            _ReservasTable(
              eventos: evtMes,
              fmt: fmt,
              isDark: isDark,
              onEdit: widget.onEditEvento,
              onDelete: widget.onDeleteEvento,
            ),
        ],
      ),
    );
  }
}

class _ReservasTable extends StatelessWidget {
  final List<_EventoItem> eventos;
  final NumberFormat fmt;
  final bool isDark;
  final void Function(_EventoItem) onEdit;
  final void Function(_EventoItem) onDelete;
  const _ReservasTable({
    required this.eventos,
    required this.fmt,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final dateFmt = DateFormat('dd/MM (EEE)', 'pt_BR');

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                BookableAreaTableCol('Data', flex: 2),
                BookableAreaTableCol('Cliente', flex: 3),
                BookableAreaTableCol('Evento', flex: 3),
                BookableAreaTableCol('Valor', flex: 2),
                BookableAreaTableCol('Reserva', flex: 2),
                BookableAreaTableCol('Limpeza', flex: 2),
                BookableAreaTableCol('Ações', flex: 2),
              ],
            ),
          ),
          ...eventos.asMap().entries.map((e) {
            final r = e.value;
            final rowBg = e.key % 2 == 1
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02))
                : Colors.transparent;
            return Container(
              color: rowBg,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      dateFmt.format(r.data),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.cliente,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.tipoEvento,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmt.format(r.valor),
                      style: const TextStyle(
                        color: AppColors.statusSuccess,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: _statusReserva(r.statusReserva)),
                  Expanded(flex: 2, child: _statusLimpeza(r.statusLimpeza)),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => onEdit(r),
                          child: const Icon(
                            LucideIcons.pencil,
                            size: 14,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => onDelete(r),
                          child: const Icon(
                            LucideIcons.trash2,
                            size: 14,
                            color: AppColors.statusError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 3 — CONSOLIDADO ANUAL
// ═══════════════════════════════════════════════════════════════════════════
class _LazerConsolidado extends StatelessWidget {
  final List<_EventoItem> eventos;
  final List<_DespesaItem> despesas;
  final int ano;
  final bool isDark;
  const _LazerConsolidado({
    required this.eventos,
    required this.despesas,
    required this.ano,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final mesNomes = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    double receitaTotal = 0;
    double despesasTotal = 0;
    int reservasTotal = 0;

    final rows = List.generate(12, (i) {
      final m = i + 1;

      final evtMes = eventos
          .where((e) => e.data.month == m && e.data.year == ano)
          .toList();
      final rec = evtMes
          .where((e) =>
              e.statusReserva == 'realizada' || e.statusReserva == 'Realizada')
          .fold(0.0, (s, e) => s + e.receitaTotal);
      final desp = despesas
          .where((d) => d.data.month == m && d.data.year == ano)
          .fold(0.0, (s, d) => s + d.valor);
      final lucro = rec - desp;
      final reservas = evtMes
          .where((e) =>
              e.statusReserva != 'cancelada' &&
              e.statusReserva != 'Cancelada')
          .length;

      // Ocupação
      int totalFds = 0;
      int ocupados = 0;
      for (var d = DateTime(ano, m);
          d.month == m;
          d = d.add(const Duration(days: 1))) {
        if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
          totalFds++;
          final tem = eventos.any((e) =>
              e.data.year == d.year &&
              e.data.month == d.month &&
              e.data.day == d.day &&
              e.statusReserva != 'cancelada' &&
              e.statusReserva != 'Cancelada');
          if (tem) ocupados++;
        }
      }
      final ocup = totalFds == 0 ? 0.0 : (ocupados / totalFds) * 100;

      receitaTotal += rec;
      despesasTotal += desp;
      reservasTotal += reservas;

      return (
        mes: mesNomes[i],
        receita: rec,
        despesas: desp,
        lucro: lucro,
        reservas: reservas,
        ocupacao: ocup,
      );
    });

    final lucroTotal = receitaTotal - despesasTotal;

    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final headerBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final textPrimary =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSec =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consolidado $ano',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          // ── KPIs anuais ──
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 48) / 4;
              return Row(
                children: [
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Receita do Ano',
                      value: fmt.format(receitaTotal),
                      icon: LucideIcons.trendingUp,
                      iconColor: AppColors.statusSuccess,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Despesas do Ano',
                      value: fmt.format(despesasTotal),
                      icon: LucideIcons.trendingDown,
                      iconColor: AppColors.statusError,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Lucro Líquido',
                      value: fmt.format(lucroTotal),
                      icon: LucideIcons.dollarSign,
                      iconColor: lucroTotal >= 0
                          ? AppColors.statusSuccess
                          : AppColors.statusError,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: w,
                    child: BookableAreaKpiCard(
                      label: 'Reservas Realizadas',
                      value: '$reservasTotal',
                      icon: LucideIcons.calendarCheck,
                      iconColor: AppColors.atrOrange,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // ── Tabela por mês ──
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      BookableAreaTableCol('Mês', flex: 3),
                      BookableAreaTableCol('Receita', flex: 3),
                      BookableAreaTableCol('Despesas', flex: 3),
                      BookableAreaTableCol('Lucro', flex: 3),
                      BookableAreaTableCol('Reservas', flex: 2),
                      BookableAreaTableCol('Ocup.%', flex: 2),
                    ],
                  ),
                ),
                ...rows.asMap().entries.map((e) {
                  final r = e.value;
                  final rowBg = e.key % 2 == 1
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02))
                      : Colors.transparent;
                  final lucroColor = r.lucro >= 0
                      ? AppColors.statusSuccess
                      : AppColors.statusError;
                  return Container(
                    color: rowBg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            r.mes,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            fmt.format(r.receita),
                            style: const TextStyle(
                              color: AppColors.statusSuccess,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            fmt.format(r.despesas),
                            style: const TextStyle(
                              color: AppColors.statusError,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            fmt.format(r.lucro),
                            style: TextStyle(
                              color: lucroColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${r.reservas}',
                            style: TextStyle(color: textSec, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${r.ocupacao.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.atrOrange,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // ── Rodapé totais ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.atrOrange.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          fmt.format(receitaTotal),
                          style: const TextStyle(
                            color: AppColors.statusSuccess,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          fmt.format(despesasTotal),
                          style: const TextStyle(
                            color: AppColors.statusError,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          fmt.format(lucroTotal),
                          style: TextStyle(
                            color: lucroTotal >= 0
                                ? AppColors.statusSuccess
                                : AppColors.statusError,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$reservasTotal',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
