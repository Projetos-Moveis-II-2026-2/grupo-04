import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_auth_notifier.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  group('ForgotPasswordPage Widget Tests', () {
    testWidgets('renderiza título, instrução, campo Email e botão de envio', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier();

      await pumpApp(
        tester,
        child: const ForgotPasswordPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      expect(find.text('Recuperar Senha'), findsOneWidget);
      expect(
        find.text(
          'Digite seu email para receber o link de recuperação de senha.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
        findsOneWidget,
      );
    });

    testWidgets('valida email vazio e inválido sem chamar sendPasswordReset', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier();

      await pumpApp(
        tester,
        child: const ForgotPasswordPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
      );
      await tester.pump();

      expect(find.text('Email obrigatório'), findsOneWidget);
      expect(fakeAuth.sendPasswordResetCalls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalido',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
      );
      await tester.pump();

      expect(find.text('Email inválido'), findsOneWidget);
      expect(fakeAuth.sendPasswordResetCalls, isEmpty);
    });

    testWidgets('estado loading desabilita botão e exibe indicador', (
      tester,
    ) async {
      final completer = Completer<void>();
      final fakeAuth = FakeAuthNotifier(
        onSendPasswordReset: (_) => completer.future,
      );

      await pumpApp(
        tester,
        child: const ForgotPasswordPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'atleta@olimpus.com',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
      );
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Enviar Link de Recuperação'), findsNothing);

      completer.complete();
      await tester.pump();
    });

    testWidgets(
      'envio com sucesso exibe tela de confirmação e permite voltar ao login',
      (tester) async {
        final fakeAuth = FakeAuthNotifier(onSendPasswordReset: (_) async {});
        final router = buildTestRouter(
          initialLocation: '/forgot-password',
          routes: [
            GoRoute(
              path: '/forgot-password',
              builder: (_, _) => const ForgotPasswordPage(),
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
          find.widgetWithText(TextFormField, 'Email'),
          '  atleta@olimpus.com  ',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
        );
        await tester.pumpAndSettleBounded();

        expect(fakeAuth.sendPasswordResetCalls, ['atleta@olimpus.com']);
        expect(
          find.text(
            'Se o email estiver cadastrado, você receberá '
            'um link de recuperação em instantes.',
          ),
          findsOneWidget,
        );
        expect(find.text('Verifique também a pasta de spam.'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Voltar ao Login'),
        );
        await tester.pumpAndSettleBounded();

        expect(find.text('Tela Login'), findsOneWidget);
      },
    );

    testWidgets(
      'erro no envio exibe SnackBar mapeada e mantém formulário na tela',
      (tester) async {
        final fakeAuth = FakeAuthNotifier(
          onSendPasswordReset: (_) async =>
              throw const AuthException('rate limit exceeded'),
        );

        await pumpApp(
          tester,
          child: const ForgotPasswordPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'atleta@olimpus.com',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
          findsOneWidget,
        );
      },
    );

    testWidgets('erro genérico exibe mensagem padrão no SnackBar', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier(
        onSendPasswordReset: (_) async => throw Exception('erro inesperado'),
      );

      await pumpApp(
        tester,
        child: const ForgotPasswordPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'atleta@olimpus.com',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar Link de Recuperação'),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Ocorreu um erro. Tente novamente.'), findsOneWidget);
    });
  });
}
