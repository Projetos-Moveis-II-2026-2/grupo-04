import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/presentation/pages/home_page.dart';
import 'package:olimpus/features/auth/presentation/pages/login_page.dart';
import 'package:olimpus/features/auth/presentation/pages/settings_page.dart';
import 'package:olimpus/features/auth/presentation/pages/splash_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/progress/presentation/pages/progress_page.dart';
import 'package:olimpus/features/workout/presentation/pages/workout_list_page.dart';
import 'package:olimpus/router/app_router.dart';
import 'package:olimpus/router/scaffold_with_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

Widget createTestApp({
  required StreamController<AppUser?> authController,
  required MockAuthRepository mockAuthRepo,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(mockAuthRepo),
      authStateProvider.overrideWith((ref) => authController.stream),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          routerConfig: router,
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const authenticatedUser = AppUser(
    id: 'user-123',
    email: 'atleta@olimpus.com',
    emailConfirmedAt: null, // isEmailConfirmed é false
  );

  final confirmedUser = AppUser(
    id: 'user-456',
    email: 'confirmado@olimpus.com',
    emailConfirmedAt: DateTime.now(),
  );

  group('GoRouter redirect & navigation tests', () {
    late StreamController<AppUser?> authController;
    late MockAuthRepository mockAuthRepo;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      authController = StreamController<AppUser?>.broadcast();
      mockAuthRepo = MockAuthRepository();

      when(() => mockAuthRepo.authStateChanges())
          .thenAnswer((_) => authController.stream);
      when(() => mockAuthRepo.currentUser).thenReturn(null);
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await authController.close();
    });

    testWidgets('exibe SplashPage inicialmente enquanto auth está carregando',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      // Não emitiu nada ainda -> estado de loading no Splash
      expect(find.byType(SplashPage), findsOneWidget);
    });

    testWidgets('redireciona para LoginPage quando usuário não está autenticado',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      // Emite null (não autenticado)
      authController.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets(
        'redireciona para LoginPage se usuário tem email pendente de confirmação',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      // Emite usuário sem confirmação de email
      authController.add(authenticatedUser);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets(
        'redireciona para /home (HomePage dentro de ScaffoldWithNavBar) quando autenticado com email confirmado',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      authController.add(confirmedUser);
      await tester.pumpAndSettle();

      expect(find.byType(ScaffoldWithNavBar), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('confirmado@olimpus.com'), findsOneWidget);
    });

    testWidgets(
        'ScaffoldWithNavBar possui as 4 abas corretas (Início, Treinos, Exercícios, Progresso)',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      authController.add(confirmedUser);
      await tester.pumpAndSettle();

      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(
          find.descendant(of: navBar, matching: find.text('Início')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Treinos')),
          findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Exercícios')),
          findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Progresso')),
          findsOneWidget);
    });

    testWidgets('alterna entre as abas via BottomNavigationBar', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      authController.add(confirmedUser);
      await tester.pumpAndSettle();

      final navBar = find.byType(NavigationBar);

      // Inicialmente na aba Início
      expect(find.byType(HomePage), findsOneWidget);

      // Toca na aba Treinos
      await tester.tap(find.descendant(of: navBar, matching: find.text('Treinos')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutListPage), findsOneWidget);

      // Toca na aba Progresso
      await tester.tap(find.descendant(of: navBar, matching: find.text('Progresso')));
      await tester.pumpAndSettle();
      expect(find.byType(ProgressPage), findsOneWidget);

      // Volta para a aba Início
      await tester.tap(find.descendant(of: navBar, matching: find.text('Início')));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('navega para SettingsPage e abre sem o ScaffoldWithNavBar',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          authController: authController,
          mockAuthRepo: mockAuthRepo,
          prefs: prefs,
        ),
      );

      authController.add(confirmedUser);
      await tester.pumpAndSettle();

      // Toca no botão de configurações na AppBar da HomePage
      final settingsIcon = find.byIcon(Icons.settings_outlined);
      expect(settingsIcon, findsOneWidget);
      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      // Está na SettingsPage
      expect(find.byType(SettingsPage), findsOneWidget);
      // Barra inferior NÃO deve estar visível na tela de configurações
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
