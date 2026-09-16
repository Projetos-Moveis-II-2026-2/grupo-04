import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/domain/entities/daily_water_summary.dart';
import 'package:olimpus/features/water/domain/entities/water_intake_record.dart';
import 'package:olimpus/features/water/presentation/pages/water_history_page.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/daily_water_total_card.dart';
import 'package:olimpus/features/water/presentation/widgets/today_water_entries_list.dart';
import 'package:olimpus/features/water/presentation/widgets/weekly_water_chart.dart';

import 'package:olimpus/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('DailyWaterTotalCard Widget', () {
    testWidgets('exibe total consumido e texto "hoje"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyWaterTotalCard(
              totalMl: 1850,
              goalMl: 2000,
            ),
          ),
        ),
      );

      expect(find.textContaining('1.850 ml'), findsOneWidget);
      expect(find.text('hoje'), findsOneWidget);
      expect(find.textContaining('Meta diária: 2.000 ml'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('exibe "Meta atingida! 🎉" quando totalMl >= goalMl',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyWaterTotalCard(
              totalMl: 2200,
              goalMl: 2000,
            ),
          ),
        ),
      );

      expect(find.textContaining('2.200 ml'), findsOneWidget);
      expect(find.text('Meta atingida! 🎉'), findsOneWidget);
    });
  });

  group('TodayWaterEntriesList Widget', () {
    testWidgets('exibe estado vazio amigável quando lista está vazia',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodayWaterEntriesList(entries: []),
          ),
        ),
      );

      expect(find.text('Nenhum registro hoje'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('exibe itens com volume em ml e horário formatado',
        (tester) async {
      final entries = [
        WaterIntakeRecord(
          id: 'w-1',
          userId: 'u-1',
          amountMl: 250,
          recordedAt: DateTime(2026, 9, 16, 8, 30),
          date: '2026-09-16',
        ),
        WaterIntakeRecord(
          id: 'w-2',
          userId: 'u-1',
          amountMl: 500,
          recordedAt: DateTime(2026, 9, 16, 14, 15),
          date: '2026-09-16',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayWaterEntriesList(entries: entries),
          ),
        ),
      );

      expect(find.text('250 ml'), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('500 ml'), findsOneWidget);
      expect(find.text('14:15'), findsOneWidget);
      expect(find.text('2 registros'), findsOneWidget);
    });
  });

  group('WeeklyWaterChart Widget', () {
    testWidgets('renderiza com 7 resumos incluindo Hoje', (tester) async {
      final summaries = [
        DailyWaterSummary(
          date: DateTime(2026, 9, 10),
          totalMl: 1500,
          dayOfWeekAbbr: 'Qui',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 11),
          totalMl: 2000,
          dayOfWeekAbbr: 'Sex',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 12),
          totalMl: 1000,
          dayOfWeekAbbr: 'Sáb',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 13),
          totalMl: 500,
          dayOfWeekAbbr: 'Dom',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 14),
          totalMl: 1800,
          dayOfWeekAbbr: 'Seg',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 15),
          totalMl: 2200,
          dayOfWeekAbbr: 'Ter',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 16),
          totalMl: 1850,
          dayOfWeekAbbr: 'Qua',
          isToday: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyWaterChart(summaries: summaries),
            ),
          ),
        ),
      );

      expect(find.text('Últimos 7 dias'), findsOneWidget);
      expect(find.text('Hoje'), findsWidgets);
    });
  });

  group('WaterHistoryPage Full Integration', () {
    testWidgets('renderiza página completa com dados providos pelo Riverpod',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testUser = AppUser(
        id: 'u-123',
        email: 'atleta@olimpus.com',
        emailConfirmedAt: null,
      );

      final entries = [
        WaterIntakeRecord(
          id: 'w-1',
          userId: 'u-123',
          amountMl: 350,
          recordedAt: DateTime(2026, 9, 16, 9, 0),
          date: '2026-09-16',
        ),
        WaterIntakeRecord(
          id: 'w-2',
          userId: 'u-123',
          amountMl: 500,
          recordedAt: DateTime(2026, 9, 16, 13, 30),
          date: '2026-09-16',
        ),
      ];

      final summaries = [
        DailyWaterSummary(
          date: DateTime(2026, 9, 10),
          totalMl: 1000,
          dayOfWeekAbbr: 'Qui',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 11),
          totalMl: 1500,
          dayOfWeekAbbr: 'Sex',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 12),
          totalMl: 2000,
          dayOfWeekAbbr: 'Sáb',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 13),
          totalMl: 1200,
          dayOfWeekAbbr: 'Dom',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 14),
          totalMl: 1800,
          dayOfWeekAbbr: 'Seg',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 15),
          totalMl: 1600,
          dayOfWeekAbbr: 'Ter',
          isToday: false,
        ),
        DailyWaterSummary(
          date: DateTime(2026, 9, 16),
          totalMl: 850,
          dayOfWeekAbbr: 'Qua',
          isToday: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser),
            todayWaterTotalProvider.overrideWith(
              (ref) => Stream.value(850),
            ),
            todayWaterEntriesProvider.overrideWith(
              (ref) => Stream.value(entries),
            ),
            weeklyWaterSummaryProvider.overrideWith(
              (ref) => Stream.value(summaries),
            ),
          ],
          child: const MaterialApp(
            home: WaterHistoryPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confere cabeçalho
      expect(find.text('Hidratação'), findsOneWidget);

      // Confere Total Diário
      expect(find.textContaining('850 ml'), findsWidgets);
      expect(find.text('hoje'), findsOneWidget);

      // Confere botões de adição rápida
      expect(find.text('+250 ml'), findsOneWidget);
      expect(find.text('+500 ml'), findsOneWidget);

      // Confere Gráfico Semanal
      expect(find.text('Últimos 7 dias'), findsOneWidget);

      // Confere lista de registros de hoje
      expect(find.text('350 ml'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('500 ml'), findsOneWidget);
      expect(find.text('13:30'), findsOneWidget);
    });
  });
}

