import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/ai_chat_provider.dart';
import '../../custos/custos_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/pending_action_card.dart';
import 'widgets/chat_input.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final List<ImageAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    context.read<AiChatProvider>().init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    final provider = context.read<AiChatProvider>();
    if (_attachments.isNotEmpty) {
      provider.sendImages(
        _attachments
            .map((a) => (mimeType: a.mimeType, base64: a.base64Data))
            .toList(),
        text.isEmpty ? null : text,
      );
      setState(() => _attachments.clear());
    } else {
      provider.sendText(text);
    }
    _controller.clear();
  }

  Future<void> _onPickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final newAttachments = <ImageAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      newAttachments.add(ImageAttachment(
        mimeType: _mimeFromExtension(file.extension ?? ''),
        base64Data: base64Encode(bytes),
        thumbnailBytes: Uint8List.fromList(bytes.take(65536).toList()),
      ));
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
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final sending = context.watch<AiChatProvider>().sending;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      color: AppColors.surfaceDark,
      child: Column(
        children: [
          const _ChatPanelHeader(),
          Expanded(child: _ChatBody()),
          _ChatInputArea(
            controller: _controller,
            sending: sending,
            onSend: _onSend,
            onImagePick: _onPickImage,
            attachments: _attachments,
            onRemoveAttachment: _onRemoveAttachment,
          ),
        ],
      ),
    );
  }
}

/// ── Header ───────────────────────────────────────────────────────────────
class _ChatPanelHeader extends StatefulWidget {
  const _ChatPanelHeader();

  @override
  State<_ChatPanelHeader> createState() => _ChatPanelHeaderState();
}

class _ChatPanelHeaderState extends State<_ChatPanelHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.8,
      upperBound: 1.2,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulse(bool sending) {
    if (sending && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
      return;
    }
    if (!sending && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatProvider>();
    final sending = provider.sending;
    final statusText = sending ? 'Digitando...' : 'Online';
    final statusColor = sending ? AppColors.statusWarning : AppColors.statusSuccess;
    _syncPulse(sending);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.warmGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(LucideIcons.bot, color: Colors.white, size: 20),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseController,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Nova conversa',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: provider.startNewConversation,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    LucideIcons.edit2,
                    color: AppColors.textSecondaryDark,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  LucideIcons.x,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Body ─────────────────────────────────────────────────────────────────
class _ChatBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatProvider>();

    if (!provider.initialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.atrOrange,
          strokeWidth: 2.5,
        ),
      );
    }

    if (provider.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.atrOrange.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  color: AppColors.atrOrange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pergunte algo sobre sua frota',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondaryDark,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consultas, registros e análises — tudo por aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final msg = provider.messages[index];
        return Column(
          children: [
            MessageBubble(message: msg),
            if (msg.pendingActions != null)
              ...msg.pendingActions!.map(
                (action) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PendingActionCard(
                    action: action,
                    onConfirm: () async {
                      await context.read<AiChatProvider>().confirmAction(action.actionId);
                      if (context.mounted) {
                        await context.read<CustosProvider>().refresh();
                      }
                    },
                    onCancel: () =>
                        context.read<AiChatProvider>().cancelAction(action.actionId),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ── Input Area ───────────────────────────────────────────────────────────
class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onImagePick;
  final List<ImageAttachment> attachments;
  final void Function(int index) onRemoveAttachment;

  const _ChatInputArea({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onImagePick,
    required this.attachments,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      child: ChatInput(
        controller: controller,
        sending: sending,
        onSend: onSend,
        onPickImage: onImagePick,
        attachments: attachments.isEmpty ? null : attachments,
        onRemoveAttachment: onRemoveAttachment,
      ),
    );
  }
}
