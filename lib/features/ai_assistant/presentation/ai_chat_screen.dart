import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;
import 'dart:ui' show ImageFilter;

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/app_logger.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atr_page_background.dart';
import '../../custos/custos_provider.dart';
import '../data/models/ai_conversation.dart';
import '../data/models/ai_message.dart';
import '../domain/ai_chat_provider.dart';
import 'widgets/ai_chat_screen_spinner.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';
import 'widgets/pending_action_card.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialQuery;

  const AiChatScreen({super.key, this.initialQuery});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ImageAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<AiChatProvider>();
    provider.prepareNewScreenState();
    provider.init().then((_) {
      if (!mounted) return;
      if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
        provider.sendText(widget.initialQuery!.trim());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    final provider = context.read<AiChatProvider>();
    final pdfs = _attachments.where((a) => a.mimeType == 'application/pdf').toList();
    final images = _attachments.where((a) => a.mimeType != 'application/pdf').toList();

    // Calcula SHA-256 dos PDFs brutos para deteccao de reenvio
    final pdfHashes = <String>[];
    for (final pdf in pdfs) {
      try {
        final rawBytes = base64Decode(pdf.base64Data);
        pdfHashes.add(sha256.convert(rawBytes).toString());
      } catch (e) { AppLogger.warning('AiChatScreen PDF hash: $e'); }
    }

    // Renderiza páginas dos PDFs como PNG para enviar ao modelo
    const maxPdfPages = 3;
    final pdfPageImages = <ImageAttachment>[];
    int pdfRenderErrors = 0;
    if (pdfs.isNotEmpty) {
      await pdfrxFlutterInitialize();
    }
    for (final pdf in pdfs) {
      try {
        final bytes = base64Decode(pdf.base64Data);
        final document = await PdfDocument.openData(bytes);
        final pageCount = document.pages.length.clamp(0, maxPdfPages);
        for (int i = 0; i < pageCount; i++) {
          final page = document.pages[i];
          final pdfImage = await page.render(
            fullWidth: page.width,
            fullHeight: page.height,
          );
          if (pdfImage == null) continue;
          final uiImage = await pdfImage.createImage();
          final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
          uiImage.dispose();
          pdfImage.dispose();
          if (byteData == null) continue;
          final pngBytes = byteData.buffer.asUint8List();
          pdfPageImages.add(ImageAttachment(
            mimeType: 'image/png',
            base64Data: base64Encode(pngBytes),
            thumbnailBytes: Uint8List.fromList(pngBytes.take(65536).toList()),
          ));
        }
        await document.dispose();
      } catch (e) {
        pdfRenderErrors++;
        debugPrint('[PDF render] erro: $e');
      }
    }

    // Monta texto da mensagem com hashes para anti-reenvio
    String? messageText = text.trim().isEmpty ? null : text.trim();
    if (pdfHashes.isNotEmpty) {
      final hashTag = '[content_hashes:${pdfHashes.join(",")}]';
      messageText = messageText != null ? '$messageText $hashTag' : hashTag;
    }

    bool sent = false;
    if (pdfPageImages.isNotEmpty) {
      final pdfLabel =
          '📄 ${pdfs.length} PDF${pdfs.length > 1 ? 's' : ''} (${pdfPageImages.length} página${pdfPageImages.length > 1 ? 's' : ''})';
      final backendImages = [
        ...pdfPageImages,
        ...images,
      ].map((a) => (mimeType: a.mimeType, base64: a.base64Data)).toList();
      provider.sendPdf(backendImages, pdfLabel, messageText,
          contentHashes: pdfHashes.isNotEmpty ? pdfHashes : null);
      sent = true;
      if (pdfRenderErrors > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pdfRenderErrors == pdfs.length
                  ? 'Não foi possível processar ${pdfs.length} PDF(s). Tente novamente.'
                  : '$pdfRenderErrors de ${pdfs.length} PDF(s) não puderam ser processados (página corrompida?). Os demais foram enviados.',
            ),
            backgroundColor: pdfRenderErrors == pdfs.length ? Colors.red : Colors.orange,
          ),
        );
      }
    } else if (images.isNotEmpty) {
      provider.sendImages(
        images.map((a) => (mimeType: a.mimeType, base64: a.base64Data)).toList(),
        messageText,
      );
      sent = true;
    } else if (messageText != null && pdfs.isEmpty) {
      provider.sendText(messageText);
      sent = true;
    } else if (pdfs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível processar o PDF. Tente novamente ou use uma imagem.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (sent) {
      setState(_attachments.clear);
      _controller.clear();
      _scrollToBottom();
    }
  }

  Future<void> _onPickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'pdf'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final newAttachments = <ImageAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      newAttachments.add(
        ImageAttachment(
          mimeType: _mimeFromExtension(file.extension ?? ''),
          base64Data: base64Encode(bytes),
          thumbnailBytes: Uint8List.fromList(bytes.take(65536).toList()),
        ),
      );
    }

    if (newAttachments.isNotEmpty) {
      setState(() => _attachments.addAll(newAttachments));
    }
  }

  void _onRemoveAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AtrPageBackground(
        grid: true,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _AiChatHeader(
                    onBack: () => context.pop(),
                    onToggleSidebar: provider.toggleSidebar,
                    onNewChat: provider.startNewConversation,
                    sidebarOpen: provider.sidebarOpen,
                    sending: provider.sending,
                  ),
                  if (provider.error != null)
                    _ErrorBanner(
                      message: provider.error!,
                      onDismiss: provider.clearError,
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: _buildMessageList(provider),
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: _buildInputArea(provider),
                    ),
                  ),
                ],
              ),
              if (provider.sidebarOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: provider.closeSidebar,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(color: Colors.black.withValues(alpha: 0.18)),
                    ),
                  ),
                ),
              _ConversationSidebar(
                open: provider.sidebarOpen,
                conversations: provider.conversations,
                activeConversationId: provider.activeConversationId,
                messageCountForConversation: provider.messageCountForConversation,
                onClose: provider.closeSidebar,
                onNewChat: provider.startNewConversation,
                onOpenConversation: provider.loadConversation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(AiChatProvider provider) {
    if (!provider.initialized) {
      return const Center(child: AiSpinner(size: 24));
    }

    if (provider.messages.isEmpty && !provider.sending) {
      return _EmptyStateSuggestions(
        onTapSuggestion: (query) => context.read<AiChatProvider>().sendText(query),
      );
    }

    final children = <Widget>[];
    for (int index = 0; index < provider.messages.length; index++) {
      final message = provider.messages[index];
      if (_showDateSeparator(provider.messages, index)) {
        children.add(_DateSeparator(date: message.createdAt));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: MessageBubble(message: message),
        ),
      );
      if (message.pendingActions != null) {
        children.addAll(
          message.pendingActions!.map(
            (action) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PendingActionCard(
                action: action,
                onConfirm: () async {
                  await context.read<AiChatProvider>().confirmAction(action.actionId);
                  if (context.mounted) {
                    await context.read<CustosProvider>().refresh();
                  }
                },
                onCancel: () => context.read<AiChatProvider>().cancelAction(action.actionId),
              ),
            ),
          ),
        );
      }
      children.add(const SizedBox(height: 12));
    }

    if (provider.sending) {
      children.add(const _TypingIndicator());
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: children,
    );
  }

  bool _showDateSeparator(List<AiMessage> messages, int index) {
    if (index == 0) return true;
    final prev = messages[index - 1].createdAt.toLocal();
    final curr = messages[index].createdAt.toLocal();
    return prev.day != curr.day || prev.month != curr.month || prev.year != curr.year;
  }

  Widget _buildInputArea(AiChatProvider provider) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      color: Colors.transparent,
      child: ChatInput(
        controller: _controller,
        sending: provider.sending,
        onSend: _onSend,
        onPickImage: _onPickFile,
        attachments: _attachments.isEmpty ? null : _attachments,
        onRemoveAttachment: _onRemoveAttachment,
      ),
    );
  }
}

