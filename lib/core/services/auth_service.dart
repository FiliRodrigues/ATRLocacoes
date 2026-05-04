import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'audit_service.dart';

const String _kAuthKey = 'is_authenticated';
const String _kSessionStartKey = 'session_started_at_ms';
const String _kSessionProofKey = 'session_proof';
const String _kSessionUserKey = 'session_user';
const String _kSessionRoleKey = 'session_role';
const String _kSessionTenantKey = 'session_tenant_id';
const String _kFailedAttemptsKey = 'auth_failed_attempts';
const String _kLockedUntilKey = 'auth_locked_until_ms';
const Duration _kSessionDuration = Duration(hours: 12);
const Duration _kLockDuration = Duration(minutes: 5);
const int _kMaxAttempts = 5;

/// UUID do tenant padrão ATR — usado como fallback e no login DEV.
const String kDefaultTenantId = '00000000-0000-0000-0000-000000000001';

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

/// Serviço de autenticação: persiste sessão via [SharedPreferences].
///
/// Valida credenciais contra a tabela [app_users] no Supabase,
/// suportando múltiplos usuários simultâneos com senhas com hash SHA-256.
/// Expõe [isAuthenticated] como estado reativo via [ChangeNotifier].
class AuthService extends ChangeNotifier {
  final DateTime Function() _now;

  /// Função de lookup injetável — padrão consulta Supabase [app_users].
  /// Injetar em testes para evitar dependência de Supabase real.
  final Future<Map<String, dynamic>?> Function(String username) _userLookup;

  bool _isAuthenticated = false;
  AuthUser? _currentUser;

  AuthService({
    DateTime Function()? now,
    Future<Map<String, dynamic>?> Function(String username)? userLookup,
  })  : _now = now ?? DateTime.now,
        _userLookup = userLookup ?? _defaultSupabaseLookup;

