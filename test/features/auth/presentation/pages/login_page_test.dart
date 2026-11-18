import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/pages/login_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_auth_notifier.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  group('LoginPage Widget Tests', () {
    testWidgets('renderiza campos, botão e links de navegação', (tester) async {
      final fakeAuth = FakeAuthNotifier();

      await pumpApp(
        tester,
        child: const LoginPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      expect(find.text('Login'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Esqueci minha senha'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Criar conta'), findsOneWidget);
    });

    testWidgets(
      'exibe validações inline para campos vazios e inválidos sem chamar signIn',
      (tester) async {
        final fakeAuth = FakeAuthNotifier();

        await pumpApp(
          tester,
          child: const LoginPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
        await tester.pump();

        expect(find.text('Email obrigatório'), findsOneWidget);
        expect(find.text('Senha obrigatória'), findsOneWidget);
        expect(fakeAuth.signInCalls, isEmpty);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'email-invalido',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'),
          '123',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
        await tester.pump();

        expect(find.text('Email inválido'), findsOneWidget);
        expect(find.text('Mínimo de 6 caracteres'), findsOneWidget);
        expect(fakeAuth.signInCalls, isEmpty);
      },
    );

    testWidgets('submit válido chama signIn com email e senha informados', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier(
        onSignIn: (email, password) async => AppUser(
          id: 'u-1',
          email: email,
          emailConfirmedAt: DateTime(2026, 1, 1),
        ),
      );

      await pumpApp(
        tester,
        child: const LoginPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'atleta@olimpus.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettleBounded();

      expect(fakeAuth.signInCalls, [
        (email: 'atleta@olimpus.com', password: '123456'),
      ]);
    });

    testWidgets('estado loading desabilita botão e exibe indicador', (
      tester,
    ) async {
      final completer = Completer<AppUser?>();
      final fakeAuth = FakeAuthNotifier(onSignIn: (_, _) => completer.future);

      await pumpApp(
        tester,
        child: const LoginPage(),
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'atleta@olimpus.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);

      completer.complete(null);
      await tester.pump();
    });

    testWidgets(
      'exibe SnackBar com mensagem mapeada quando signIn retorna erro de credenciais',
      (tester) async {
        final fakeAuth = FakeAuthNotifier(
          onSignIn: (_, _) async =>
              throw const AuthException('Invalid login credentials'),
        );

        await pumpApp(
          tester,
          child: const LoginPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'atleta@olimpus.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'),
          '123456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Email ou senha incorretos.'), findsOneWidget);
      },
    );

    testWidgets(
      'exibe mensagem padrão no SnackBar para erro genérico ao fazer login',
      (tester) async {
        final fakeAuth = FakeAuthNotifier(
          onSignIn: (_, _) async => throw Exception('erro desconhecido'),
        );

        await pumpApp(
          tester,
          child: const LoginPage(),
          overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
        );
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'atleta@olimpus.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'),
          '123456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Ocorreu um erro ao fazer login. Tente novamente.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('link "Esqueci minha senha" navega para /forgot-password', (
      tester,
    ) async {
      final fakeAuth = FakeAuthNotifier();
      final router = buildTestRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
          GoRoute(
            path: '/forgot-password',
            builder: (_, _) => const Scaffold(body: Text('Tela Recuperar')),
          ),
        ],
      );

      await pumpApp(
        tester,
        router: router,
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Esqueci minha senha'));
      await tester.pumpAndSettleBounded();

      expect(find.text('Tela Recuperar'), findsOneWidget);
    });

    testWidgets('link "Criar conta" navega para /register', (tester) async {
      final fakeAuth = FakeAuthNotifier();
      final router = buildTestRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
          GoRoute(
            path: '/register',
            builder: (_, _) => const Scaffold(body: Text('Tela Cadastro')),
          ),
        ],
      );

      await pumpApp(
        tester,
        router: router,
        overrides: [authNotifierProvider.overrideWith(() => fakeAuth)],
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Criar conta'));
      await tester.pumpAndSettleBounded();

      expect(find.text('Tela Cadastro'), findsOneWidget);
    });
  });
}
