import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/progress/domain/entities/exercise_load_point.dart';
import 'package:olimpus/features/progress/domain/entities/monthly_workout_summary.dart';
import 'package:olimpus/features/progress/domain/entities/streak.dart';
import 'package:olimpus/features/progress/domain/entities/user_exercise_summary.dart';
import 'package:olimpus/features/progress/presentation/pages/progress_page.dart';
import 'package:olimpus/features/progress/presentation/providers/progress_providers.dart';
import 'package:olimpus/features/progress/presentation/widgets/exercise_load_chart.dart';
import 'package:olimpus/features/progress/presentation/widgets/exercise_selector.dart';

import '../../../../helpers/pump_app.dart';

MonthlyWorkoutSummary _emptyMonth() {
  final now = DateTime.now();
  return MonthlyWorkoutSummary(
    month: DateTime(now.year, now.month),
    trainedDays: const {},
    workoutCount: 0,
    totalVolumeKg: 0,
  );
}

void main() {
  const testUser = AppUser(
    id: 'user-test-123',
    email: 'atleta@olimpus.app',
    emailConfirmedAt: null,
  );

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('ProgressPage Widget Tests', () {
    testWidgets(
      'exibe estado vazio quando usuário não possui treinos registrados',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(testUser),
              monthlyWorkoutSummaryProvider.overrideWith(
                (ref) => Stream.value(_emptyMonth()),
              ),
              workoutStreakProvider.overrideWith(
                (ref) => Stream.value(const Streak(current: 0, best: 0)),
              ),
              waterStreakProvider.overrideWith(
                (ref) => Stream.value(const Streak(current: 0, best: 0)),
              ),
              userExercisesWithProgressProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              hasDemoDataProgressionProvider.overrideWith(
                (ref) => Stream.value(false),
              ),
            ],
            child: const MaterialApp(home: ProgressPage()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Evolução'), findsOneWidget);
        expect(find.text('Treine para ver sua evolução'), findsOneWidget);
        expect(
          find.textContaining(
            'Complete séries nos seus treinos para acompanhar aqui a curva',
          ),
          findsOneWidget,
        );
        expect(find.text('Gerar dados de demonstração'), findsOneWidget);
        expect(find.text('Ver Consumo de Água'), findsOneWidget);
      },
    );

    testWidgets(
      'exibe estado com dados, seletor de exercícios e gráfico de evolução',
      (tester) async {
        final exercises = [
          const UserExerciseSummary(
            exerciseId: 'ex-bench',
            name: 'Supino Reto com Barra',
          ),
          const UserExerciseSummary(
            exerciseId: 'ex-squat',
            name: 'Agachamento Livre',
          ),
        ];

        final points = [
          ExerciseLoadPoint(
            sessionId: 's-1',
            date: DateTime(2026, 9, 1, 10, 0),
            maxWeightKg: 60.0,
          ),
          ExerciseLoadPoint(
            sessionId: 's-2',
            date: DateTime(2026, 9, 5, 10, 0),
            maxWeightKg: 65.0,
          ),
          ExerciseLoadPoint(
            sessionId: 's-3',
            date: DateTime(2026, 9, 10, 10, 0),
            maxWeightKg: 70.0,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(testUser),
              monthlyWorkoutSummaryProvider.overrideWith(
                (ref) => Stream.value(_emptyMonth()),
              ),
              workoutStreakProvider.overrideWith(
                (ref) => Stream.value(const Streak(current: 0, best: 0)),
              ),
              waterStreakProvider.overrideWith(
                (ref) => Stream.value(const Streak(current: 0, best: 0)),
              ),
              userExercisesWithProgressProvider.overrideWith(
                (ref) => Stream.value(exercises),
              ),
              exerciseLoadProgressionProvider.overrideWith(
                (ref) => Stream.value(points),
              ),
              hasDemoDataProgressionProvider.overrideWith(
                (ref) => Stream.value(false),
              ),
            ],
            child: const MaterialApp(home: ProgressPage()),
          ),
        );

        await tester.pumpAndSettle();

        // Confere cabeçalho e widgets principais
        expect(find.text('Evolução'), findsOneWidget);
        expect(find.byType(ExerciseSelector), findsOneWidget);
        expect(find.byType(ExerciseLoadChart), findsOneWidget);

        // Confere valores e métricas
        expect(find.text('Supino Reto com Barra'), findsWidgets);
        expect(find.text('PR: 70 kg'), findsOneWidget);
        expect(find.text('70 kg'), findsWidgets); // Atual e lista
        expect(find.text('+10 kg'), findsOneWidget); // Progresso: 70 - 60 = +10
        expect(find.text('Histórico de Sessões'), findsOneWidget);
        expect(find.text('3 treinos'), findsOneWidget);
      },
    );

    testWidgets(
      'exibe mensagem orientativa quando exercício possui apenas 1 ponto',
      (tester) async {
        final exercises = [
          const UserExerciseSummary(
            exerciseId: 'ex-bench',
            name: 'Supino Reto com Barra',
          ),
        ];

        final singlePoint = [
          ExerciseLoadPoint(
            sessionId: 's-1',
            date: DateTime(2026, 9, 1, 10, 0),
            maxWeightKg: 50.0,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(testUser),
              monthlyWorkoutSummaryProvider.overrideWith(
                (ref) => Stream.value(_emptyMonth()),
              ),
              workoutStreakProvider.overrideWith(
                (ref) => Stream.value(const Streak(current: 0, best: 0)),
              ),
              waterStreakProvider.overrideWith(
                (ref) => Stream.value(const Streak(current: 0, best: 0)),
              ),
              userExercisesWithProgressProvider.overrideWith(
                (ref) => Stream.value(exercises),
              ),
              exerciseLoadProgressionProvider.overrideWith(
                (ref) => Stream.value(singlePoint),
              ),
              hasDemoDataProgressionProvider.overrideWith(
                (ref) => Stream.value(false),
              ),
            ],
            child: const MaterialApp(home: ProgressPage()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(ExerciseLoadChart), findsOneWidget);
        expect(
          find.textContaining(
            'São necessárias 2 ou mais sessões para exibir a curva de evolução',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('exibe AppErrorWidget em caso de falha no stream', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
            monthlyWorkoutSummaryProvider.overrideWith(
              (ref) => Stream.value(_emptyMonth()),
            ),
            workoutStreakProvider.overrideWith(
              (ref) => Stream.value(const Streak(current: 0, best: 0)),
            ),
            waterStreakProvider.overrideWith(
              (ref) => Stream.value(const Streak(current: 0, best: 0)),
            ),
            userExercisesWithProgressProvider.overrideWith(
              (ref) => Stream.error(Exception('Erro ao carregar histórico')),
            ),
            hasDemoDataProgressionProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
          child: const MaterialApp(home: ProgressPage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppErrorWidget), findsOneWidget);
    });
  });

  group('ProgressPage Estados Extras', () {
    const supino = UserExerciseSummary(
      exerciseId: 'ex-bench',
      name: 'Supino Reto com Barra',
    );
    const agachamento = UserExerciseSummary(
      exerciseId: 'ex-squat',
      name: 'Agachamento Livre',
    );

    final calendarAndStreakOverrides = [
      monthlyWorkoutSummaryProvider.overrideWith(
        (ref) => Stream.value(_emptyMonth()),
      ),
      workoutStreakProvider.overrideWith(
        (ref) => Stream.value(const Streak(current: 0, best: 0)),
      ),
      waterStreakProvider.overrideWith(
        (ref) => Stream.value(const Streak(current: 0, best: 0)),
      ),
    ];

    testWidgets('exibe indicador de carregamento enquanto carrega exercícios', (
      tester,
    ) async {
      final exercisesCtrl = StreamController<List<UserExerciseSummary>>();
      addTearDown(exercisesCtrl.close);

      await pumpApp(
        tester,
        child: const ProgressPage(),
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
          ...calendarAndStreakOverrides,
          userExercisesWithProgressProvider.overrideWith(
            (ref) => exercisesCtrl.stream,
          ),
          hasDemoDataProgressionProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
        ],
      );
      await tester.pump();

      expect(find.text('Evolução'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'exibe carregamento na área do gráfico enquanto progressão carrega',
      (tester) async {
        final progressionCtrl = StreamController<List<ExerciseLoadPoint>>();
        addTearDown(progressionCtrl.close);

        await pumpApp(
          tester,
          child: const ProgressPage(),
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
            ...calendarAndStreakOverrides,
            userExercisesWithProgressProvider.overrideWith(
              (ref) => Stream.value([supino]),
            ),
            exerciseLoadProgressionProvider.overrideWith(
              (ref) => progressionCtrl.stream,
            ),
            hasDemoDataProgressionProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
        );
        await tester.pump();

        expect(find.byType(ExerciseSelector), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'exibe estado vazio secundário quando exercício selecionado não tem séries com carga',
      (tester) async {
        await pumpApp(
          tester,
          child: const ProgressPage(),
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
            ...calendarAndStreakOverrides,
            userExercisesWithProgressProvider.overrideWith(
              (ref) => Stream.value([supino]),
            ),
            exerciseLoadProgressionProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            hasDemoDataProgressionProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        expect(find.byType(ExerciseSelector), findsOneWidget);
        expect(
          find.text('Nenhuma série concluída com carga para este exercício.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'exibe AppErrorWidget quando stream de progressão do exercício falha',
      (tester) async {
        await pumpApp(
          tester,
          child: const ProgressPage(),
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
            ...calendarAndStreakOverrides,
            userExercisesWithProgressProvider.overrideWith(
              (ref) => Stream.value([supino]),
            ),
            exerciseLoadProgressionProvider.overrideWith(
              (ref) => Stream.error(const NetworkException('Erro de rede.')),
            ),
            hasDemoDataProgressionProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        expect(find.byType(ExerciseSelector), findsOneWidget);
        expect(find.byType(AppErrorWidget), findsOneWidget);
        expect(find.text('Erro de rede.'), findsOneWidget);
        expect(find.text('Tentar novamente'), findsOneWidget);
      },
    );

    testWidgets(
      'selecionar outro exercício no ExerciseSelector atualiza estado',
      (tester) async {
        final points = [
          ExerciseLoadPoint(
            sessionId: 's-1',
            date: DateTime(2026, 9, 1, 10, 0),
            maxWeightKg: 60.0,
          ),
          ExerciseLoadPoint(
            sessionId: 's-2',
            date: DateTime(2026, 9, 5, 10, 0),
            maxWeightKg: 70.0,
          ),
        ];

        await pumpApp(
          tester,
          child: const ProgressPage(),
          overrides: [
            currentUserProvider.overrideWithValue(testUser),
            ...calendarAndStreakOverrides,
            userExercisesWithProgressProvider.overrideWith(
              (ref) => Stream.value([supino, agachamento]),
            ),
            exerciseLoadProgressionProvider.overrideWith(
              (ref) => Stream.value(points),
            ),
            hasDemoDataProgressionProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        await tester.ensureVisible(find.byType(ExerciseSelector));
        await tester.tap(find.byType(ExerciseSelector));
        await tester.pumpAndSettleBounded();
        await tester.tap(find.text('Agachamento Livre').last);
        await tester.pumpAndSettleBounded();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProgressPage)),
        );
        expect(container.read(selectedExerciseIdProvider), 'ex-squat');
      },
    );
  });
}
