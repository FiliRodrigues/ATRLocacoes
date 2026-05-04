// Implementação web usando dart:html — só compilado quando dart.library.html disponível.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

Future<String?> pickPdfFileName() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,application/pdf'
    ..style.display = 'none';

  html.document.body!.append(input);

  // Completa quando o usuário seleciona um arquivo.
  input.onChange.listen((_) {
    input.remove();
    if (!completer.isCompleted) {
      completer.complete(
        (input.files?.isNotEmpty ?? false) ? input.files!.first.name : null,
      );
    }
  });

  // Detecta cancelamento: quando a janela volta ao foco sem onChange ter disparado.
  StreamSubscription<html.Event>? focusSub;
  focusSub = html.window.onFocus.listen((_) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        input.remove();
      }
      focusSub?.cancel();
    });
  });

  input.click();
  return completer.future;
}
