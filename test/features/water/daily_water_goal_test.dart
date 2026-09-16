import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/daily_water_total_card.dart';
import 'package:olimpus/features/water/presentation/widgets/edit_water_goal_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer({Map<String, Object> initialPrefs = const {}}) {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('DailyWaterGoalNotifier', () {
    test('inicia com valor padrão de 2000 ml se não houver persistência', () {
      final container = createContainer();
      final goal = container.read(dailyWaterGoalProvider);
      expect(goal, 2000);
    });

    test('lê meta persistida no SharedPreferences', () async {
      await prefs.setInt('daily_water_goal_ml', 2500);
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(dailyWaterGoalProvider), 2500);
    });

    test('setGoal atualiza o estado e persiste no SharedPreferences', () async {
      final container = createContainer();
      final notifier = container.read(dailyWaterGoalProvider.notifier);

      await notifier.setGoal(2750);
      expect(container.read(dailyWaterGoalProvider), 2750);
      expect(prefs.getInt('daily_water_goal_ml'), 2750);
    });
  });

  group('EditWaterGoalDialog Widget', () {
    testWidgets('renderiza com chips de presets e campo de texto com meta atual',
        (tester) async {
      await prefs.setInt('daily_water_goal_ml', 2000);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EditWaterGoalDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Meta Diária de Água'), findsOneWidget);
      expect(find.text('1500 ml'), findsOneWidget);
      expect(find.text('2000 ml'), findsOneWidget);
      expect(find.text('2500 ml'), findsOneWidget);
      expect(find.text('3000 ml'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '2000'), findsOneWidget);
    });

    testWidgets('tocar em preset chip atualiza campo e salvar persiste nova meta',
        (tester) async {
      await prefs.setInt('daily_water_goal_ml', 2000);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EditWaterGoalDialog(),
            ),
          ),
        ),
      );

      // Toca no preset de 2500 ml
      await tester.tap(find.text('2500 ml'));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, '2500'), findsOneWidget);

      // Toca em Salvar
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(prefs.getInt('daily_water_goal_ml'), 2500);
    });

    testWidgets('valida limites: rejeita valores abaixo de 500 ml',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EditWaterGoalDialog(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '300');
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(
        find.text('A meta mínima recomendada é 500 ml'),
        findsOneWidget,
      );
    });
  });

  group('DailyWaterTotalCard com onEditGoal', () {
    testWidgets('tocar no ícone de meta dispara callback onEditGoal',
        (tester) async {
      var edited = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyWaterTotalCard(
              totalMl: 1000,
              goalMl: 2000,
              onEditGoal: () {
                edited = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();

      expect(edited, isTrue);
    });
  });
}

