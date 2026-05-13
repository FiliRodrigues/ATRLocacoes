import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import 'ai_chat_screen_spinner.dart';

class ImageAttachment {
  final String mimeType;
  final String base64Data;
  final Uint8List? thumbnailBytes;

  const ImageAttachment({
    required this.mimeType,
    required this.base64Data,
    this.thumbnailBytes,
  });
}

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final bool sending;
  final List<ImageAttachment>? attachments;
  final void Function(int index)? onRemoveAttachment;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.sending,
    this.attachments,
    this.onRemoveAttachment,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late final FocusNode _focusNode;
  bool _focused = false;

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  bool get _hasAttachment => widget.attachments != null && widget.attachments!.isNotEmpty;

  bool get _canSend {
    final hasText = widget.controller.text.trim().isNotEmpty;
    return (hasText || _hasAttachment) && !widget.sending;
  }

  String get _hintText {
    if (_hasAttachment) {
      return 'Adicione uma descricao (opcional)...';
    }
    return 'Pergunte sobre a frota...';
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused
        ? AppColors.atrOrange.withValues(alpha: 0.6)
        : AppColors.borderDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasAttachment) _buildAttachmentRow(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _focused ? AppColors.atrOrange.withValues(alpha: 0.4) : AppColors.borderDark.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: widget.sending ? null : widget.onPickImage,
                      icon: const Icon(LucideIcons.paperclip, size: 20),
                      color: AppColors.textMutedDark,
                      splashRadius: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            return KeyEventResult.ignored; // Permite a quebra de linha
                          } else {
                            if (_canSend) {
                              widget.onSend();
                            }
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimaryDark,
                          fontFamily: 'PlusJakartaSans',
                        ),
                        decoration: InputDecoration(
                          hintText: _hintText,
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textMutedDark,
                            fontFamily: 'PlusJakartaSans',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: _canSend ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _canSend ? AppColors.atrOrange : AppColors.surfaceDarkAlt,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: widget.sending
                          ? const Center(child: AiSpinner(size: 16))
                          : IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: _canSend ? widget.onSend : null,
                              icon: const Icon(LucideIcons.arrowUp, size: 18),
                              color: _canSend ? Colors.white : AppColors.textSecondaryDark,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.attachments!.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final attachment = widget.attachments![index];
            return _AttachmentThumbnail(
              attachment: attachment,
              onRemove: widget.onRemoveAttachment != null
                  ? () => widget.onRemoveAttachment!(index)
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _AttachmentThumbnail extends StatefulWidget {
  final ImageAttachment attachment;
  final VoidCallback? onRemove;

  const _AttachmentThumbnail({required this.attachment, this.onRemove});

  @override
  State<_AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<_AttachmentThumbnail> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.attachment.mimeType == 'application/pdf';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isPdf
                    ? AppColors.atrOrange.withValues(alpha: 0.15)
                    : AppColors.surfaceDarkAlt,
                border: Border.all(
                  color: _hovered ? AppColors.borderGlowDark : AppColors.borderDark,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isPdf ? _buildPdfPlaceholder() : _buildImage(),
            ),
          ),
          if (widget.onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.statusError,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (widget.attachment.thumbnailBytes == null) {
      return const Center(
        child: Icon(LucideIcons.image, size: 22, color: AppColors.textMutedDark),
      );
    }

    return Image.memory(
      widget.attachment.thumbnailBytes!,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(LucideIcons.imageOff, size: 22, color: AppColors.textMutedDark),
      ),
    );
  }

  Widget _buildPdfPlaceholder() {
    return const Center(
      child: Icon(LucideIcons.fileText, size: 24, color: AppColors.atrOrange),
    );
  }
}
