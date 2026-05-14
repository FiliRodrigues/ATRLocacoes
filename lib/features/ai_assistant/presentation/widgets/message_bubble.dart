import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/ai_content_block.dart';
import '../../data/models/ai_message.dart';

class MessageBubble extends StatelessWidget {
  final AiMessage message;

  const MessageBubble({super.key, required this.message});

  static const _toolLabels = {
    'list_vehicles': 'Buscando veículos',
    'get_vehicle_details': 'Carregando detalhes do veículo',
    'list_maintenances': 'Buscando manutenções',
    'list_contracts': 'Buscando contratos',
    'list_drivers': 'Buscando motoristas',
    'get_financing_status': 'Verificando financiamentos',
    'get_costs_summary': 'Calculando custos',
    'extract_invoice_data': 'Lendo nota fiscal',
    'list_expenses': 'Buscando despesas',
    'create_maintenance': 'Preparando registro de manutenção',
    'create_expense': 'Preparando registro de despesa',
    'create_maintenances_batch': 'Preparando múltiplos registros',
    'update_vehicle_mileage': 'Atualizando hodômetro',
    'create_vehicle': 'Cadastrando veículo',
    'update_vehicle': 'Atualizando veículo',
    'delete_vehicle': 'Excluindo veículo',
    'update_maintenance': 'Atualizando manutenção',
    'delete_maintenance': 'Excluindo manutenção',
    'update_expense': 'Atualizando despesa',
    'delete_expense': 'Excluindo despesa',
    'create_abastecimento': 'Registrando abastecimento',
    'update_abastecimento': 'Atualizando abastecimento',
    'delete_abastecimento': 'Excluindo abastecimento',
    'create_contract': 'Criando contrato',
    'update_contract': 'Atualizando contrato',
    'delete_contract': 'Excluindo contrato',
    'update_payment_status': 'Atualizando pagamento',
    'create_regra_manutencao': 'Criando regra',
    'update_regra_manutencao': 'Atualizando regra',
    'create_ocorrencia': 'Registrando ocorrência',
  };

  static const _toolIcons = {
    'list_vehicles': LucideIcons.truck,
    'get_vehicle_details': LucideIcons.info,
    'list_maintenances': LucideIcons.wrench,
    'list_contracts': LucideIcons.fileText,
    'list_drivers': LucideIcons.users,
    'get_financing_status': LucideIcons.creditCard,
    'get_costs_summary': LucideIcons.barChart2,
    'extract_invoice_data': LucideIcons.scan,
    'list_expenses': LucideIcons.receipt,
    'create_maintenance': LucideIcons.plusCircle,
    'create_expense': LucideIcons.receipt,
    'create_maintenances_batch': LucideIcons.layers,
    'update_vehicle_mileage': LucideIcons.gauge,
    'create_vehicle': LucideIcons.plusCircle,
    'update_vehicle': LucideIcons.pencil,
    'delete_vehicle': LucideIcons.trash2,
    'update_maintenance': LucideIcons.pencil,
    'delete_maintenance': LucideIcons.trash2,
    'update_expense': LucideIcons.pencil,
    'delete_expense': LucideIcons.trash2,
    'create_abastecimento': LucideIcons.fuel,
    'update_abastecimento': LucideIcons.pencil,
    'delete_abastecimento': LucideIcons.trash2,
    'create_contract': LucideIcons.clipboardList,
    'update_contract': LucideIcons.pencil,
    'delete_contract': LucideIcons.trash2,
    'update_payment_status': LucideIcons.creditCard,
    'create_regra_manutencao': LucideIcons.ruler,
    'update_regra_manutencao': LucideIcons.pencil,
    'create_ocorrencia': LucideIcons.alertTriangle,
  };

  bool get _isUser => message.role == AiMessageRole.user;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (content == null) return const SizedBox.shrink();

    final animated = content
        .animate()
        .fade(duration: 250.ms)
        .slide(
          begin: _isUser ? const Offset(0.1, 0) : const Offset(-0.1, 0),
          duration: 250.ms,
          curve: Curves.easeOut,
        );

    return _isUser
        ? Align(alignment: Alignment.centerRight, child: animated)
        : Align(alignment: Alignment.centerLeft, child: animated);
  }

  Widget? _buildContent(BuildContext context) {
    final blocks = message.content;
    if (blocks.isEmpty) return null;

    if (_isUser) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.warmGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: blocks.map((block) => _buildBlock(block)).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isPending)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(LucideIcons.clock, size: 12, color: AppColors.textMutedDark),
                  ),
                if (message.hasFailed)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(LucideIcons.alertCircle, size: 12, color: AppColors.statusError),
                  ),
                Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.warmGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(LucideIcons.bot, size: 16, color: Colors.white),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: blocks.map((block) => _buildBlock(block)).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(AiContentBlock block) {
    return switch (block) {
      AiTextBlock(:final text) => _buildTextBlock(text),
      AiImageBlock(:final data) => _buildImageBlock(data),
      AiToolUseBlock(:final name) => _buildToolUse(name),
      AiToolResultBlock(:final content, :final isError) => _buildToolResult(content, isError),
    };
  }

  Widget _buildTextBlock(String text) {
    if (_isUser) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
          height: 1.5,
          fontFamily: 'PlusJakartaSans',
        ),
      );
    }

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimaryDark,
          fontFamily: 'PlusJakartaSans',
          height: 1.5,
        ),
        h1: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
          fontFamily: 'PlusJakartaSans',
        ),
        h2: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
          fontFamily: 'PlusJakartaSans',
        ),
        h3: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
          fontFamily: 'PlusJakartaSans',
        ),
        strong: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
        ),
        em: const TextStyle(
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondaryDark,
        ),
        listBullet: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondaryDark,
          fontFamily: 'PlusJakartaSans',
        ),
        code: TextStyle(
          fontSize: 13,
          fontFamily: 'JetBrainsMono',
          color: AppColors.atrOrange,
          backgroundColor: AppColors.surfaceDarkAlt,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surfaceDarkAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDark),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        tableBorder: TableBorder.all(color: AppColors.borderDark, width: 1),
        tableHead: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
          fontFamily: 'PlusJakartaSans',
        ),
        tableBody: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontFamily: 'PlusJakartaSans',
        ),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        blockquoteDecoration: BoxDecoration(
          border: const Border(left: BorderSide(color: AppColors.atrOrange, width: 3)),
          color: AppColors.surfaceDarkAlt.withValues(alpha: 0.5),
        ),
        blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildImageBlock(String data) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(data);
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: bytes != null 
          ? Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackImage(),
            )
          : _buildFallbackImage(),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(LucideIcons.imageOff, size: 24, color: AppColors.textMutedDark),
      ),
    );
  }

  Widget _buildToolUse(String toolName) {
    final label = _toolLabels[toolName] ?? 'Processando';
    final icon = _toolIcons[toolName] ?? LucideIcons.wrench;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.atrOrange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.atrOrange.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.2,
                color: AppColors.atrOrange,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 12, color: AppColors.atrOrange),
            const SizedBox(width: 6),
            Text(
              '$label...',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryDark,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolResult(String content, bool isError) {
    final numberMatch = RegExp(r'\d+').firstMatch(content);
    final countText = numberMatch != null ? '${numberMatch.group(0)} itens' : 'concluído';
    final color = isError ? AppColors.statusError : AppColors.statusSuccess;
    final background = isError ? AppColors.glowError : AppColors.glowSuccess;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? LucideIcons.xCircle : LucideIcons.checkCircle2, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              isError ? 'Falha ao executar ação' : 'Ação finalizada: $countText',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
   }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (now.difference(local).inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
