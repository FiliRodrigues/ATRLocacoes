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
      'create-user',
      body: {
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
        .eq('ativo', true)
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
}
