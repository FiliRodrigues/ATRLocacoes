import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atr_button.dart';
import '../../core/widgets/atr_page_background.dart';

import '../../core/utils/export_csv_stub.dart'
    if (dart.library.html) '../../core/utils/export_csv_html.dart'
    if (dart.library.io) '../../core/utils/export_csv_io.dart';

// ═══════════════════════════════════════════════════════════════════════
// OBRAS SCREEN -- Gestao de obras com persistencia via Supabase
// ═══════════════════════════════════════════════════════════════════════

class ObrasScreen extends StatefulWidget {
  const ObrasScreen({super.key});

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  // ── State ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _obras = [];
  bool _loading = true;
  String? _filtroCidade;
  String? _filtroStatus;
  String? _busca;
  String _ordenacao = 'data';
  bool _ordemAscendente = false;

  // ── Formatadores ───────────────────────────────────────────────────
  final _fmtMoney = NumberFormat.currency(
      locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
  final _fmtDate = DateFormat('dd/MM/yyyy');
  final _fmtDateIso = DateFormat('yyyy-MM-dd');
  final _buscaCtrl = TextEditingController();

  // ── Cores de status ────────────────────────────────────────────────
  static const _statusCores = {
    'Em andamento': AppColors.statusInfo,
    'Concluida': AppColors.statusSuccess,
    'Paralisada': AppColors.statusWarning,
    'Cancelada': AppColors.statusError,
  };

  static const _statusIcones = {
    'Em andamento': LucideIcons.construction,
    'Concluida': LucideIcons.checkCircle,
    'Paralisada': LucideIcons.pauseCircle,
    'Cancelada': LucideIcons.xCircle,
  };

  static const _coresCidade = {
    'Dourados': AppColors.statusSuccess,
    'Paulinia': AppColors.statusInfo,
    'Jarinu': Color(0xFFA78BFA),
    'Indaiatuba': Color(0xFFFB923C),
    'Salto': Color(0xFF2DD4BF),
  };

  // ── Tenant ─────────────────────────────────────────────────────────
  String? get _tenantId => Supabase
      .instance.client.auth.currentUser?.appMetadata['tenant_id'] as String?;

  // ── Filtros computados ─────────────────────────────────────────────
  List<String> get _cidades {
    final cidades =
        _obras.map((o) => (o['cidade'] as String?) ?? '').where((c) => c.isNotEmpty).toSet().toList();
    cidades.sort();
    return cidades;
  }

  List<Map<String, dynamic>> get _obrasFiltradas {
    var lista = _obras;
    if (_filtroCidade != null) {
      lista = lista.where((o) => o['cidade'] == _filtroCidade).toList();
    }
    if (_filtroStatus != null) {
      lista = lista.where((o) => o['status'] == _filtroStatus).toList();
    }
    if (_busca != null && _busca!.isNotEmpty) {
      final q = _busca!.toLowerCase();
      lista = lista.where((o) {
        final nome = (o['nome'] as String? ?? '').toLowerCase();
        final cidade = (o['cidade'] as String? ?? '').toLowerCase();
        final equipe = (o['equipe_responsavel'] as String? ?? '').toLowerCase();
        return nome.contains(q) || cidade.contains(q) || equipe.contains(q);
      }).toList();
    }
    // Ordenacao
    lista.sort((a, b) {
      int result;
      switch (_ordenacao) {
        case 'nome':
          final na = (a['nome'] as String? ?? '').toLowerCase();
          final nb = (b['nome'] as String? ?? '').toLowerCase();
          result = na.compareTo(nb);
          break;
        case 'valor':
          final va = (a['valor_total'] as num?)?.toDouble() ?? 0;
          final vb = (b['valor_total'] as num?)?.toDouble() ?? 0;
          result = va.compareTo(vb);
          break;
        default: // data
          final da = DateTime.tryParse((a['data_inicio'] ?? '').toString()) ?? DateTime(2000);
          final db = DateTime.tryParse((b['data_inicio'] ?? '').toString()) ?? DateTime(2000);
          result = da.compareTo(db);
      }
      return _ordemAscendente ? result : -result;
    });
    return lista;
  }

  // ── KPIs resumo ────────────────────────────────────────────────────
  double get _valorTotalObras {
    return _obrasFiltradas.fold(
        0, (s, o) => s + ((o['valor_total'] as num?)?.toDouble() ?? 0));
  }

  int get _qtdEmAndamento {
    return _obrasFiltradas
        .where((o) => o['status'] == 'Em andamento')
        .length;
  }

  double get _custoTotalObras {
    return _obrasFiltradas.fold(0, (s, o) {
      final mo = (o['custo_mao_obra'] as num?)?.toDouble() ?? 0;
      final mat = (o['custo_material'] as num?)?.toDouble() ?? 0;
      final eq = (o['custo_equipamento'] as num?)?.toDouble() ?? 0;
      return s + mo + mat + eq;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadObras();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadObras() async {
    setState(() => _loading = true);
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = await Supabase.instance.client
          .from('obras')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _obras = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar obras: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    }
  }

  Future<void> _salvarObra(Map<String, dynamic> data) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;

    final payload = Map<String, dynamic>.from(data);
    payload['tenant_id'] = tenantId;

    // Remove 'id' separadamente -- Supabase gera id via gen_random_uuid()
    final id = payload.remove('id') as String?;

    try {
      if (id != null && id.isNotEmpty) {
        await Supabase.instance.client
            .from('obras')
            .update(payload)
            .eq('id', id);
      } else {
        await Supabase.instance.client.from('obras').insert(payload);
      }
      await _loadObras();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar obra: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    }
  }

  Future<void> _excluirObra(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir obra?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('Esta acao nao pode ser desfeita.',
            style: TextStyle(color: AppColors.textSecondaryDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(
                    color: AppColors.statusError,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('obras')
            .delete()
            .eq('id', id);
        await _loadObras();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir obra: $e'),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIALOG DE CRIACAO / EDICAO
  // ═══════════════════════════════════════════════════════════════════

  void _showObraDialog({Map<String, dynamic>? obra}) {
    final nomeCtrl = TextEditingController(text: obra?['nome'] ?? '');
    final cidadeCtrl = TextEditingController(text: obra?['cidade'] ?? '');
    final equipeCtrl =
        TextEditingController(text: obra?['equipe_responsavel'] ?? '');
    final valorCtrl = TextEditingController(
        text: _numStr(obra?['valor_total']));
    final custoMOCtrl = TextEditingController(
        text: _numStr(obra?['custo_mao_obra']));
    final custoMatCtrl = TextEditingController(
        text: _numStr(obra?['custo_material']));
    final custoEquipCtrl = TextEditingController(
        text: _numStr(obra?['custo_equipamento']));
    final obsCtrl = TextEditingController(text: obra?['observacoes'] ?? '');
    final raioXCtrl =
        TextEditingController(text: obra?['raio_x_justificativa'] ?? '');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        String status = _normalizeStatus(obra?['status']);
        DateTime dataInicio = obra?['data_inicio'] != null
            ? DateTime.tryParse(obra!['data_inicio'].toString()) ??
                DateTime.now()
            : DateTime.now();
        DateTime? dataFim = obra?['data_fim'] != null
            ? DateTime.tryParse(obra!['data_fim'].toString())
            : null;
        bool raioXAprovado = obra?['raio_x_aprovado'] == true;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> pickDate(bool isInicio) async {
              final picked = await showDatePicker(
                context: dialogCtx,
                initialDate:
                    isInicio ? dataInicio : (dataFim ?? dataInicio),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.atrOrange,
                      surface: AppColors.surfaceDark,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setDialogState(() {
                  if (isInicio) {
                    dataInicio = picked;
                  } else {
                    dataFim = picked;
                  }
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    obra != null ? LucideIcons.edit : LucideIcons.plusCircle,
                    color: AppColors.atrOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      obra != null ? 'Editar Obra' : 'Nova Obra',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Dados basicos ──
                        _buildDialogSection('Dados Basicos'),
                        const SizedBox(height: 10),
                        _dialogField(
                            'Nome da Obra *', nomeCtrl, LucideIcons.hardHat),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _dialogField('Cidade *', cidadeCtrl,
                                    LucideIcons.mapPin)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _dialogField(
                                    'Equipe *',
                                    equipeCtrl,
                                    LucideIcons.users)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // ── Status e Datas ──
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Status',
                                      style: TextStyle(
                                          color: AppColors
                                              .textSecondaryDark,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: status,
                                    dropdownColor:
                                        AppColors.surfaceElevatedDark,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    decoration: _inputDecoration(),
                                    isExpanded: true,
                                    items: _statusCores.keys.map((s) {
                                      final cor = _statusCores[s] ??
                                          AppColors.textSecondaryDark;
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Row(
                                          children: [
                                            Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: cor)),
                                            const SizedBox(width: 8),
                                            Text(s),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setDialogState(() => status = v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dialogDateField(
                                'Data Inicio *',
                                dataInicio,
                                () => pickDate(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dialogDateField(
                                'Data Fim',
                                dataFim,
                                () => pickDate(false),
                                clearable: true,
                                onClear: () =>
                                    setDialogState(() => dataFim = null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // ── Valores ──
                        _buildDialogSection('Valores'),
                        const SizedBox(height: 10),
                        _dialogField('Valor Total (R\$) *', valorCtrl,
                            LucideIcons.dollarSign,
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _dialogField(
                                    'Mao de Obra (R\$)',
                                    custoMOCtrl,
                                    LucideIcons.user,
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _dialogField(
                                    'Material (R\$)',
                                    custoMatCtrl,
                                    LucideIcons.package,
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _dialogField(
                                    'Equipamento (R\$)',
                                    custoEquipCtrl,
                                    LucideIcons.truck,
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // ── Raio-X ──
                        _buildDialogSection('Raio-X de Producao'),
                        const SizedBox(height: 10),
                        _dialogField(
                            'Justificativa', raioXCtrl, LucideIcons.scanLine,
                            maxLines: 2),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: raioXAprovado,
                              activeColor: AppColors.atrOrange,
                              checkColor: Colors.white,
                              onChanged: (v) => setDialogState(
                                  () => raioXAprovado = v ?? false),
                            ),
                            GestureDetector(
                              onTap: () => setDialogState(() =>
                                  raioXAprovado = !raioXAprovado),
                              child: const Text('Raio-X Aprovado',
                                  style: TextStyle(
                                      color: AppColors.textSecondaryDark,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // ── Observacoes ──
                        _dialogField(
                            'Observacoes', obsCtrl, LucideIcons.fileText,
                            maxLines: 3),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.only(left: 24, right: 24, bottom: 16),
              actions: [
                if (obra != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _excluirObra(obra['id']);
                    },
                    child: const Text('Excluir',
                        style: TextStyle(
                            color: AppColors.statusError,
                            fontWeight: FontWeight.w700)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar',
                      style:
                          TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.atrOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    if (nomeCtrl.text.trim().isEmpty ||
                        cidadeCtrl.text.trim().isEmpty ||
                        equipeCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Preencha os campos obrigatorios: Nome, Cidade e Equipe'),
                          backgroundColor: AppColors.statusWarning,
                        ),
                      );
                      return;
                    }

                    final payload = <String, dynamic>{
                      if (obra?['id'] != null) 'id': obra!['id'],
                      'nome': nomeCtrl.text.trim(),
                      'cidade': cidadeCtrl.text.trim(),
                      'equipe_responsavel': equipeCtrl.text.trim(),
                      'status': status,
                      'data_inicio': _fmtDateIso.format(dataInicio),
                      'data_fim': dataFim != null
                          ? _fmtDateIso.format(dataFim!)
                          : null,
                      'valor_total': _parseMoney(valorCtrl.text),
                      'custo_mao_obra': _parseMoney(custoMOCtrl.text),
                      'custo_material': _parseMoney(custoMatCtrl.text),
                      'custo_equipamento':
                          _parseMoney(custoEquipCtrl.text),
                      'raio_x_justificativa': raioXCtrl.text.trim(),
                      'raio_x_aprovado': raioXAprovado,
                      'observacoes': obsCtrl.text.trim(),
                    };

                    Navigator.pop(dialogCtx);
                    _salvarObra(payload);
                  },
                  child: Text(obra != null ? 'Salvar' : 'Criar',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  String _normalizeStatus(dynamic status) {
    final s = status?.toString() ?? 'Em andamento';
    // Aceita tanto "Concluida" quanto "Concluída"
    if (s.contains('onclu')) return 'Concluida';
    if (s.contains('aralis')) return 'Paralisada';
    if (s.contains('ancel')) return 'Cancelada';
    if (s.contains('m andamento')) return 'Em andamento';
    for (final key in _statusCores.keys) {
      if (s == key) return key;
    }
    return 'Em andamento';
  }

  String _numStr(dynamic val) {
    if (val == null || val == 0) return '';
    final n = (val is num) ? val.toDouble() : double.tryParse(val.toString());
    if (n == null || n == 0) return '';
    return n.toStringAsFixed(2).replaceAll('.', ',');
  }

  double _parseMoney(String text) {
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }

  Color _statusCor(dynamic status) {
    return _statusCores[_normalizeStatus(status)] ??
        AppColors.textSecondaryDark;
  }

  IconData _statusIcone(dynamic status) {
    return _statusIcones[_normalizeStatus(status)] ?? LucideIcons.helpCircle;
  }

  Color _cidadeCor(String? cidade) {
    if (cidade == null) return AppColors.textSecondaryDark;
    return _coresCidade[cidade] ?? AppColors.textTertiaryDark;
  }

  Widget _buildDialogSection(String title) {
    return Row(
      children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
                color: AppColors.atrOrange,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppColors.atrOrange,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _dialogField(
      String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDecoration().copyWith(
            prefixIcon: Icon(icon, size: 15, color: AppColors.textMutedDark),
          ),
        ),
      ],
    );
  }

  Widget _dialogDateField(String label, DateTime? date, VoidCallback onTap,
      {bool clearable = false, VoidCallback? onClear}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendarDays,
                    size: 15, color: AppColors.textMutedDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null ? _fmtDate.format(date) : '---',
                    style: TextStyle(
                        color: date != null
                            ? Colors.white
                            : AppColors.textMutedDark,
                        fontSize: 13),
                  ),
                ),
                if (clearable && date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(LucideIcons.x,
                        size: 14, color: AppColors.textMutedDark),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: AppColors.surfaceElevatedDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.atrOrange, width: 1.5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showObraDialog(),
        backgroundColor: AppColors.atrOrange,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Nova Obra',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      body: AtrPageBackground(
        grid: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.backgroundDark,
                      AppColors.atrNavyDarker,
                      AppColors.backgroundDark,
                    ],
                    stops: [0, 0.5, 1],
                  )
                : null,
            color: isDark ? null : AppColors.backgroundLight,
          ),
          child: SafeArea(
            child: _loading ? _buildLoadingState() : _buildContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.atrOrange),
    );
  }

  Widget _buildContent(bool isDark) {
    final obras = _obrasFiltradas;

    return Column(
      children: [
        // ── Header ──
        _buildHeader(isDark),
        // ── KPI summary bar ──
        _buildKpiBar(isDark),
        // ── Filtros ──
        _buildFiltros(isDark),
        // ── Lista ──
        Expanded(
          child: obras.isEmpty
              ? _buildEmptyState(isDark)
              : _buildObrasGrid(obras, isDark),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : Colors.black54),
            onPressed: () => context.go('/selector'),
            tooltip: 'Voltar',
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.hardHat,
              color: AppColors.atrOrange, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestao de Obras',
                  style: TextStyle(
                    color:
                        isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_obras.length} obra${_obras.length == 1 ? '' : 's'} cadastrada${_obras.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x12FFFFFF)),
            ),
            child: DropdownButton<String>(
              value: _ordenacao,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.surfaceElevatedDark,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
              icon: Icon(
                _ordemAscendente ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                size: 12,
                color: AppColors.atrOrange,
              ),
              items: const [
                DropdownMenuItem(value: 'data', child: Text('Data')),
                DropdownMenuItem(value: 'valor', child: Text('Valor')),
                DropdownMenuItem(value: 'nome', child: Text('Nome')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (_ordenacao == v) {
                    _ordemAscendente = !_ordemAscendente;
                  } else {
                    _ordenacao = v;
                    _ordemAscendente = false;
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'csv') _exportCsv();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(LucideIcons.fileSpreadsheet, size: 16),
                    SizedBox(width: 8),
                    Text('Exportar CSV'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surfaceDark,
              ),
              child: const Icon(LucideIcons.download, size: 16, color: AppColors.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // KPI BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildKpiBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final cols = w > 900 ? 4 : (w > 600 ? 2 : 1);
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiCard('Total Obras', '${_obrasFiltradas.length}',
                  LucideIcons.building, AppColors.atrOrange, isDark,
                  width: (w - 12 * (cols - 1)) / cols),
              _kpiCard('Valor Total', _fmtMoney.format(_valorTotalObras),
                  LucideIcons.dollarSign, AppColors.statusSuccess, isDark,
                  width: (w - 12 * (cols - 1)) / cols),
              _kpiCard('Em Andamento', '$_qtdEmAndamento',
                  LucideIcons.construction, AppColors.statusInfo, isDark,
                  width: (w - 12 * (cols - 1)) / cols),
              _kpiCard('Custo Total', _fmtMoney.format(_custoTotalObras),
                  LucideIcons.wallet, AppColors.statusWarning, isDark,
                  width: (w - 12 * (cols - 1)) / cols),
            ],
          ).animate().fadeIn(duration: 300.ms).moveY(
              begin: 10, end: 0, duration: 300.ms, curve: Curves.easeOut);
        },
      ),
    );
  }

  Widget _kpiCard(String label, String valor, IconData icon, Color cor,
      bool isDark,
      {required double width}) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: cor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(valor,
                      style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTROS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFiltros(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Busca
          SizedBox(
            height: 40,
            child: TextField(
              controller: _buscaCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) => setState(() => _busca = v.isEmpty ? null : v),
              decoration: InputDecoration(
                hintText: 'Buscar por nome, cidade ou equipe...',
                hintStyle: const TextStyle(
                    color: AppColors.textMutedDark, fontSize: 13),
                prefixIcon: const Icon(LucideIcons.search,
                    size: 16, color: AppColors.textMutedDark),
                suffixIcon: _busca != null && _busca!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x,
                            size: 14, color: AppColors.textMutedDark),
                        onPressed: () {
                          _buscaCtrl.clear();
                          setState(() => _busca = null);
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.atrOrange, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Chips de filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status chips
                const Text('Status:',
                    style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ..._statusCores.keys.map((s) {
                  final ativo = _filtroStatus == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _filterChip(
                      s, ativo,
                      color: _statusCores[s]!,
                      onTap: () => setState(
                          () => _filtroStatus = ativo ? null : s),
                    ),
                  );
                }),
                const SizedBox(width: 16),
                // Cidade chips
                if (_cidades.isNotEmpty) ...[
                  const Text('Cidade:',
                      style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  ..._cidades.map((c) {
                    final ativo = _filtroCidade == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _filterChip(
                        c, ativo,
                        color: _cidadeCor(c),
                        onTap: () => setState(
                            () => _filtroCidade = ativo ? null : c),
                      ),
                    );
                  }),
                ],
                if (_filtroCidade != null || _filtroStatus != null) ...[
                  const SizedBox(width: 8),
                  AtrGhostButton(
                    label: 'Limpar',
                    icon: LucideIcons.x,
                    onPressed: () => setState(() {
                      _filtroCidade = null;
                      _filtroStatus = null;
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool ativo,
      {required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? color.withValues(alpha: 0.15) : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: ativo ? color : AppColors.borderDark,
              width: ativo ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: ativo ? color : AppColors.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: ativo ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // GRID DE OBRAS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildObrasGrid(List<Map<String, dynamic>> obras, bool isDark) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final cols = w > 1200 ? 3 : (w > 750 ? 2 : 1);
        final spacing = 16.0;
        final cardW = (w - spacing * (cols - 1)) / cols;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: obras.asMap().entries.map((entry) {
              final i = entry.key;
              final obra = entry.value;
              return SizedBox(
                width: cardW,
                child: _buildObraCard(obra, i, isDark)
                    .animate()
                    .fadeIn(
                        delay: (i * 50).ms, duration: 350.ms)
                    .moveY(
                        begin: 12,
                        end: 0,
                        delay: (i * 50).ms,
                        duration: 300.ms,
                        curve: Curves.easeOut),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildObraCard(Map<String, dynamic> obra, int index, bool isDark) {
    final nome = obra['nome'] as String? ?? 'Sem nome';
    final cidade = obra['cidade'] as String? ?? '';
    final equipe = obra['equipe_responsavel'] as String? ?? '';
    final status = _normalizeStatus(obra['status']);
    final valorTotal =
        (obra['valor_total'] as num?)?.toDouble() ?? 0;
    final dataInicioRaw = obra['data_inicio'];
    final dataFimRaw = obra['data_fim'];
    final observacoes = obra['observacoes'] as String? ?? '';

    final hoje = DateTime.now();
    final dataInicio = dataInicioRaw != null
        ? DateTime.tryParse(dataInicioRaw.toString())
        : null;
    final dataFim = dataFimRaw != null
        ? DateTime.tryParse(dataFimRaw.toString())
        : null;

    final statusCor = _statusCor(status);
    final statusIco = _statusIcone(status);
    final cidadeCor = _cidadeCor(cidade);

    // Calcular custo total
    final custoTotal =
        ((obra['custo_mao_obra'] as num?)?.toDouble() ?? 0) +
            ((obra['custo_material'] as num?)?.toDouble() ?? 0) +
            ((obra['custo_equipamento'] as num?)?.toDouble() ?? 0);

    // Calcular dias em andamento / duracao
    String periodoTexto = '';
    if (dataInicio != null) {
      final ref = dataFim ?? hoje;
      final dias = ref.difference(dataInicio).inDays;
      if (dataFim != null) {
        periodoTexto = '${dias} dias · ${_fmtDate.format(dataInicio)} — ${_fmtDate.format(dataFim)}';
      } else {
        periodoTexto =
            '${dias} dias em andamento · desde ${_fmtDate.format(dataInicio)}';
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showObraDialog(obra: obra),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status bar + acoes ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: statusCor.withValues(alpha: 0.08),
                  border: Border(
                      bottom: BorderSide(
                          color:
                              statusCor.withValues(alpha: 0.15))),
                ),
                child: Row(
                  children: [
                    Icon(statusIco, size: 14, color: statusCor),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusCor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              color: statusCor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _excluirObra(obra['id']),
                      child: const Icon(LucideIcons.trash2,
                          size: 15, color: AppColors.textMutedDark),
                    ),
                  ],
                ),
              ),
              // ── Conteudo ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    Text(nome,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    // Cidade + Equipe
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin,
                            size: 13, color: cidadeCor),
                        const SizedBox(width: 5),
                        Text(cidade,
                            style: TextStyle(
                                color: cidadeCor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 14),
                        const Icon(LucideIcons.users,
                            size: 13,
                            color: AppColors.textSecondaryDark),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(equipe,
                              style: const TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Periodo
                    if (periodoTexto.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendarDays,
                                size: 12,
                                color: AppColors.textMutedDark),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(periodoTexto,
                                  style: const TextStyle(
                                      color: AppColors.textMutedDark,
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    // Observacoes (if any)
                    if (observacoes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(observacoes,
                            style: const TextStyle(
                                color: AppColors.textMutedDark,
                                fontSize: 11,
                                fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    const SizedBox(height: 4),
                    // Valores
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Valor Total',
                                  style: TextStyle(
                                      color: AppColors.textMutedDark,
                                      fontSize: 9)),
                              const SizedBox(height: 2),
                              Text(_fmtMoney.format(valorTotal),
                                  style: const TextStyle(
                                      color: AppColors.atrOrange,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (custoTotal > 0)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Custo Total',
                                    style: TextStyle(
                                        color: AppColors.textMutedDark,
                                        fontSize: 9)),
                                const SizedBox(height: 2),
                                Text(_fmtMoney.format(custoTotal),
                                    style: const TextStyle(
                                        color: AppColors.statusWarning,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Edit button
                    Align(
                      alignment: Alignment.centerRight,
                      child: AtrGhostButton(
                        label: 'Editar',
                        icon: LucideIcons.edit,
                        onPressed: () => _showObraDialog(obra: obra),
                      ),
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

  // ═══════════════════════════════════════════════════════════════════
  // EXPORT CSV
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportCsv() async {
    final obras = _obrasFiltradas;
    final buffer = StringBuffer();
    buffer.writeln(
      '"NOME";"CIDADE";"EQUIPE";"STATUS";"DATA INICIO";"DATA FIM";"VALOR TOTAL";"CUSTO TOTAL"',
    );

    for (final o in obras) {
      final nome = o['nome'] as String? ?? '';
      final cidade = o['cidade'] as String? ?? '';
      final equipe = o['equipe_responsavel'] as String? ?? '';
      final status = _normalizeStatus(o['status']);
      final dataInicio = o['data_inicio'] != null
          ? _fmtDate.format(DateTime.tryParse(o['data_inicio'].toString()) ?? DateTime.now())
          : '';
      final dataFim = o['data_fim'] != null
          ? _fmtDate.format(DateTime.tryParse(o['data_fim'].toString()) ?? DateTime.now())
          : '';
      final valorTotal =
          ((o['valor_total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2).replaceAll('.', ',');
      final custoTotal = (((o['custo_mao_obra'] as num?)?.toDouble() ?? 0) +
              ((o['custo_material'] as num?)?.toDouble() ?? 0) +
              ((o['custo_equipamento'] as num?)?.toDouble() ?? 0))
          .toStringAsFixed(2).replaceAll('.', ',');

      buffer.writeln(
        '${_csvField(nome)};${_csvField(cidade)};${_csvField(equipe)};${_csvField(status)};${_csvField(dataInicio)};${_csvField(dataFim)};${_csvField(valorTotal)};${_csvField(custoTotal)}',
      );
    }

    try {
      final fileName = 'obras_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.hardHat,
              size: 64, color: AppColors.atrOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _obras.isEmpty
                ? 'Nenhuma obra cadastrada'
                : 'Nenhuma obra encontrada com os filtros atuais',
            style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _obras.isEmpty
                ? 'Clique em "Nova Obra" para comecar'
                : 'Tente limpar os filtros',
            style: TextStyle(
                color: isDark ? AppColors.textMutedDark : AppColors.textTertiaryDark,
                fontSize: 12),
          ),
          if (_obras.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showObraDialog(),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Nova Obra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.atrOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
