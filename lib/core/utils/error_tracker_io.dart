import 'dart:io';
import 'package:flutter/foundation.dart';

Future<void> saveErrorLog(String message) async {
  try {
    final timestamp = DateTime.now().toIso8601String();
    final text =
        '[$timestamp]\n$message\n--------------------------------------------\n';
    final file = File('erros_encontrados.txt');
    await file.writeAsString(text, mode: FileMode.append);
  } catch (e) {
    debugPrint('Erro ao gravar log local: $e');
  }
}
