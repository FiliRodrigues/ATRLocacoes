import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

class AuthService extends ChangeNotifier {
  static bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      AppLogger.info('Verificação de sessão: ${_isAuthenticated ? 'Autenticado' : 'Visitante'}');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Falha ao verificar sessão', e);
    }
  }

  Future<void> login() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = true;
      await prefs.setBool('is_authenticated', true);
      AppLogger.success('Usuário logado com sucesso (Sessão Persistida)');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Erro no processo de login', e);
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = false;
      await prefs.setBool('is_authenticated', false);
      AppLogger.warning('Usuário realizou logout');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Erro ao encerrar sessão', e);
    }
  }
}