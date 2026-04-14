import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

const String _kAuthKey = 'is_authenticated';
const String _kSessionStartKey = 'session_started_at_ms';
const String _kFailedAttemptsKey = 'auth_failed_attempts';
const String _kLockedUntilKey = 'auth_locked_until_ms';
const Duration _kSessionDuration = Duration(hours: 12);
const Duration _kLockDuration = Duration(minutes: 5);
const int _kMaxAttempts = 5;

const String _kConfiguredUser = String.fromEnvironment('ATR_LOGIN_USER');
const String _kConfiguredPass = String.fromEnvironment('ATR_LOGIN_PASS');
const bool _kDevQuickLoginEnabled = bool.fromEnvironment('ATR_DEV_QUICK_LOGIN');

enum AuthFailureReason { invalidCredentials, locked, configurationMissing }

class AuthAttemptResult {
  final bool success;
  final AuthFailureReason? failureReason;
  final int? remainingAttempts;
  final Duration? lockRemaining;

  const AuthAttemptResult._({
    required this.success,
    this.failureReason,
    this.remainingAttempts,
    this.lockRemaining,
  });

  const AuthAttemptResult.success() : this._(success: true);

  const AuthAttemptResult.failure({
    required AuthFailureReason reason,
    int? remainingAttempts,
    Duration? lockRemaining,
  }) : this._(
          success: false,
          failureReason: reason,
          remainingAttempts: remainingAttempts,
          lockRemaining: lockRemaining,
        );
}

/// Serviço de autenticação: persiste sessão via [SharedPreferences].
///
/// Expõe [isAuthenticated] como estado reativo via [ChangeNotifier].
class AuthService extends ChangeNotifier {
  final String _configuredUser;
  final String _configuredPass;
  final DateTime Function() _now;
  bool _isAuthenticated = false;

  AuthService({
    String? configuredUser,
    String? configuredPass,
    DateTime Function()? now,
  })  : _configuredUser = configuredUser ?? _kConfiguredUser,
        _configuredPass = configuredPass ?? _kConfiguredPass,
        _now = now ?? DateTime.now;

  bool get isAuthenticated => _isAuthenticated;

  bool get hasConfiguredCredentials {
    return _configuredUser.isNotEmpty && _configuredPass.isNotEmpty;
  }

  bool get canUseDevShortcut => kDebugMode && _kDevQuickLoginEnabled;

  Future<bool> loginWithDevShortcut() async {
    if (!canUseDevShortcut) return false;
    await login();
    AppLogger.warning('Atalho de login DEV utilizado');
    return true;
  }

  Future<AuthAttemptResult> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    final normalizedUser = username.trim();
    final normalizedPass = password.trim();

    if (!hasConfiguredCredentials) {
      AppLogger.warning(
        'Login bloqueado: credenciais de ambiente não configuradas',
      );
      return const AuthAttemptResult.failure(
        reason: AuthFailureReason.configurationMissing,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final now = _now();
    final lockUntilMs = prefs.getInt(_kLockedUntilKey);
    if (lockUntilMs != null) {
      final lockUntil = DateTime.fromMillisecondsSinceEpoch(lockUntilMs);
      if (now.isBefore(lockUntil)) {
        return AuthAttemptResult.failure(
          reason: AuthFailureReason.locked,
          lockRemaining: lockUntil.difference(now),
        );
      }
      await prefs.remove(_kLockedUntilKey);
    }

    final isValid =
        normalizedUser == _configuredUser && normalizedPass == _configuredPass;
    if (isValid) {
      _isAuthenticated = true;
      await prefs.setBool(_kAuthKey, true);
      await prefs.setInt(_kSessionStartKey, now.millisecondsSinceEpoch);
      await prefs.remove(_kFailedAttemptsKey);
      await prefs.remove(_kLockedUntilKey);
      AppLogger.success('Usuário logado com sucesso (credenciais válidas)');
      notifyListeners();
      return const AuthAttemptResult.success();
    }

    final attempts = (prefs.getInt(_kFailedAttemptsKey) ?? 0) + 1;
    if (attempts >= _kMaxAttempts) {
      final lockUntil = now.add(_kLockDuration);
      await prefs.setInt(_kLockedUntilKey, lockUntil.millisecondsSinceEpoch);
      await prefs.remove(_kFailedAttemptsKey);
      AppLogger.warning('Login bloqueado por excesso de tentativas');
      return const AuthAttemptResult.failure(
        reason: AuthFailureReason.locked,
        lockRemaining: _kLockDuration,
      );
    }

    await prefs.setInt(_kFailedAttemptsKey, attempts);
    return AuthAttemptResult.failure(
      reason: AuthFailureReason.invalidCredentials,
      remainingAttempts: _kMaxAttempts - attempts,
    );
  }

  /// Lê o estado de sessão persistido e notifica ouvintes.
  Future<void> checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final persistedAuth = prefs.getBool(_kAuthKey) ?? false;
      final sessionStartMs = prefs.getInt(_kSessionStartKey);

      if (!persistedAuth || sessionStartMs == null) {
        _isAuthenticated = false;
        await _clearSession(prefs);
        notifyListeners();
        return;
      }

      final sessionStart = DateTime.fromMillisecondsSinceEpoch(sessionStartMs);
      final sessionExpired =
          _now().difference(sessionStart) > _kSessionDuration;

      if (sessionExpired) {
        _isAuthenticated = false;
        await _clearSession(prefs);
        AppLogger.warning('Sessão expirada automaticamente');
      } else {
        _isAuthenticated = true;
      }

      AppLogger.info(
        'Verificação de sessão: ${_isAuthenticated ? 'Autenticado' : 'Visitante'}',
      );
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Falha ao verificar sessão', e);
      debugPrintStack(stackTrace: s);
    }
  }

  /// Persiste a sessão ativa e notifica ouvintes.
  Future<void> login() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = true;
      await prefs.setBool(_kAuthKey, true);
      await prefs.setInt(_kSessionStartKey, _now().millisecondsSinceEpoch);
      AppLogger.success('Usuário logado com sucesso (Sessão Persistida)');
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Erro no processo de login', e);
      debugPrintStack(stackTrace: s);
    }
  }

  /// Invalida a sessão e notifica ouvintes.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = false;
      await _clearSession(prefs);
      AppLogger.warning('Usuário realizou logout');
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Erro ao encerrar sessão', e);
      debugPrintStack(stackTrace: s);
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    try {
      await prefs.remove(_kAuthKey);
      await prefs.remove(_kSessionStartKey);
      await prefs.remove(_kFailedAttemptsKey);
      await prefs.remove(_kLockedUntilKey);
    } catch (e) {
      AppLogger.error('Falha ao limpar sessão', e);
    }
  }
}
