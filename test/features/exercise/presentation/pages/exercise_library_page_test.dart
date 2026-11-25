import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/domain/repositories/i_exercise_repository.dart';
import 'package:olimpus/features/exercise/presentation/pages/exercise_library_page.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_card.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_library_skeleton.dart';

import '../../../../helpers/pump_app.dart';

class MockExerciseRepository extends Mock implements IExerciseRepository {}

void main() {
  late MockExerciseRepository mockRepo;

  final now = DateTime(2026, 1, 1);
  final supino = Exercise(
    id: 'ex-1',
    externalId: 'bench_press',
    name: 'Supino Reto',
    primaryMuscles: 'chest',
    secondaryMuscles: 'triceps',
    equipment: 'Barra',
    synced: true,
    updatedAt: now,
  );
  final agachamento = Exercise(
    id: 'ex-2',
    externalId: 'squat',
    name: 'Agachamento Livre',
    primaryMuscles: 'quadriceps',
    secondaryMuscles: 'glutes',
    equipment: 'Barra',
    synced: true,
    updatedAt: now,
  );
  final rosca = Exercise(
    id: 'ex-3',
    externalId: 'biceps_curl',
    name: 'Rosca Direta',
    primaryMuscles: 'biceps',
    equipment: 'Halteres',
    synced: true,
    updatedAt: now,
  );

  setUp(() {
    mockRepo = MockExerciseRepository();
    when(() => mockRepo.syncExercises()).thenAnswer((_) async {});
    when(() => mockRepo.watchExercises())
        .thenAnswer((_) => Stream.value(const []));
  });

  group('ExerciseLibraryPage Widget Tests', () {
    testWidgets('exibe indicador de carregamento no estado loading', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const ExerciseLibraryPage(),
        overrides: [
          exerciseRepositoryProvider.overrideWithValue(mockRepo),
          filteredExercisesProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      await tester.pump();

      expect(find.text('Biblioteca de Exercícios'), findsOneWidget);
      expect(find.byType(ExerciseLibrarySkeleton), findsOneWidget);
      expect(find.byType(ExerciseCardSkeleton), findsWidgets);
    });

    testWidgets(
      'renderiza lista com ExerciseCard e navega ao tocar no exercício',
      (tester) async {
        final router = buildTestRouter(
          initialLocation: '/exercises',
          routes: [
            GoRoute(
              path: '/exercises',
              builder: (_, _) => const ExerciseLibraryPage(),
            ),
            GoRoute(
              path: '/exercises/:id',
              builder: (_, state) {
                final extra = state.extra as Exercise?;
                return Scaffold(
                  body: Text(
                    'Detalhe ${state.pathParameters['id']}: ${extra?.name}',
                  ),
                );
              },
            ),
          ],
        );

        await pumpApp(
          tester,
          router: router,
          overrides: [
            exerciseRepositoryProvider.overrideWithValue(mockRepo),
            filteredExercisesProvider.overrideWithValue(
              AsyncData([supino, agachamento]),
            ),
          ],
        );
        await tester.pump();

        expect(find.byType(ExerciseCard), findsNWidgets(2));
        expect(find.text('Supino Reto'), findsOneWidget);
        expect(find.text('Agachamento Livre'), findsOneWidget);
        expect(find.text('Barra'), findsNWidgets(2));

        await tester.tap(find.text('Supino Reto'));
        await tester.pumpAndSettleBounded();

        expect(find.text('Detalhe ex-1: Supino Reto'), findsOneWidget);
      },
    );

    testWidgets('exibe estado vazio quando não há exercícios', (tester) async {
      await pumpApp(
        tester,
        child: const ExerciseLibraryPage(),
        overrides: [
          exerciseRepositoryProvider.overrideWithValue(mockRepo),
          filteredExercisesProvider.overrideWithValue(const AsyncData([])),
        ],
      );
      await tester.pump();

      expect(find.text('Nenhum exercício encontrado.'), findsOneWidget);
      expect(find.byType(ExerciseCard), findsNothing);
    });

    testWidgets(
      'exibe AppErrorWidget no estado erro e chama syncExercises ao tentar novamente',
      (tester) async {
        await pumpApp(
          tester,
          child: const ExerciseLibraryPage(),
          overrides: [
            exerciseRepositoryProvider.overrideWithValue(mockRepo),
            filteredExercisesProvider.overrideWithValue(
              const AsyncError(
                NetworkException('Sem conexão com a internet.'),
                StackTrace.empty,
              ),
            ),
          ],
        );
        await tester.pump();

        verify(() => mockRepo.syncExercises()).called(1);
        clearInteractions(mockRepo);

        expect(find.byType(AppErrorWidget), findsOneWidget);
        expect(find.text('Sem conexão com a internet.'), findsOneWidget);

        await tester.tap(find.text('Tentar novamente'));
        await tester.pump();

        verify(() => mockRepo.syncExercises()).called(1);
      },
    );

    testWidgets('busca atualiza searchQueryProvider após debounce e filtra', (
      tester,
    ) async {
      when(() => mockRepo.watchExercises())
          .thenAnswer((_) => Stream.value([supino, agachamento]));

      await pumpApp(
        tester,
        child: const ExerciseLibraryPage(),
        overrides: [exerciseRepositoryProvider.overrideWithValue(mockRepo)],
      );
      await tester.pump();

      expect(find.byType(ExerciseCard), findsNWidgets(2));

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar exercício...'),
        'Supino',
      );
      await tester.pump(const Duration(milliseconds: 350));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExerciseLibraryPage)),
      );
      expect(container.read(searchQueryProvider), 'Supino');
      expect(find.byType(ExerciseCard), findsOneWidget);
      expect(find.text('Supino Reto'), findsOneWidget);
      expect(find.text('Agachamento Livre'), findsNothing);
    });

    testWidgets('filtro de grupo muscular altera a lista exibida', (
      tester,
    ) async {
      when(() => mockRepo.watchExercises())
          .thenAnswer((_) => Stream.value([supino, agachamento, rosca]));

      await pumpApp(
        tester,
        child: const ExerciseLibraryPage(),
        overrides: [exerciseRepositoryProvider.overrideWithValue(mockRepo)],
      );
      await tester.pump();

      expect(find.byType(ExerciseCard), findsNWidgets(3));

      await tester.tap(find.widgetWithText(FilterChip, 'Peito'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExerciseLibraryPage)),
      );
      expect(container.read(selectedMuscleGroupProvider), 'Peito');
      expect(find.byType(ExerciseCard), findsOneWidget);
      expect(find.text('Supino Reto'), findsOneWidget);
      expect(find.text('Agachamento Livre'), findsNothing);
      expect(find.text('Rosca Direta'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Todos'));
      await tester.pump();

      expect(container.read(selectedMuscleGroupProvider), isNull);
      expect(find.byType(ExerciseCard), findsNWidgets(3));
    });
  });
}