  // ── Supabase lookup padrão ──────────────────────────────────────────
  static Future<Map<String, dynamic>?> _defaultSupabaseLookup(
      String username) async {
    final rows = await Supabase.instance.client
        .from('app_users')
        .select('username, password_hash, password_salt, role, ativo, tenant_id')
        .eq('username', username)
        .eq('ativo', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  // ── Hash de senha: SHA-256(salt:password:atr-salt-v1) ──────────────
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password:atr-salt-v1');
    return sha256.convert(bytes).toString();
  }

  // ── Getters públicos ────────────────────────────────────────────────
  bool get isAuthenticated => _isAuthenticated;
  AuthUser? get currentUser => _currentUser;
  AuthUserRole? get currentRole => _currentUser?.role;
  bool get isFleetOnlyUser => currentRole == AuthUserRole.fleet;

  /// Atalho dev: disponível apenas em builds debug (kDebugMode).
  bool get canUseDevShortcut => kDebugMode;

  // ── Prova de integridade da sessão local ────────────────────────────
  String _sessionProofFor(
    int sessionStartMs, {
    required String username,
    required AuthUserRole role,
    String tenantId = kDefaultTenantId,
  }) {
    const int fnvPrime = 16777619;
    int hash = 2166136261;
    final payload =
        '$sessionStartMs|${username.toLowerCase()}|${role.name}|$tenantId|atr-v3';
    for (final unit in payload.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  // ── Atalho DEV (só funciona em kDebugMode) ──────────────────────────
  Future<bool> loginWithDevShortcut() async {
    if (!canUseDevShortcut) return false;
    await login();
    AppLogger.warning('Atalho de login DEV utilizado');
    return true;
  }

  // ── Login com credenciais (multi-user via Supabase) ─────────────────
  Future<AuthAttemptResult> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    final normalizedUser = username.trim().toLowerCase();
    final normalizedPass = password.trim();

    final prefs = await SharedPreferences.getInstance();
    final now = _now();

    // Verificar bloqueio por excesso de tentativas
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

    // Consultar Supabase
    try {
      final row = await _userLookup(normalizedUser);
      if (row != null) {
        final salt = row['password_salt'] as String;
        final storedHash = row['password_hash'] as String;
        final computedHash = hashPassword(normalizedPass, salt);
        if (computedHash == storedHash) {
          final roleStr = row['role'] as String? ?? 'admin';
          final role =
              roleStr == 'fleet' ? AuthUserRole.fleet : AuthUserRole.admin;
          final tenantId =
              row['tenant_id'] as String? ?? kDefaultTenantId;
          await _persistAuthenticatedSession(
            prefs,
            username: row['username'] as String,
            role: role,
            tenantId: tenantId,
            sessionStartMs: now.millisecondsSinceEpoch,
          );
          AppLogger.success('Usuário logado com sucesso (credenciais válidas)');
          return const AuthAttemptResult.success();
        }
      }
    } catch (e) {
      AppLogger.error('Falha ao consultar base de usuários', e);
      return const AuthAttemptResult.failure(
          reason: AuthFailureReason.networkError);
    }

    // Credenciais inválidas — incrementar tentativas
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

  // ── Restaurar sessão persistida ─────────────────────────────────────
  Future<void> checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final persistedAuth = prefs.getBool(_kAuthKey) ?? false;
      final sessionStartMs = prefs.getInt(_kSessionStartKey);
      final sessionProof = prefs.getString(_kSessionProofKey);
      final sessionUser = prefs.getString(_kSessionUserKey);
      final sessionRoleName = prefs.getString(_kSessionRoleKey);
      final sessionTenantId =
          prefs.getString(_kSessionTenantKey) ?? kDefaultTenantId;

      if (!persistedAuth ||
          sessionStartMs == null ||
          sessionProof == null ||
          sessionUser == null ||
          sessionRoleName == null) {
        _isAuthenticated = false;
        _currentUser = null;
        await _clearSession(prefs);
        notifyListeners();
        return;
      }

      final matchingRoles = AuthUserRole.values.where(
        (role) => role.name == sessionRoleName,
      );
      if (matchingRoles.isEmpty) {
        _isAuthenticated = false;
        _currentUser = null;
        await _clearSession(prefs);
        notifyListeners();
        return;
      }
      final sessionRole = matchingRoles.first;

      // Validar prova de integridade (evita edição manual do SharedPreferences)
      if (sessionProof !=
          _sessionProofFor(
            sessionStartMs,
            username: sessionUser,
            role: sessionRole,
            tenantId: sessionTenantId,
          )) {
        _isAuthenticated = false;
        _currentUser = null;
        await _clearSession(prefs);
        AppLogger.warning(
            'Sessão inválida detectada (integridade comprometida)');
        notifyListeners();
        return;
      }

      final sessionStart = DateTime.fromMillisecondsSinceEpoch(sessionStartMs);
      final sessionExpired =
          _now().difference(sessionStart) > _kSessionDuration;

      if (sessionExpired) {
        _isAuthenticated = false;
        _currentUser = null;
        await _clearSession(prefs);
        AppLogger.warning('Sessão expirada automaticamente');
      } else {
        _isAuthenticated = true;
        _currentUser = AuthUser(
          username: sessionUser,
          role: sessionRole,
          tenantId: sessionTenantId,
        );
        AuditService.setCurrentUser(sessionUser, tenantId: sessionTenantId);
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

  // ── Atalho dev: persiste sessão sem consultar Supabase ──────────────
  Future<void> login() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _persistAuthenticatedSession(
        prefs,
        username: 'dev',
        role: AuthUserRole.admin,
        tenantId: kDefaultTenantId,
        sessionStartMs: _now().millisecondsSinceEpoch,
      );
      AppLogger.success('Usuário logado com sucesso (Atalho DEV)');
    } catch (e, s) {
      AppLogger.error('Erro no processo de login', e);
      debugPrintStack(stackTrace: s);
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedOutUser = _currentUser?.username ?? 'desconhecido';
      _isAuthenticated = false;
      _currentUser = null;
      await AuditService.log(
        action: AuditAction.logout,
        entity: AuditEntity.usuario,
        entityId: loggedOutUser,
      );
      AuditService.setCurrentUser(null, tenantId: null);
      await _clearSession(prefs);
      AppLogger.warning('Usuário realizou logout');
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Erro ao encerrar sessão', e);
      debugPrintStack(stackTrace: s);
    }
  }

  // ── Internos ────────────────────────────────────────────────────────
  Future<void> _clearSession(SharedPreferences prefs) async {
    try {
      await prefs.remove(_kAuthKey);
      await prefs.remove(_kSessionStartKey);
      await prefs.remove(_kSessionProofKey);
      await prefs.remove(_kSessionUserKey);
      await prefs.remove(_kSessionRoleKey);
      await prefs.remove(_kSessionTenantKey);
      await prefs.remove(_kFailedAttemptsKey);
      await prefs.remove(_kLockedUntilKey);
    } catch (e) {
      AppLogger.error('Falha ao limpar sessão', e);
    }
  }

  Future<void> _persistAuthenticatedSession(
    SharedPreferences prefs, {
    required String username,
    required AuthUserRole role,
    required int sessionStartMs,
    String tenantId = kDefaultTenantId,
  }) async {
    _isAuthenticated = true;
    _currentUser = AuthUser(username: username, role: role, tenantId: tenantId);
    AuditService.setCurrentUser(username, tenantId: tenantId);
    await prefs.setBool(_kAuthKey, true);
    await prefs.setInt(_kSessionStartKey, sessionStartMs);
    await prefs.setString(
      _kSessionProofKey,
      _sessionProofFor(
        sessionStartMs,
        username: username,
        role: role,
        tenantId: tenantId,
      ),
    );
    await prefs.setString(_kSessionUserKey, username);
    await prefs.setString(_kSessionRoleKey, role.name);
    await prefs.setString(_kSessionTenantKey, tenantId);
    await prefs.remove(_kFailedAttemptsKey);
    await prefs.remove(_kLockedUntilKey);
    AuditService.log(
      action: AuditAction.login,
      entity: AuditEntity.usuario,
      entityId: username,
    );
    notifyListeners();
  }
}
