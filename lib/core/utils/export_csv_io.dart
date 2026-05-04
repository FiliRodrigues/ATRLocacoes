import 'dart:io';

Future<void> exportCsv(String fileName, String csvContent) async {
  try {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null) {
      // Tenta salvar na pasta Downloads
      final path = '$home/Downloads/$fileName';
      final file = File(path);
      await file.writeAsString(csvContent);
    }
  } catch (e) {
    print('Erro ao exportar CSV no Windows: $e');
  }
}
