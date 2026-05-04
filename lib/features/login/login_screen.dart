import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _showLoginForm = false;
  String? _feedback;

  String? _validateInputs() {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      return 'Informe usuário e senha para continuar.';
    }
    if (username.length < 3) {
      return 'Usuário deve ter ao menos 3 caracteres.';
    }
    if (password.length < 3) {
      return 'Senha deve ter ao menos 3 caracteres.';
    }
    if (username.length > 32 || password.length > 64) {
      return 'Credenciais inválidas para este ambiente.';
    }
    return null;
  }

  void _login() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final validationError = _validateInputs();
    if (validationError != null) {
      setState(() => _feedback = validationError);
      return;
    }
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final result = await authService.loginWithCredentials(
        username: _userCtrl.text,
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _feedback = null;
        });
        return;
      }

      setState(() {
        switch (result.failureReason) {
          case AuthFailureReason.configurationMissing:
            _feedback = 'Credenciais do sistema não configuradas.';
            break;
          case AuthFailureReason.locked:
            final minutes = result.lockRemaining == null
                ? 5
                : (result.lockRemaining!.inSeconds / 60).ceil();
            _feedback =
                'Muitas tentativas inválidas. Tente novamente em $minutes min.';
            break;
          case AuthFailureReason.invalidCredentials:
            final left = result.remainingAttempts ?? 0;
            _feedback =
                'Usuário ou senha inválidos. Tentativas restantes: $left.';
            break;
            case AuthFailureReason.networkError:
              _feedback =
                  'Erro de conexão. Verifique sua internet e tente novamente.';
              break;
          case null:
            _feedback = 'Falha inesperada no login.';
            break;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginWithDevShortcut() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final ok = await authService.loginWithDevShortcut();
      if (!mounted) return;
      if (ok) {
        _userCtrl.clear();
        _passCtrl.clear();
      }
      setState(() {
        _feedback = ok ? null : 'Atalho DEV indisponível para este build.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0F19),
                  Color(0xFF111827),
                  Color(0xFF0B0F19),
                ],
              ),
            ),
          ),

          // Sutil grid pattern
          CustomPaint(
            painter: _GridPainter(),
            size: MediaQuery.of(context).size,
          ),

          // Glow central
          Center(
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.atrOrange.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 60),

                  // Logo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.atrOrange.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.atrOrange.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.truck,
                      size: 48,
                      color: AppColors.atrOrange,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.3, 0.3),
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 600.ms),

                  const SizedBox(height: 28),

                  // Título
                  Text(
                    'ATR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 52,
                      letterSpacing: 8,
                      shadows: [
                        Shadow(
                          color: AppColors.atrOrange.withValues(alpha: 0.35),
                          blurRadius: 35,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  )
                      .animate(delay: 150.ms)
                      .fadeIn(duration: 600.ms)
                      .moveY(begin: 12, end: 0),

                  const SizedBox(height: 6),

                  // Subtítulo
                  Text(
                    'Locações',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 5,
                    ),
                  ).animate(delay: 250.ms).fadeIn(duration: 600.ms),

                  const SizedBox(height: 10),

                  // Linha
                  Container(
                    width: 70,
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.atrOrange.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                      .animate(delay: 350.ms)
                      .fadeIn(duration: 600.ms)
                      .scaleX(begin: 0, duration: 600.ms),

                  const SizedBox(height: 18),

                  // Tagline
                  Text(
                    'Gestão Inteligente de Frotas',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.32),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ).animate(delay: 450.ms).fadeIn(duration: 600.ms),

                  const SizedBox(height: 52),

                  // Formulário ou Botão
                  if (!_showLoginForm)
                    // Botão de Iniciar Login
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 280,
                            height: 50,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _showLoginForm = true);
                                  HapticFeedback.lightImpact();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.atrOrange.withValues(alpha: 0.92),
                                        AppColors.atrOrange,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.atrOrange
                                            .withValues(alpha: 0.25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Fazer Login',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          LucideIcons.arrowRight,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (context.read<AuthService>().canUseDevShortcut) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 280,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loginWithDevShortcut,
                                icon: const Icon(LucideIcons.zap, size: 16),
                                label: const Text('Entrar sem senha (teste)'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                        .animate(delay: 550.ms)
                        .fadeIn(duration: 500.ms)
                        .moveY(begin: 15, end: 0)
                  else
                    // Campos de entrada com animação
                    AnimatedOpacity(
                      opacity: _showLoginForm ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SizedBox(
                          width: 340,
                          child: Column(
                            children: [
                              _AuthInput(
                                controller: _userCtrl,
                                hintText: 'Usuário',
                                icon: LucideIcons.user,
                                obscure: false,
                              ),
                              const SizedBox(height: 12),
                              _AuthInput(
                                controller: _passCtrl,
                                hintText: 'Senha',
                                icon: LucideIcons.lock,
                                obscure: _obscurePass,
                                maxLength: 64,
                                suffixIcon: IconButton(
                                  tooltip: _obscurePass
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                  icon: Icon(
                                    _obscurePass
                                        ? LucideIcons.eye
                                        : LucideIcons.eyeOff,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                ),
                                onSubmitted: (_) => _login(),
                              ),
                              if (_feedback != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _feedback!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFF9999),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .moveY(begin: 10, end: 0),

                  const SizedBox(height: 24),

                  // Botão de envio (aparece somente quando formulário é mostrado)
                  if (_showLoginForm)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: 280,
                        height: 50,
                        child: _LoginButton(loading: _loading, onTap: _login),
                      ),
                    )
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 400.ms)
                        .moveY(begin: 10, end: 0),

                  const SizedBox(height: 50),

                  // Footer
                  Text(
                    'v1.0.0 • ATR Locações © 2026',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 11,
                    ),
                  ).animate(delay: 750.ms).fadeIn(duration: 500.ms),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoginButton({required this.loading, required this.onTap});
  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscure;
  final int maxLength;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _AuthInput({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.obscure,
    this.maxLength = 32,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              maxLength: maxLength,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.42)),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          if (suffixIcon != null) suffixIcon!,
        ],
      ),
    );
  }
}

class _LoginButtonState extends State<_LoginButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovering
                  ? [AppColors.atrOrange, const Color(0xFFFF7A45)]
                  : [
                      AppColors.atrOrange.withValues(alpha: 0.92),
                      AppColors.atrOrange,
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.atrOrange
                    .withValues(alpha: _hovering ? 0.35 : 0.18),
                blurRadius: _hovering ? 28 : 14,
                spreadRadius: _hovering ? 1 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Entrar no Sistema',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 9),
                        Icon(
                          LucideIcons.arrowRight,
                          color: Colors.white,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 0.5;
    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
