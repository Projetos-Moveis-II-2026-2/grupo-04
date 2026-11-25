// ignore_for_file: riverpod_lint/avoid_public_notifier_properties

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/presentation/pages/onboarding_page.dart';
import 'package:olimpus/features/profile/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOnboardingNotifier extends OnboardingNotifier {
  bool wasCalled = false;
  int? capturedWaterGoal;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<bool> completeOnboarding({
    required String displayName,
    required double bodyWeightKg,
    required int dailyWaterGoalMl,
    required ExperienceLevel experienceLevel,
  }) async {
    wasCalled = true;
    capturedWaterGoal = dailyWaterGoalMl;
    return true;
  }
}

void main() {
  late SharedPreferences prefs;

  final testUser = AppUser(
    id: 'user-49',
    email: 'user49@olimpus.com',
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createWidget({_FakeOnboardingNotifier? fakeNotifier}) {
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

  group('OnboardingPage - Sugestão automática de meta de água (#49)', () {
    testWidgets(
      'preenche a sugestão automaticamente no campo de água ao informar peso (80 kg -> 2800 ml)',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Passo 1: Informa nome e peso de 80 kg
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Nome completo ou como prefere ser chamado *',
          ),
          'Atleta Olimpus',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '80',
        );

        // Avança para o Passo 2
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Passo 2 de 3'), findsOneWidget);
        expect(find.text('Sugestão para 80 kg: 2800 ml'), findsOneWidget);

        // Campo de meta deve estar preenchido com a sugestão (2800)
        final waterField = find.widgetWithText(
          TextFormField,
          'Meta diária personalizada *',
        );
        expect(
          find.descendant(of: waterField, matching: find.text('2800')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'depois de um ajuste manual, mudar o peso não sobrescreve a meta, e ação Aceitar atualiza o campo',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Passo 1: Digita peso 80 kg
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Nome completo ou como prefere ser chamado *',
          ),
          'Atleta Olimpus',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '80',
        );

        // Avança para o Passo 2
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Sugestão para 80 kg: 2800 ml'), findsOneWidget);

        // Usuário faz ajuste manual selecionando um preset de 2500 ml
        await tester.tap(find.text('2500 ml'));
        await tester.pumpAndSettle();

        final waterField = find.widgetWithText(
          TextFormField,
          'Meta diária personalizada *',
        );
        expect(
          find.descendant(of: waterField, matching: find.text('2500')),
          findsOneWidget,
        );

        // Usuário volta para o Passo 1
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();

        // Altera o peso para 90 kg (sugestão seria 3150 ml)
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '90',
        );

        // Avança novamente para o Passo 2
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // O valor manual (2500) NÃO deve ter sido sobrescrito!
        expect(
          find.descendant(of: waterField, matching: find.text('2500')),
          findsOneWidget,
        );

        // Mas a nova sugestão para 90 kg está visível
        expect(find.text('Sugestão para 90 kg: 3150 ml'), findsOneWidget);

        // Toca na ação para aceitar a nova sugestão
        await tester.tap(find.text('Aceitar'));
        await tester.pumpAndSettle();

        // Agora o campo deve conter a nova sugestão aceita (3150)
        expect(
          find.descendant(of: waterField, matching: find.text('3150')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ajuste manual digitado no campo também é preservado ao alterar peso',
      (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Nome completo ou como prefere ser chamado *',
          ),
          'Atleta Olimpus',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '80',
        );

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Digita manualmente 3200
        final waterField = find.widgetWithText(
          TextFormField,
          'Meta diária personalizada *',
        );
        await tester.enterText(waterField, '3200');
        await tester.pumpAndSettle();

        // Volta para o Passo 1 e altera peso para 70
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Peso corporal (kg) *'),
          '70',
        );

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Preserva os 3200 digitados manualmente
        expect(
          find.descendant(of: waterField, matching: find.text('3200')),
          findsOneWidget,
        );
        expect(find.text('Sugestão para 70 kg: 2450 ml'), findsOneWidget);
      },
    );
  });
}
