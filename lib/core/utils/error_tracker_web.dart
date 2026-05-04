import 'package:flutter/foundation.dart';

Future<void> saveErrorLog(String message) async {
  final timestamp = DateTime.now().toIso8601String();
  debugPrint(
      '[WEB LOG - $timestamp]\n$message\n--------------------------------------------\n',);
}
