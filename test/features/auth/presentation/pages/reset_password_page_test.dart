import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/auth/presentation/pages/reset_password_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_auth_notifier.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  group('ResetPasswordPage Widget Tests', () {
    testWidgets('renderiza campos de nova senha e botão Redefinir Senha', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier();

      await pumpApp(
        tester,
        child: const ResetPasswordPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      expect(find.text('Nova Senha'), findsWidgets);
      expect(find.text('Defina sua nova senha.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nova Senha'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Redefinir Senha'),
        findsOneWidget,
      );
    });

    testWidgets(
      'valida senha obrigatória, tamanho mínimo e confirmação divergente',
      (tester) async {
        final fakeAuth = FakeAuthNotifier();

        await pumpApp(
          tester,
          child: const ResetPasswordPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        // Campos vazios
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Redefinir Senha'),
        );
        await tester.pump();

        expect(find.text('Senha obrigatória'), findsNWidgets(2));
        expect(fakeAuth.updatePasswordCalls, isEmpty);

        // Senha curta
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova Senha'),
          '123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
          '123',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Redefinir Senha'),
        );
        await tester.pump();

        expect(find.text('Mínimo de 6 caracteres'), findsNWidgets(2));
        expect(fakeAuth.updatePasswordCalls, isEmpty);

        // Confirmação divergente
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova Senha'),
          '123456',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
          '654321',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Redefinir Senha'),
        );
        await tester.pump();

        expect(find.text('Senhas não coincidem'), findsOneWidget);
        expect(fakeAuth.updatePasswordCalls, isEmpty);
      },
    );

    testWidgets('estado loading desabilita botão e exibe indicador', (
      tester,
    ) async {
      final completer = Completer<void>();
      final fakeAuth = FakeAuthNotifier(
        onUpdatePassword: (_) => completer.future,
      );
      final router = buildTestRouter(
        initialLocation: '/reset-password',
        routes: [
          GoRoute(
            path: '/reset-password',
            builder: (_, _) => const ResetPasswordPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('Tela Login')),
          ),
        ],
      );

      await pumpApp(
        tester,
        router: router,
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova Senha'),
        'novaSenha123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
        'novaSenha123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Redefinir Senha'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Redefinir Senha'), findsNothing);

      completer.complete();
      await tester.pumpAndSettleBounded();
    });

    testWidgets('redefinição com sucesso exibe SnackBar e navega para /login', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier(onUpdatePassword: (_) async {});
      final router = buildTestRouter(
        initialLocation: '/reset-password',
        routes: [
          GoRoute(
            path: '/reset-password',
            builder: (_, _) => const ResetPasswordPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('Tela Login')),
          ),
        ],
      );

      await pumpApp(
        tester,
        router: router,
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova Senha'),
        'novaSenha123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
        'novaSenha123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Redefinir Senha'));
      await tester.pumpAndSettleBounded();

      expect(fakeAuth.updatePasswordCalls, ['novaSenha123']);
      expect(
        find.text('Senha atualizada com sucesso! Faça login.'),
        findsOneWidget,
      );
      expect(find.text('Tela Login'), findsOneWidget);
    });

    testWidgets(
      'erro ao atualizar senha exibe mensagem mapeada no SnackBar sem navegar',
      (tester) async {
        final fakeAuth = FakeAuthNotifier(
          onUpdatePassword: (_) async =>
              throw const AuthException('New password should be different'),
        );

        await pumpApp(
          tester,
          child: const ResetPasswordPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova Senha'),
          'novaSenha123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
          'novaSenha123',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Redefinir Senha'),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('A nova senha deve ser diferente da senha atual.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('erro genérico exibe mensagem padrão no SnackBar', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier(
        onUpdatePassword: (_) async => throw Exception('erro inesperado'),
      );

      await pumpApp(
        tester,
        child: const ResetPasswordPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nova Senha'),
        'novaSenha123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Nova Senha'),
        'novaSenha123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Redefinir Senha'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Erro ao redefinir a senha. Tente novamente.'),
        findsOneWidget,
      );
    });
  });
}
