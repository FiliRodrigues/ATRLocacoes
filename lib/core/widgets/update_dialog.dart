import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131825),
      title: Row(
        children: [
          const Icon(LucideIcons.download, color: Color(0xFFFF8C42)),
          const SizedBox(width: 8),
          Text(
            'Nova versão v${widget.info.version} disponível',
            style: GoogleFonts.syne(
              color: const Color(0xFFF1F5F9),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.info.notes,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8B9CC0),
              fontSize: 16,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
          ],
        ],
      ),
      actions: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Depois', style: TextStyle(color: Color(0xFF8B9CC0))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C42),
              foregroundColor: const Color(0xFF1A2332),
            ),
            onPressed: _onUpdate,
            child: const Text('Atualizar agora'),
          ),
        ],
      ],
    );
  }

  Future<void> _onUpdate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await UpdateService.downloadAndInstall(widget.info.url);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      Future.delayed(const Duration(milliseconds: 300), () => exit(0));
    } else {
      setState(() {
        _loading = false;
        _error = 'Falha ao baixar ou instalar a atualização.';
      });
    }
  }
}
