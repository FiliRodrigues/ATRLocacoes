import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fleet_app/core/services/auth_service.dart';
import 'package:fleet_app/features/login/login_screen.dart';

class _FakeAuthService extends AuthService {
  final AuthAttemptResult result;

  _FakeAuthService(this.result);

  @override
  Future<AuthAttemptResult> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    return result;
  }
}

void main() {
  Widget buildApp(AuthService authService) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const LoginScreen(),
      ),
    );
  }

  testWidgets('exibe validação quando usuário e senha estão vazios',
      (tester) async {
    await tester.pumpWidget(
      buildApp(
        _FakeAuthService(const AuthAttemptResult.success()),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Fazer Login'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar no Sistema'));
    await tester.pump();

    expect(
      find.text('Informe usuário e senha para continuar.'),
      findsOneWidget,
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('exibe feedback para credenciais inválidas', (tester) async {
    final auth = _FakeAuthService(
      const AuthAttemptResult.failure(
        reason: AuthFailureReason.invalidCredentials,
        remainingAttempts: 4,
      ),
    );

    await tester.pumpWidget(buildApp(auth));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Fazer Login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'adm');
    await tester.enterText(find.byType(TextField).last, 'errada123');
    await tester.tap(find.text('Entrar no Sistema'));
    await tester.pump();

    expect(
      find.text('Usuário ou senha inválidos. Tentativas restantes: 4.'),
      findsOneWidget,
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('exibe validação para usuário curto', (tester) async {
    await tester.pumpWidget(
      buildApp(_FakeAuthService(const AuthAttemptResult.success())),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Fazer Login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ab');
    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.text('Entrar no Sistema'));
    await tester.pump();

    expect(
      find.text('Usuário deve ter ao menos 3 caracteres.'),
      findsOneWidget,
    );
  });
}
