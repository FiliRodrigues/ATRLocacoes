import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../utils/app_logger.dart';
import 'audit_service.dart';

// ── Storage keys (apenas lockout local — sessão fica no Supabase) ────
const String _kFailedAttemptsKey = 'auth_failed_attempts';
const String _kLockedUntilKey = 'auth_locked_until_ms';
const Duration _kLockDuration = Duration(minutes: 5);
const int _kMaxAttempts = 5;

/// Sufixo de email aplicado quando o usuário digita só o "username" (sem `@`).
/// Mantido para compatibilidade com os usernames legados (`adm`, `filippe`)
/// que foram migrados para `<username>@atr.local` na migration 017.
const String _kDefaultEmailDomain = '@atr.local';

enum AuthUserRole { admin, fleet }

enum AuthFailureReason {
  invalidCredentials,
  locked,
  configurationMissing,
  networkError,
}

class AuthUser {
  final String username;
  final AuthUserRole role;
  final String tenantId;

  const AuthUser({
    required this.username,
    required this.role,
    this.tenantId = kDefaultTenantId,
  });
}

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

/// Serviço de autenticação backed por **Supabase Auth**.
///
/// Mudança v4 (P002 fix — migração 017): toda a lógica de senha custom
/// (`PBKDF2-like`, sal determinístico, HMAC de sessão hardcoded) foi removida.
/// O Supabase Auth gerencia hashing (bcrypt), expiração, refresh e
/// persistência segura. As policies RLS leem `tenant_id` e `role` do
/// JWT (claim em `app_metadata`), eliminando o bypass via `set_app_tenant`.
class AuthService extends ChangeNotifier {
  final DateTime Function() _now;
  AuthUser? _currentUser;
  bool _isAuthenticated = false;

  AuthService({DateTime Function()? now}) : _now = now ?? DateTime.now {
    // Reage a SIGNED_IN/SIGNED_OUT/TOKEN_REFRESHED do Supabase
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _hydrateFromSession(data.session);
      notifyListeners();
    });
  }

  // ── Getters públicos ────────────────────────────────────────────────
  bool get isAuthenticated => _isAuthenticated;
  AuthUser? get currentUser => _currentUser;
  AuthUserRole? get currentRole => _currentUser?.role;
  bool get isFleetOnlyUser => currentRole == AuthUserRole.fleet;

  /// Atalho DEV: criação de sessão Supabase em DEV exige credenciais
  /// reais, então o atalho fica desabilitado. Mantido como `false` para
  /// preservar o contrato com `LoginScreen` sem expor superfície de risco.
  bool get canUseDevShortcut => false;

  // ── Hidratar AuthUser a partir do JWT ───────────────────────────────
  void _hydrateFromSession(Session? session) {
    if (session == null) {
      _isAuthenticated = false;
      _currentUser = null;
      AuditService.setCurrentUser(null, tenantId: null);
      return;
    }

    final user = session.user;
    final meta = user.appMetadata;
    final tenantId = (meta['tenant_id'] as String?) ?? kDefaultTenantId;
    final roleStr = (meta['role'] as String?) ?? 'admin';
    final role = roleStr == 'fleet' ? AuthUserRole.fleet : AuthUserRole.admin;
    final username = (meta['username'] as String?) ?? user.email ?? 'desconhecido';

    _isAuthenticated = true;
    _currentUser = AuthUser(username: username, role: role, tenantId: tenantId);
    AuditService.setCurrentUser(username, tenantId: tenantId);
  }

  // ── Restaurar sessão persistida (chamada na inicialização) ─────────
  Future<void> checkAuth() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      _hydrateFromSession(session);
      AppLogger.info(
        'Verificação de sessão: ${_isAuthenticated ? 'Autenticado' : 'Visitante'}',
      );
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Falha ao verificar sessão', e);
      debugPrintStack(stackTrace: s);
    }
  }

  // ── Login ───────────────────────────────────────────────────────────
  Future<AuthAttemptResult> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    final input = username.trim();
    final email = input.contains('@')
        ? input.toLowerCase()
        : '${input.toLowerCase()}$_kDefaultEmailDomain';

    final prefs = await SharedPreferences.getInstance();
    final now = _now();

    // Lockout local — defesa em profundidade sobre o rate limit do Supabase
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

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session != null) {
        _hydrateFromSession(res.session);
        await prefs.remove(_kFailedAttemptsKey);
        await AuditService.log(
          action: AuditAction.login,
          entity: AuditEntity.usuario,
          entityId: _currentUser?.username ?? email,
        );
        AppLogger.success('Usuário logado com sucesso');
        notifyListeners();
        return const AuthAttemptResult.success();
      }
    } on AuthException catch (e) {
      AppLogger.warning('Auth recusada: ${e.message}');
      // segue pro fluxo de tentativa inválida abaixo
    } catch (e) {
      AppLogger.error('Falha de rede ou genérica no login', e);
      return const AuthAttemptResult.failure(
        reason: AuthFailureReason.networkError,
      );
    }

    final attempts = (prefs.getInt(_kFailedAttemptsKey) ?? 0) + 1;
    if (attempts >= _kMaxAttempts) {
      final lockUntil = now.add(_kLockDuration);
      await prefs.setInt(_kLockedUntilKey, lockUntil.millisecondsSinceEpoch);
      await prefs.remove(_kFailedAttemptsKey);
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

  // ── Atalho dev (desabilitado; preserva contrato com LoginScreen) ───
  Future<bool> loginWithDevShortcut() async {
    if (!canUseDevShortcut) return false;
    return false;
  }

  Future<void> login() async {
    // Mantido para compat com chamadas internas; sem efeito sem credenciais.
    AppLogger.warning('login() sem credenciais — ignorado (use loginWithCredentials)');
  }

  // ── Logout ──────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final loggedOutUser = _currentUser?.username ?? 'desconhecido';
      await Supabase.instance.client.auth.signOut();
      await AuditService.log(
        action: AuditAction.logout,
        entity: AuditEntity.usuario,
        entityId: loggedOutUser,
      );
      _isAuthenticated = false;
      _currentUser = null;
      AuditService.setCurrentUser(null, tenantId: null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFailedAttemptsKey);
      await prefs.remove(_kLockedUntilKey);

      AppLogger.warning('Usuário realizou logout');
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Erro ao encerrar sessão', e);
      debugPrintStack(stackTrace: s);
    }
  }
}
