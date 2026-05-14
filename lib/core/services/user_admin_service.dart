import 'package:supabase_flutter/supabase_flutter.dart';

class UserAdminException implements Exception {
  final String message;
  const UserAdminException(this.message);
  @override
  String toString() => message;
}

class AppUser {
  final String username;
  final String role;
  final String nomeCompleto;
  final String? email;
  final bool ativo;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final List<String> allowedFeatures;
  final bool mustChangePassword;
  final String? id;

  const AppUser({
    required this.username,
    required this.role,
    required this.nomeCompleto,
    this.email,
    this.ativo = true,
    this.lastLogin,
    required this.createdAt,
    this.allowedFeatures = const [],
    this.mustChangePassword = false,
    this.id,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      nomeCompleto: json['nome_completo'] as String? ?? '',
      email: json['email'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      allowedFeatures: (json['allowed_features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mustChangePassword: json['must_change_password'] == true,
      id: json['id'] as String?,
    );
  }

  bool get isAdmin => role == 'admin';

  String get roleLabel => isAdmin ? 'Administrador' : 'Membro';
}

class UserAdminService {
  Future<void> createUser({
    required String email,
    required String password,
    required String username,
    required String nomeCompleto,
    required String role,
    required List<String> allowedFeatures,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'create_user',
        'email': email,
        'password': password,
        'username': username,
        'nome_completo': nomeCompleto,
        'role': role,
        'allowed_features': allowedFeatures,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<List<AppUser>> listUsers() async {
    final rows = await Supabase.instance.client
        .from('app_users')
        .select()
        .order('username')
        .limit(500);
    return (rows as List).map((r) => AppUser.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> setActive(String userId, bool ativo) async {
    await Supabase.instance.client
        .from('app_users')
        .update({'ativo': ativo}).eq('id', userId);
  }

  Future<void> updatePermissions(String userId, List<String> features) async {
    await Supabase.instance.client
        .from('app_users')
        .update({'allowed_features': features}).eq('id', userId);
  }

  Future<void> updateUser({
    required String id,
    String? username,
    String? nomeCompleto,
    String? role,
    List<String>? features,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'update_user',
        'user_id': id,
        if (username != null) 'username': username,
        if (nomeCompleto != null) 'nome_completo': nomeCompleto,
        if (role != null) 'role': role,
        if (features != null) 'allowed_features': features,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<void> resetPassword({
    required String id,
    required String newPassword,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'reset_password',
        'user_id': id,
        'password': newPassword,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<void> deleteUser(String id) async {
    final res = await Supabase.instance.client.functions.invoke(
      'manage-users',
      body: {
        'action': 'delete_user',
        'user_id': id,
      },
    );

    if (res.status != 200) {
      final data = res.data;
      final error = data is Map ? (data['error'] ?? 'Erro desconhecido') : 'Erro desconhecido';
      throw UserAdminException(error.toString());
    }
  }

  Future<void> reactivateUser(String userId) async {
    await Supabase.instance.client
        .from('app_users')
        .update({'ativo': true}).eq('id', userId);
  }

  Future<bool> verifyAdminPassword(String password) async {
    try {
      final currentEmail = Supabase.instance.client.auth.currentUser?.email;
      if (currentEmail == null) return false;

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: currentEmail,
        password: password,
      );
      return res.session != null;
    } catch (_) {
      return false;
    }
  }
}
