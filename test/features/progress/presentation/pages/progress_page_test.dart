import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
}
