import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/presentation/pages/onboarding_page.dart';
import 'package:olimpus/features/profile/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeOnboardingNotifier extends OnboardingNotifier {
  final Future<bool> Function({
    required String displayName,
    required double bodyWeightKg,
    required int dailyWaterGoalMl,
    required ExperienceLevel experienceLevel,
  })?
  onComplete;

  bool wasCalled = false;
  String? capturedDisplayName;
  double? capturedWeight;
  int? capturedWaterGoal;
  ExperienceLevel? capturedExperience;

  final AsyncValue<void> initialState;

  FakeOnboardingNotifier({
    this.onComplete,
    this.initialState = const AsyncData(null),
  });

  @override
  AsyncValue<void> build() => initialState;

  @override
  Future<bool> completeOnboarding({
    required String displayName,
    required double bodyWeightKg,
    required int dailyWaterGoalMl,
    required ExperienceLevel experienceLevel,
  }) async {
    wasCalled = true;
    capturedDisplayName = displayName;
    capturedWeight = bodyWeightKg;
    capturedWaterGoal = dailyWaterGoalMl;
    capturedExperience = experienceLevel;

    if (onComplete != null) {
      final res = await onComplete!(
        displayName: displayName,
        bodyWeightKg: bodyWeightKg,
        dailyWaterGoalMl: dailyWaterGoalMl,
        experienceLevel: experienceLevel,
      );
      if (!res) {
        state = const AsyncError(
          NetworkException('Falha na conexão com o servidor.'),
          StackTrace.empty,
        );
      }
      return res;
    }
    return true;
  }
}

void main() {
  late SharedPreferences prefs;

  final testUser = AppUser(
    id: 'user-123',
    email: 'user@olimpus.com',
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createWidget({FakeOnboardingNotifier? fakeNotifier}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(testUser),
        if (fakeNotifier != null)
          onboardingNotifierProvider.overrideWith(() => fakeNotifier),
      ],
      child: const MaterialApp(home: OnboardingPage()),
    );
  }

  group('OnboardingPage Widget Tests', () {
    testWidgets('exibe Passo 1 e valida campos obrigatórios (nome e peso)', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Passo 1 de 3'), findsOneWidget);
      expect(find.text('Bem-vindo ao Olimpus! 💪'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu nome'), findsOneWidget);
      expect(find.text('Informe seu peso'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Nome completo ou como prefere ser chamado *',
        ),
        'Matheus',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
        '0',
      );

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Informe um peso válido maior que 0 kg'),
        findsOneWidget,
      );
      expect(find.text('Passo 1 de 3'), findsOneWidget);
    });

    testWidgets(
      'avança para o Passo 2 ao validar Passo 1 e valida meta de água entre 500 e 5000 ml',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Nome completo ou como prefere ser chamado *',
          ),
          'Matheus',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '80.5',
        );

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Passo 2 de 3'), findsOneWidget);
        expect(find.text('Hidratação Diária'), findsOneWidget);

        final waterField = find.widgetWithText(
          TextFormField,
          'Meta diária personalizada *',
        );
        await tester.enterText(waterField, '300');

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(
          find.text('A meta de água deve estar entre 500 e 5000 ml'),
          findsOneWidget,
        );

        await tester.enterText(waterField, '6000');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(
          find.text('A meta de água deve estar entre 500 e 5000 ml'),
          findsOneWidget,
        );

        await tester.tap(find.text('2500 ml'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Passo 3 de 3'), findsOneWidget);
        expect(find.text('Nível de Experiência 🏋️'), findsOneWidget);
        expect(find.text('Concluir'), findsOneWidget);
      },
    );

    testWidgets('permite voltar entre os passos', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Nome completo ou como prefere ser chamado *',
        ),
        'Matheus',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
        '75',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Passo 2 de 3'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Passo 1 de 3'), findsOneWidget);
    });

    testWidgets('ao concluir com sucesso chama completeOnboarding', (
      tester,
    ) async {
      final fakeNotifier = FakeOnboardingNotifier();

      await tester.pumpWidget(createWidget(fakeNotifier: fakeNotifier));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Nome completo ou como prefere ser chamado *',
        ),
        'Carlos',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
        '85',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Intermediário'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.wasCalled, isTrue);
      expect(fakeNotifier.capturedDisplayName, 'Carlos');
      expect(fakeNotifier.capturedWeight, 85.0);
      expect(fakeNotifier.capturedWaterGoal, 2000);
      expect(fakeNotifier.capturedExperience, ExperienceLevel.intermediate);
    });

    testWidgets(
      'exibe SnackBar com erro caso completeOnboarding retorne false',
      (tester) async {
        final fakeNotifier = FakeOnboardingNotifier(
          onComplete:
              ({
                required String displayName,
                required double bodyWeightKg,
                required int dailyWaterGoalMl,
                required ExperienceLevel experienceLevel,
              }) async {
                return false;
              },
        );

        await tester.pumpWidget(createWidget(fakeNotifier: fakeNotifier));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Nome completo ou como prefere ser chamado *',
          ),
          'Carlos',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '85',
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Tentar novamente'), findsOneWidget);
      },
    );
  });
}
