import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/providers/action_feedback_provider.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/domain/repositories/i_exercise_repository.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';
import 'package:olimpus/features/workout/presentation/pages/free_workout_page.dart';

import '../../../../helpers/pump_app.dart';

class FakeActionFeedback extends ActionFeedback {
  final List<bool> playCalls = [];

  @override
  ActionFeedbackSettings build() => (vibration: true, sound: false);

  @override
  Future<void> play({bool lightImpact = false}) async {
    playCalls.add(lightImpact);
  }
}

class MockExerciseRepository extends Mock implements IExerciseRepository {}

AppDatabase _createInMemoryDb() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

void main() {
  const testUser = AppUser(
    id: 'user-1',
    email: 'atleta@olimpus.com',
    emailConfirmedAt: null,
  );

  group('FreeWorkoutPage Widget Tests', () {
    testWidgets('sem usuário exibe apenas AppBar sem corpo do treino', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const FreeWorkoutPage(),
        overrides: [currentUserProvider.overrideWithValue(null)],
      );
      await tester.pump();

      expect(find.text('Treino livre'), findsOneWidget);
      expect(find.textContaining('Séries concluídas'), findsNothing);
      expect(find.byType(DropdownMenu<Exercise>), findsNothing);
      expect(find.text('Iniciar timer'), findsNothing);
    });

    testWidgets('exibe estado de loading enquanto carrega exercícios', (
      tester,
    ) async {
      final db = _createInMemoryDb();
      addTearDown(db.close);
      final mockRepo = MockExerciseRepository();
      final controller = StreamController<List<Exercise>>();
      addTearDown(controller.close);
      when(() => mockRepo.watchExercises())
          .thenAnswer((_) => controller.stream);
      when(() => mockRepo.syncExercises()).thenAnswer((_) async {});

      await pumpApp(
        tester,
        child: const FreeWorkoutPage(),
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(testUser),
          exerciseRepositoryProvider.overrideWithValue(mockRepo),
          actionFeedbackProvider.overrideWith(FakeActionFeedback.new),
        ],
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe estado vazio quando não há exercícios cadastrados', (
      tester,
    ) async {
      final db = _createInMemoryDb();
      addTearDown(db.close);
      final mockRepo = MockExerciseRepository();
      when(() => mockRepo.watchExercises())
          .thenAnswer((_) => Stream.value(const []));
      when(() => mockRepo.syncExercises()).thenAnswer((_) async {});

      await pumpApp(
        tester,
        child: const FreeWorkoutPage(),
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(testUser),
          exerciseRepositoryProvider.overrideWithValue(mockRepo),
          actionFeedbackProvider.overrideWith(FakeActionFeedback.new),
        ],
      );
      await tester.pumpAndSettleBounded();

      verify(() => mockRepo.syncExercises()).called(1);
      expect(find.text('Séries concluídas neste treino: 0'), findsOneWidget);
      expect(find.text('Nenhum exercício disponível.'), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando stream de exercícios falha', (
      tester,
    ) async {
      final db = _createInMemoryDb();
      addTearDown(db.close);
      final mockRepo = MockExerciseRepository();
      when(() => mockRepo.watchExercises())
          .thenAnswer((_) => Stream.error(Exception('erro de leitura')));

      await pumpApp(
        tester,
        child: const FreeWorkoutPage(),
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(testUser),
          exerciseRepositoryProvider.overrideWithValue(mockRepo),
          actionFeedbackProvider.overrideWith(FakeActionFeedback.new),
        ],
      );
      await tester.pumpAndSettleBounded();

      expect(find.text('Erro ao carregar exercícios.'), findsOneWidget);
    });

    testWidgets(
      'renderiza lista de exercícios, valida campos, registra série e aciona feedback tátil',
      (tester) async {
        final db = _createInMemoryDb();
        addTearDown(db.close);
        await db
            .into(db.exerciseLibraryTable)
            .insert(
              ExerciseLibraryTableCompanion.insert(
                id: 'ex-supino',
                externalId: 'supino',
                name: 'Supino Reto',
                updatedAt: DateTime(2026, 1, 1),
              ),
            );
        await db
            .into(db.exerciseLibraryTable)
            .insert(
              ExerciseLibraryTableCompanion.insert(
                id: 'ex-agachamento',
                externalId: 'agachamento',
                name: 'Agachamento',
                updatedAt: DateTime(2026, 1, 1),
              ),
            );

        final fakeFeedback = FakeActionFeedback();

        await pumpApp(
          tester,
          child: const FreeWorkoutPage(),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserProvider.overrideWithValue(testUser),
            actionFeedbackProvider.overrideWith(() => fakeFeedback),
          ],
        );
        await tester.pumpAndSettleBounded();

        expect(find.text('Séries concluídas neste treino: 0'), findsOneWidget);
        expect(find.byType(DropdownMenu<Exercise>), findsOneWidget);

        // Validação sem exercício e campos inválidos
        await tester.tap(find.text('Concluir série'));
        await tester.pump();
        expect(find.text('Selecione um exercício.'), findsOneWidget);
        expect(find.text('Informe uma carga válida.'), findsOneWidget);
        expect(
          find.text('Informe um número de repetições maior que zero.'),
          findsOneWidget,
        );
        expect(fakeFeedback.playCalls, isEmpty);

        // Abre dropdown e seleciona Supino Reto
        await tester.tap(find.byType(DropdownMenu<Exercise>));
        await tester.pumpAndSettleBounded();
        expect(find.text('Supino Reto'), findsWidgets);
        expect(find.text('Agachamento'), findsWidgets);
        await tester.tap(find.text('Supino Reto').last);
        await tester.pumpAndSettleBounded();

        // Preenche carga e repetições válidas
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Carga (kg)'),
          '60,5',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Repetições'),
          '12',
        );
        await tester.tap(find.text('Concluir série'));
        await tester.pumpAndSettleBounded();

        expect(find.text('Séries concluídas neste treino: 1'), findsOneWidget);
        expect(find.text('Série concluída'), findsOneWidget);
        expect(fakeFeedback.playCalls, [false]);
        expect(find.text('Concluir treino'), findsOneWidget);

        // Timer de descanso aciona feedback leve
        await tester.ensureVisible(find.text('Iniciar timer'));
        await tester.tap(find.text('Iniciar timer'));
        await tester.pump();
        expect(find.text('Parar timer'), findsOneWidget);
        expect(fakeFeedback.playCalls, [false, true]);

        await tester.tap(find.text('Parar timer'));
        await tester.pump();
        expect(find.text('Iniciar timer'), findsOneWidget);

        // Conclui o treino
        await tester.ensureVisible(find.text('Concluir treino'));
        await tester.tap(find.text('Concluir treino'));
        await tester.pumpAndSettleBounded();
        expect(find.text('Treino concluído'), findsOneWidget);
        expect(find.text('Séries concluídas neste treino: 0'), findsOneWidget);
      },
    );
  });
}
