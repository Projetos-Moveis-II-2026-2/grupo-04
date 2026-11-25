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
    equipment: 'barbell',
    level: 'beginner',
    synced: true,
    updatedAt: now,
  );
  final agachamento = Exercise(
    id: 'ex-2',
    externalId: 'squat',
    name: 'Agachamento Livre',
    primaryMuscles: 'quadriceps',
    secondaryMuscles: 'glutes',
    equipment: 'barbell',
    level: 'intermediate',
    synced: true,
    updatedAt: now,
  );
  final rosca = Exercise(
    id: 'ex-3',
    externalId: 'biceps_curl',
    name: 'Rosca Direta',
    primaryMuscles: 'biceps',
    equipment: 'dumbbell',
    level: 'beginner',
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

  group('ExerciseLibraryPage filtros de equipamento e nível', () {
    Future<ProviderContainer> pumpWithExercises(WidgetTester tester) async {
      when(() => mockRepo.watchExercises())
          .thenAnswer((_) => Stream.value([supino, agachamento, rosca]));

      await pumpApp(
        tester,
        child: const ExerciseLibraryPage(),
        overrides: [exerciseRepositoryProvider.overrideWithValue(mockRepo)],
      );
      await tester.pump();

      return ProviderScope.containerOf(
        tester.element(find.byType(ExerciseLibraryPage)),
      );
    }

    Future<void> pickFromMenu(
      WidgetTester tester,
      Key chipKey,
      String option,
    ) async {
      await tester.tap(find.byKey(chipKey));
      await tester.pumpAndSettleBounded();
      await tester.tap(find.widgetWithText(MenuItemButton, option));
      await tester.pumpAndSettleBounded();
    }

    String resultCountText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('exercise-result-count')))
        .data!;

    testWidgets('mostra o contador de resultados', (tester) async {
      await pumpWithExercises(tester);

      expect(resultCountText(tester), '3 exercícios');
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('filtra por equipamento pelo menu', (tester) async {
      final container = await pumpWithExercises(tester);

      await pickFromMenu(tester, const Key('equipment-filter'), 'Halter');

      expect(container.read(selectedEquipmentProvider), 'dumbbell');
      expect(find.byType(ExerciseCard), findsOneWidget);
      expect(find.text('Rosca Direta'), findsOneWidget);
      expect(resultCountText(tester), '1 exercício');
    });

    testWidgets('combina grupo muscular, equipamento e nível', (tester) async {
      final container = await pumpWithExercises(tester);

      await pickFromMenu(tester, const Key('level-filter'), 'Iniciante');
      expect(find.byType(ExerciseCard), findsNWidgets(2));

      await tester.tap(find.widgetWithText(FilterChip, 'Peito'));
      await pickFromMenu(tester, const Key('equipment-filter'), 'Barra');

      expect(container.read(activeExerciseFilterCountProvider), 3);
      expect(find.byType(ExerciseCard), findsOneWidget);
      expect(find.text('Supino Reto'), findsOneWidget);
      expect(resultCountText(tester), '1 exercício');
    });

    testWidgets('limpar filtros restaura a lista completa', (tester) async {
      final container = await pumpWithExercises(tester);

      // Agachamento (único de pernas) é intermediário: interseção vazia.
      await tester.tap(find.widgetWithText(FilterChip, 'Pernas'));
      await pickFromMenu(tester, const Key('level-filter'), 'Iniciante');

      expect(find.byType(ExerciseCard), findsNothing);
      expect(resultCountText(tester), '0 exercícios');
      expect(find.text('Nenhum exercício encontrado.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Limpar filtros').first);
      await tester.pumpAndSettleBounded();

      expect(container.read(selectedMuscleGroupProvider), isNull);
      expect(container.read(selectedLevelProvider), isNull);
      expect(container.read(selectedEquipmentProvider), isNull);
      expect(find.byType(ExerciseCard), findsNWidgets(3));
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('opção "Todos" do menu remove o filtro', (tester) async {
      final container = await pumpWithExercises(tester);

      await pickFromMenu(tester, const Key('level-filter'), 'Avançado');
      expect(container.read(selectedLevelProvider), 'expert');

      await pickFromMenu(tester, const Key('level-filter'), 'Todos os níveis');
      expect(container.read(selectedLevelProvider), isNull);
      expect(find.byType(ExerciseCard), findsNWidgets(3));
    });
  });
}
