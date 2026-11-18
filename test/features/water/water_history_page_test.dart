import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/domain/entities/daily_water_summary.dart';
import 'package:olimpus/features/water/domain/entities/water_intake_record.dart';
import 'package:olimpus/features/water/domain/repositories/i_water_repository.dart';
import 'package:olimpus/features/water/presentation/pages/water_history_page.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/daily_water_total_card.dart';
import 'package:olimpus/features/water/presentation/widgets/today_water_entries_list.dart';
import 'package:olimpus/features/water/presentation/widgets/weekly_water_chart.dart';

import 'package:olimpus/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class _MockWaterRepository extends Mock implements IWaterRepository {}

class _MockSyncQueueService extends Mock implements SyncQueueService {}

class _FixedWaterGoalNotifier extends DailyWaterGoalNotifier {
  @override
  int build() => 2000;
}

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
            body: DailyWaterTotalCard(totalMl: 1850, goalMl: 2000),
          ),
        ),
      );

      expect(find.textContaining('1.850 ml'), findsOneWidget);
      expect(find.text('hoje'), findsOneWidget);
      expect(find.textContaining('Meta diária: 2.000 ml'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('exibe "Meta atingida! 🎉" quando totalMl >= goalMl', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyWaterTotalCard(totalMl: 2200, goalMl: 2000),
          ),
        ),
      );

      expect(find.textContaining('2.200 ml'), findsOneWidget);
      expect(find.text('Meta atingida! 🎉'), findsOneWidget);
    });
  });

  group('TodayWaterEntriesList Widget', () {
    testWidgets('exibe estado vazio amigável quando lista está vazia', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TodayWaterEntriesList(entries: [])),
        ),
      );

      expect(find.text('Nenhum registro hoje'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('exibe itens com volume em ml e horário formatado', (
      tester,
    ) async {
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
          home: Scaffold(body: TodayWaterEntriesList(entries: entries)),
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
    testWidgets('vibra apenas ao cruzar a meta a partir de um total menor', (
      tester,
    ) async {
      final totals = StreamController<int>();
      addTearDown(totals.close);
      final vibrations = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          vibrations.add(call.arguments);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(
              const AppUser(
                id: 'usuario-1',
                email: 'teste@example.com',
                emailConfirmedAt: null,
              ),
            ),
            todayWaterTotalProvider.overrideWith((ref) => totals.stream),
            todayWaterEntriesProvider.overrideWith((ref) => Stream.value([])),
            weeklyWaterSummaryProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: WaterHistoryPage()),
        ),
      );

      totals.add(2000);
      await tester.pumpAndSettle();
      expect(vibrations, isEmpty);

      for (final total in [1750, 2000, 2250]) {
        totals.add(total);
        await tester.pumpAndSettle();
      }
      expect(vibrations, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('renderiza página completa com dados providos pelo Riverpod', (
      tester,
    ) async {
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
            todayWaterTotalProvider.overrideWith((ref) => Stream.value(850)),
            todayWaterEntriesProvider.overrideWith(
              (ref) => Stream.value(entries),
            ),
            weeklyWaterSummaryProvider.overrideWith(
              (ref) => Stream.value(summaries),
            ),
          ],
          child: const MaterialApp(home: WaterHistoryPage()),
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

  group('WaterHistoryPage Estados Extras', () {
    const testUser = AppUser(
      id: 'u-extra',
      email: 'agua@olimpus.com',
      emailConfirmedAt: null,
    );

    testWidgets('exibe indicadores de carregamento no estado loading', (
      tester,
    ) async {
      final totalCtrl = StreamController<int>();
      final entriesCtrl = StreamController<List<WaterIntakeRecord>>();
      final weeklyCtrl = StreamController<List<DailyWaterSummary>>();
      addTearDown(() async {
        await totalCtrl.close();
        await entriesCtrl.close();
        await weeklyCtrl.close();
      });

      await pumpApp(
        tester,
        child: const WaterHistoryPage(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(testUser),
          dailyWaterGoalProvider.overrideWith(_FixedWaterGoalNotifier.new),
          todayWaterTotalProvider.overrideWith((ref) => totalCtrl.stream),
          todayWaterEntriesProvider.overrideWith((ref) => entriesCtrl.stream),
          weeklyWaterSummaryProvider.overrideWith((ref) => weeklyCtrl.stream),
        ],
      );
      await tester.pump();

      expect(find.text('Hidratação'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
    });

    testWidgets('exibe mensagens de erro quando streams falham', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const WaterHistoryPage(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(testUser),
          dailyWaterGoalProvider.overrideWith(_FixedWaterGoalNotifier.new),
          todayWaterTotalProvider.overrideWith(
            (ref) => Stream.error('falha total'),
          ),
          weeklyWaterSummaryProvider.overrideWith(
            (ref) => Stream.error('falha semanal'),
          ),
          todayWaterEntriesProvider.overrideWith(
            (ref) => Stream.error('falha registros'),
          ),
        ],
      );
      await tester.pumpAndSettleBounded();

      expect(find.text('Erro ao carregar total: falha total'), findsOneWidget);
      expect(
        find.text('Erro ao carregar gráfico semanal: falha semanal'),
        findsOneWidget,
      );
      expect(
        find.text('Erro ao carregar registros: falha registros'),
        findsOneWidget,
      );
    });

    testWidgets('exibe estado vazio quando não há registros de água no dia', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const WaterHistoryPage(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(testUser),
          dailyWaterGoalProvider.overrideWith(_FixedWaterGoalNotifier.new),
          todayWaterTotalProvider.overrideWith((ref) => Stream.value(0)),
          todayWaterEntriesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          weeklyWaterSummaryProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
      );
      await tester.pumpAndSettleBounded();

      expect(find.textContaining('0 ml'), findsWidgets);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Nenhum registro hoje'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets(
      'adição rápida +250 ml chama WaterRepository e exibe SnackBar',
      (tester) async {
        final mockRepo = _MockWaterRepository();
        final mockSyncQueue = _MockSyncQueueService();
        final entry = WaterIntakeRecord(
          id: 'w-10',
          userId: 'u-extra',
          amountMl: 250,
          recordedAt: DateTime(2026, 9, 16, 10, 0),
          date: '2026-09-16',
        );
        when(() => mockRepo.addWaterIntake(userId: 'u-extra', amountMl: 250))
            .thenAnswer((_) async => entry);
        when(() => mockSyncQueue.processQueue()).thenAnswer((_) async {});

        await pumpApp(
          tester,
          child: const WaterHistoryPage(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser),
            dailyWaterGoalProvider.overrideWith(_FixedWaterGoalNotifier.new),
            waterRepositoryProvider.overrideWithValue(mockRepo),
            syncQueueServiceProvider.overrideWithValue(mockSyncQueue),
            todayWaterTotalProvider.overrideWith((ref) => Stream.value(0)),
            todayWaterEntriesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            weeklyWaterSummaryProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        await tester.tap(find.text('+250 ml'));
        await tester.pumpAndSettleBounded();

        verify(() => mockRepo.addWaterIntake(userId: 'u-extra', amountMl: 250))
            .called(1);
        expect(find.text('+250 ml adicionados! 💧'), findsOneWidget);
      },
    );

    testWidgets(
      'remoção de registro chama deleteWaterIntake e exibe SnackBar',
      (tester) async {
        final mockRepo = _MockWaterRepository();
        final entry = WaterIntakeRecord(
          id: 'w-10',
          userId: 'u-extra',
          amountMl: 250,
          recordedAt: DateTime(2026, 9, 16, 10, 0),
          date: '2026-09-16',
        );
        when(() => mockRepo.deleteWaterIntake('w-10')).thenAnswer((_) async {});

        await pumpApp(
          tester,
          child: const WaterHistoryPage(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser),
            dailyWaterGoalProvider.overrideWith(_FixedWaterGoalNotifier.new),
            waterRepositoryProvider.overrideWithValue(mockRepo),
            todayWaterTotalProvider.overrideWith((ref) => Stream.value(250)),
            todayWaterEntriesProvider.overrideWith(
              (ref) => Stream.value([entry]),
            ),
            weeklyWaterSummaryProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        await tester.ensureVisible(find.byTooltip('Remover registro'));
        await tester.tap(find.byTooltip('Remover registro'));
        await tester.pumpAndSettleBounded();

        verify(() => mockRepo.deleteWaterIntake('w-10')).called(1);
        expect(find.text('Registro removido'), findsOneWidget);
      },
    );
  });
}