class _ConversationSidebar extends StatelessWidget {
  final bool open;
  final List<AiConversation> conversations;
  final String? activeConversationId;
  final int Function(String conversationId) messageCountForConversation;
  final VoidCallback onClose;
  final VoidCallback onNewChat;
  final Future<void> Function(String id) onOpenConversation;

  const _ConversationSidebar({
    required this.open,
    required this.conversations,
    required this.activeConversationId,
    required this.messageCountForConversation,
    required this.onClose,
    required this.onNewChat,
    required this.onOpenConversation,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final sidebarWidth = width < 900 ? width * 0.85 : 280.0;
    final grouped = _groupConversations(conversations);

    return Align(
      alignment: Alignment.centerLeft,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedSlide(
          offset: open ? Offset.zero : const Offset(-1, 0),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: Container(
            width: sidebarWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.96),
              border: const Border(
                right: BorderSide(color: AppColors.borderDark, width: 1),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderDark, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onClose,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              LucideIcons.arrowLeft,
                              size: 18,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Histórico',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onNewChat,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.atrOrange,
                        side: const BorderSide(color: AppColors.atrOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text(
                        'Novo Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    children: grouped
                        .map(
                          (group) => _ConversationGroupSection(
                            label: group.label,
                            conversations: group.conversations,
                            activeConversationId: activeConversationId,
                            messageCountForConversation: messageCountForConversation,
                            onTapConversation: (id) async {
                              await onOpenConversation(id);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_ConversationGroup> _groupConversations(List<AiConversation> source) {
    final now = DateTime.now();
    final map = <String, List<AiConversation>>{};
    for (final conversation in source) {
      final label = _groupLabelForDate(conversation.updatedAt.toLocal(), now);
      map.putIfAbsent(label, () => []).add(conversation);
    }
    return map.entries
        .map((entry) => _ConversationGroup(label: entry.key, conversations: entry.value))
        .toList();
  }

  String _groupLabelForDate(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    if (!target.isBefore(startOfWeek)) return 'Esta semana';

    final monthDiff = (today.year - target.year) * 12 + (today.month - target.month);
    if (monthDiff == 1) return 'Mês passado';

    return '${_monthShort(target.month)} ${target.year}';
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return months[month - 1];
  }
}

class _ConversationGroup {
  final String label;
  final List<AiConversation> conversations;

  const _ConversationGroup({required this.label, required this.conversations});
}

class _ConversationGroupSection extends StatelessWidget {
  final String label;
  final List<AiConversation> conversations;
  final String? activeConversationId;
  final int Function(String conversationId) messageCountForConversation;
  final Future<void> Function(String id) onTapConversation;

  const _ConversationGroupSection({
    required this.label,
    required this.conversations,
    required this.activeConversationId,
    required this.messageCountForConversation,
    required this.onTapConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ...conversations.map(
            (conversation) {
              final active = conversation.id == activeConversationId;
              final count = messageCountForConversation(conversation.id);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTapConversation(conversation.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? AppColors.surfaceHoverDark : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: active ? AppColors.atrOrange : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              LucideIcons.messageSquare,
                              size: 15,
                              color: AppColors.textMutedDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimaryDark,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_formatRelative(conversation.updatedAt.toLocal())} · ${_messageCountLabel(count)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMutedDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'ha ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'ha ${diff.inHours}h';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _messageCountLabel(int count) {
    return count == 1 ? '1 mensagem' : '$count mensagens';
  }
}

class _AiChatHeader extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onToggleSidebar;
  final VoidCallback onNewChat;
  final bool sidebarOpen;
  final bool sending;

  const _AiChatHeader({
    required this.onBack,
    required this.onToggleSidebar,
    required this.onNewChat,
    required this.sidebarOpen,
    required this.sending,
  });

  @override
  State<_AiChatHeader> createState() => _AiChatHeaderState();
}

class _AiChatHeaderState extends State<_AiChatHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.8,
      upperBound: 1.2,
    );
  }

  @override
  void didUpdateWidget(covariant _AiChatHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sending && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
    if (!widget.sending && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.sending ? 'Digitando...' : 'Online';
    final statusColor = widget.sending ? AppColors.statusWarning : AppColors.statusSuccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 1)),
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: widget.sidebarOpen ? LucideIcons.panelLeftClose : LucideIcons.panelLeft,
            onTap: widget.onToggleSidebar,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(icon: LucideIcons.arrowLeft, onTap: widget.onBack),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.warmGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(LucideIcons.bot, color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assistente ATR',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseController,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Nova conversa',
            child: _HeaderIconButton(icon: LucideIcons.edit2, onTap: widget.onNewChat),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.textSecondaryDark, size: 19),
        ),
      ),
    );
  }
}

class _EmptyStateSuggestions extends StatelessWidget {
  final void Function(String query) onTapSuggestion;

  const _EmptyStateSuggestions({required this.onTapSuggestion});

  static const _suggestions = [
    (
      icon: LucideIcons.wrench,
      label: 'Manutenções\nvencidas hoje',
      query: 'Quais manutenções estão vencidas ou vencem hoje?',
    ),
    (
      icon: LucideIcons.dollarSign,
      label: 'Custos\ndo mês atual',
      query: 'Qual é o resumo de custos do mês atual por categoria?',
    ),
    (
      icon: LucideIcons.plusCircle,
      label: 'Criar\nveículo novo',
      query: 'Criar um veículo novo na frota',
    ),
    (
      icon: LucideIcons.receipt,
      label: 'Despesas\nnão pagas',
      query: 'Listar todas as despesas não pagas',
    ),
    (
      icon: LucideIcons.camera,
      label: 'Registrar NF\npor foto',
      query: 'Quero registrar uma nota fiscal. Pode me ajudar?',
    ),
    (
      icon: LucideIcons.creditCard,
      label: 'Marcar IPVA\ncomo pago',
      query: 'Marcar IPVA como pago',
    ),
    (
      icon: LucideIcons.truck,
      label: 'Status da\nfrota agora',
      query: 'Qual é a situação atual da frota? Quais veículos estão disponíveis?',
    ),
    (
      icon: LucideIcons.fileText,
      label: 'Encerrar\ncontrato',
      query: 'Encerrar contrato CTR-2024-001',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.warmGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.glowOrange,
                      blurRadius: 18,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.bot, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 14),
              const Text(
                'Assistente ATR',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pergunte, registre, analise',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _SuggestionChip(
                    icon: item.icon,
                    label: item.label,
                    onTap: () => onTapSuggestion(item.query),
                  )
                      .animate(delay: Duration(milliseconds: 80 * index))
                      .fade(duration: 260.ms)
                      .slide(begin: const Offset(0, 0.3), duration: 260.ms, curve: Curves.easeOut);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = (width - 70) / 2;
    final chipWidth = maxWidth < 160 ? maxWidth : 180.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          child: Ink(
            width: chipWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surfaceHoverDark : AppColors.surfaceElevatedDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hovered ? AppColors.borderGlowDark : AppColors.borderDark,
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 15, color: AppColors.atrOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.warmGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(LucideIcons.bot, color: Colors.white, size: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final progress = ((_controller.value - (index * (150 / 900))) % 1.0 + 1.0) % 1.0;
            final phase = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
            final wave = Curves.easeInOut.transform(phase.clamp(0.0, 1.0));
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
              child: Transform.translate(
                offset: Offset(0, -6 * wave),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.textMutedDark,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.borderDark, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(date.toLocal()),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMutedDark,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.borderDark, thickness: 1),
          ),
        ],
      ),
    );
  }

  String _label(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    if (!date.isBefore(startOfWeek)) {
      const weekdays = [
        'Segunda-feira',
        'Terça-feira',
        'Quarta-feira',
        'Quinta-feira',
        'Sexta-feira',
        'Sábado',
        'Domingo',
      ];
      return weekdays[value.weekday - 1];
    }

    final day = value.day.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return '$day ${months[value.month - 1]}';
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.statusError.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: AppColors.statusError, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.statusError,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(LucideIcons.x, color: AppColors.statusError, size: 14),
          ),
        ],
      ),
    );
  }
}