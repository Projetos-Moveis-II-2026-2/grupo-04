import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/pages/register_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_auth_notifier.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  group('RegisterPage Widget Tests', () {
    testWidgets('renderiza campos de cadastro e botão Cadastrar', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier();

      await pumpApp(
        tester,
        child: const RegisterPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      expect(find.text('Criar conta'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirmar Senha'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Cadastrar'), findsOneWidget);
    });

    testWidgets(
      'valida email, senha mínima e confirmação divergente sem chamar signUp',
      (tester) async {
        final fakeAuth = FakeAuthNotifier();

        await pumpApp(
          tester,
          child: const RegisterPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        // Campos vazios
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pump();

        expect(find.text('Email obrigatório'), findsOneWidget);
        expect(find.text('Senha obrigatória'), findsNWidgets(2));
        expect(fakeAuth.signUpCalls, isEmpty);

        // Email inválido e senha curta
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'invalido',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'),
          '123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar Senha'),
          '123',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pump();

        expect(find.text('Email inválido'), findsOneWidget);
        expect(find.text('Mínimo de 6 caracteres'), findsNWidgets(2));
        expect(fakeAuth.signUpCalls, isEmpty);

        // Confirmação divergente
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'atleta@olimpus.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'),
          '123456',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar Senha'),
          '654321',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pump();

        expect(find.text('Senhas não coincidem'), findsOneWidget);
        expect(fakeAuth.signUpCalls, isEmpty);
      },
    );

    testWidgets(
      'submit válido chama signUp e redireciona para confirmação pendente',
      (tester) async {
        final fakeAuth = FakeAuthNotifier(
          onSignUp: (email, password) async =>
              AppUser(id: 'u-novo', email: email, emailConfirmedAt: null),
        );
        final router = buildTestRouter(
          initialLocation: '/register',
          routes: [
            GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
            GoRoute(
              path: '/confirmation',
              builder: (_, state) => Scaffold(
                body: Text('Confirmar: ${state.uri.queryParameters['email']}'),
              ),
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
          'novo@olimpus.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'),
          '123456',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar Senha'),
          '123456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pumpAndSettleBounded();

        expect(fakeAuth.signUpCalls, [
          (email: 'novo@olimpus.com', password: '123456'),
        ]);
        expect(find.text('Confirmar: novo@olimpus.com'), findsOneWidget);
      },
    );

    testWidgets('exibe SnackBar quando email já está cadastrado', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier(
        onSignUp: (_, _) async =>
            throw const AuthException('User already registered'),
      );

      await pumpApp(
        tester,
        child: const RegisterPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'usado@olimpus.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Senha'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          'Este email já está cadastrado. Faça login ou use outro email.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('exibe SnackBar padrão para erro desconhecido no cadastro', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier(
        onSignUp: (_, _) async => throw Exception('erro inesperado'),
      );

      await pumpApp(
        tester,
        child: const RegisterPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'novo@olimpus.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Senha'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Ocorreu um erro ao criar a conta. Tente novamente.'),
        findsOneWidget,
      );
    });

    testWidgets('estado loading desabilita botão e exibe indicador', (
      tester,
    ) async {
      final completer = Completer<AppUser?>();
      final fakeAuth = FakeAuthNotifier(onSignUp: (_, _) => completer.future);

      await pumpApp(
        tester,
        child: const RegisterPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'novo@olimpus.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar Senha'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cadastrar'), findsNothing);

      completer.complete(null);
      await tester.pump();
    });
  });
}
