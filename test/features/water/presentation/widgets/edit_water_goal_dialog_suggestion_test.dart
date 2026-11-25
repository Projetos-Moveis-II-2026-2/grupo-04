import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/presentation/providers/profile_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/edit_water_goal_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createWidget({UserProfile? profile}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userProfileProvider.overrideWith((ref) => Future.value(profile)),
      ],
      child: const MaterialApp(home: Scaffold(body: EditWaterGoalDialog())),
    );
  }

  group('EditWaterGoalDialog - Sugestão e validação (#49)', () {
    testWidgets(
      'com peso no perfil (80 kg): exibe sugestão de 2800 ml e botão Aplicar atualiza o campo',
      (tester) async {
        const profile = UserProfile(
          id: 'user-80',
          displayName: 'João',
          bodyWeightKg: 80.0,
          dailyWaterGoalMl: 2000,
        );

        await tester.pumpWidget(createWidget(profile: profile));
        await tester.pumpAndSettle();

        // Verifica título e presença da sugestão
        expect(find.text('Meta Diária de Água'), findsOneWidget);
        expect(find.text('Sugestão para 80 kg: 2800 ml'), findsOneWidget);
        expect(find.text('Aplicar'), findsOneWidget);

        // O campo inicialmente está com 2000
        expect(find.widgetWithText(TextFormField, '2000'), findsOneWidget);

        // Toca no botão Aplicar da sugestão
        await tester.tap(find.text('Aplicar'));
        await tester.pump();

        // O campo agora deve exibir 2800
        expect(find.widgetWithText(TextFormField, '2800'), findsOneWidget);

        // Salva e verifica que persiste
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        expect(prefs.getInt('daily_water_goal_ml'), 2800);
      },
    );

    testWidgets(
      'com peso fracionário (75.5 kg): exibe sugestão arredondada corretamente',
      (tester) async {
        // 75.5 kg * 35 = 2642.5 -> arredondado para 2643 ml
        const profile = UserProfile(
          id: 'user-75',
          displayName: 'Maria',
          bodyWeightKg: 75.5,
          dailyWaterGoalMl: 2000,
        );

        await tester.pumpWidget(createWidget(profile: profile));
        await tester.pumpAndSettle();

        expect(find.text('Sugestão para 75.5 kg: 2643 ml'), findsOneWidget);

        await tester.tap(find.text('Aplicar'));
        await tester.pump();

        expect(find.widgetWithText(TextFormField, '2643'), findsOneWidget);
      },
    );

    testWidgets(
      'sem peso no perfil (null): não exibe sugestão e funciona normalmente',
      (tester) async {
        const profile = UserProfile(
          id: 'user-sem-peso',
          displayName: 'Sem Peso',
          bodyWeightKg: null,
          dailyWaterGoalMl: 2000,
        );

        await tester.pumpWidget(createWidget(profile: profile));
        await tester.pumpAndSettle();

        // Não deve exibir container de sugestão
        expect(find.textContaining('Sugestão para'), findsNothing);
        expect(find.text('Aplicar'), findsNothing);

        // Mas os presets e o campo continuam funcionando
        expect(find.text('2500 ml'), findsOneWidget);
        await tester.tap(find.text('2500 ml'));
        await tester.pump();

        expect(find.widgetWithText(TextFormField, '2500'), findsOneWidget);
      },
    );

    testWidgets(
      'validação de limites 500..5000 ml: recusa valor menor que 500 e maior que 5000',
      (tester) async {
        await tester.pumpWidget(createWidget(profile: null));
        await tester.pumpAndSettle();

        final textField = find.byType(TextFormField);

        // Teste menor que 500 (ex: 450)
        await tester.enterText(textField, '450');
        await tester.tap(find.text('Salvar'));
        await tester.pump();

        expect(find.text('A meta mínima recomendada é 500 ml'), findsOneWidget);

        // Teste maior que 5000 (ex: 5500)
        await tester.enterText(textField, '5500');
        await tester.tap(find.text('Salvar'));
        await tester.pump();

        expect(find.text('A meta máxima permitida é 5000 ml'), findsOneWidget);

        // Teste valor válido dentro do limite (ex: 3500)
        await tester.enterText(textField, '3500');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        expect(prefs.getInt('daily_water_goal_ml'), 3500);
      },
    );
  });
}
