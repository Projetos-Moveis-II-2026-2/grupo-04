import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/presentation/pages/exercise_details_page.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';

import '../../../../helpers/pump_app.dart';

class _RecordingTemplateRepository implements IWorkoutTemplateRepository {
  final saved = <WorkoutTemplateEntity>[];

  @override
  Future<void> saveTemplate(WorkoutTemplateEntity template) async {
    saved.add(template);
  }

  @override
  Stream<List<WorkoutTemplateEntity>> watchTemplates(String userId) =>
      const Stream.empty();

  @override
  Future<WorkoutTemplateEntity?> getTemplateById(String templateId) async =>
      null;

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  Stream<List<CatalogExercise>> watchCatalogExercises() => const Stream.empty();

  @override
  Future<void> ensureCatalogSynced() async {}
}

void main() {
  final now = DateTime(2026, 1, 1);

  final supino = Exercise(
    id: 'ex-1',
    externalId: 'bench_press',
    name: 'Supino Reto',
    primaryMuscles: 'chest',
    equipment: 'Barra',
    instructions: 'Deite no banco e empurre a barra para cima.',
    synced: true,
    updatedAt: now,
  );

  group('ExerciseDetailsPage Widget Tests', () {
    testWidgets(
      'exibe nome, músculo alvo e instruções quando exercício é encontrado por id',
      (tester) async {
        await pumpApp(
          tester,
          child: const ExerciseDetailsPage.byId(exerciseId: 'ex-1'),
          overrides: [
            baseExercisesStreamProvider.overrideWith(
              (ref) => Stream.value([supino]),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        expect(find.text('Supino Reto'), findsOneWidget);
        expect(find.text('Músculo Alvo'), findsOneWidget);
        expect(find.text('Peito'), findsOneWidget);
        expect(find.text('Instruções'), findsOneWidget);
        expect(
          find.text('Deite no banco e empurre a barra para cima.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      },
    );

    testWidgets(
      'fromRouteState com extra exibe textos fallback quando detalhes opcionais são nulos',
      (tester) async {
        final minimo = Exercise(
          id: 'ex-2',
          externalId: 'minimo',
          name: 'Prancha',
          synced: true,
          updatedAt: now,
        );

        await pumpApp(
          tester,
          child: ExerciseDetailsPage.fromRouteState(id: 'ex-2', extra: minimo),
        );
        await tester.pump();

        expect(find.text('Prancha'), findsOneWidget);
        expect(find.text('—'), findsWidgets);
        expect(
          find.text('Nenhuma instrução disponível para este exercício.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('exibe estado de não encontrado quando id não existe', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const ExerciseDetailsPage.byId(exerciseId: 'nao-existe'),
        overrides: [
          baseExercisesStreamProvider.overrideWith(
            (ref) => Stream.value([supino]),
          ),
        ],
      );
      await tester.pumpAndSettleBounded();

      expect(find.text('Exercício'), findsOneWidget);
      expect(find.text('Exercício não encontrado.'), findsOneWidget);
    });

    testWidgets('exibe indicador de carregamento no estado loading', (
      tester,
    ) async {
      final controller = StreamController<List<Exercise>>();
      addTearDown(controller.close);

      await pumpApp(
        tester,
        child: const ExerciseDetailsPage.byId(exerciseId: 'ex-1'),
        overrides: [
          baseExercisesStreamProvider.overrideWith((ref) => controller.stream),
        ],
      );
      await tester.pump();

      expect(find.text('Exercício'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando stream falha', (tester) async {
      await pumpApp(
        tester,
        child: const ExerciseDetailsPage.byId(exerciseId: 'ex-1'),
        overrides: [
          baseExercisesStreamProvider.overrideWith(
            (ref) => Stream.error('falha ao consultar banco'),
          ),
        ],
      );
      await tester.pumpAndSettleBounded();

      expect(find.text('Exercício'), findsOneWidget);
      expect(
        find.text('Erro ao carregar exercício: falha ao consultar banco'),
        findsOneWidget,
      );
    });

    testWidgets('exibe fallback quando asset de imagem não é encontrado', (
      tester,
    ) async {
      final comAsset = Exercise(
        id: 'ex-3',
        externalId: 'asset_ex',
        name: 'Remada Curvada',
        imageUrls: 'assets/gifs/inexistente.gif',
        synced: true,
        updatedAt: now,
      );

      await pumpApp(tester, child: ExerciseDetailsPage(exercise: comAsset));
      await tester.pumpAndSettleBounded();

      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      expect(
        find.text('Substitua este arquivo vazio na pasta assets/gifs'),
        findsOneWidget,
      );
    });
    testWidgets(
      'exibe instruções numeradas e chips de músculos e equipamento',
      (tester) async {
        final remada = Exercise(
          id: 'ex-4',
          externalId: 'bent_over_row',
          name: 'Remada Curvada',
          primaryMuscles: 'middle back',
          secondaryMuscles: 'biceps, lats',
          equipment: 'barbell',
          level: 'intermediate',
          instructions:
              '• Segure a barra.\n• Incline o tronco.\n• Puxe até o abdômen.',
          synced: true,
          updatedAt: now,
        );

        await pumpApp(tester, child: ExerciseDetailsPage(exercise: remada));
        await tester.pump();

        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Segure a barra.'), findsOneWidget);
        expect(find.text('Puxe até o abdômen.'), findsOneWidget);
        expect(find.textContaining('•'), findsNothing);

        expect(find.widgetWithText(Chip, 'Costas (meio)'), findsOneWidget);
        expect(find.widgetWithText(Chip, 'Bíceps'), findsOneWidget);
        expect(find.widgetWithText(Chip, 'Dorsais'), findsOneWidget);
        expect(find.widgetWithText(Chip, 'Equipamento: Barra'), findsOneWidget);
        expect(
          find.widgetWithText(Chip, 'Nível: Intermediário'),
          findsOneWidget,
        );
      },
    );

    testWidgets('galeria mostra todas as imagens com indicador de página', (
      tester,
    ) async {
      final comDuasImagens = Exercise(
        id: 'ex-5',
        externalId: 'duas_imagens',
        name: 'Agachamento',
        imageUrls: 'assets/gifs/a.gif,assets/gifs/b.gif',
        synced: true,
        updatedAt: now,
      );

      await pumpApp(
        tester,
        child: ExerciseDetailsPage(exercise: comDuasImagens),
      );
      await tester.pumpAndSettleBounded();

      expect(find.byType(PageView), findsOneWidget);
      expect(
        find.byKey(const Key('exercise-gallery-indicator')),
        findsOneWidget,
      );

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.childrenDelegate.estimatedChildCount, 2);
    });

    testWidgets('usar no treino adiciona o exercício à ficha escolhida', (
      tester,
    ) async {
      final repo = _RecordingTemplateRepository();
      final ficha = WorkoutTemplateEntity(
        id: 'tpl-1',
        userId: 'u1',
        name: 'Treino A',
        exercises: const [
          TemplateExerciseItem(
            id: 'item-1',
            templateId: 'tpl-1',
            exerciseId: 'ex-9',
            exerciseName: 'Crucifixo',
            sortOrder: 0,
          ),
        ],
        updatedAt: now,
      );

      await pumpApp(
        tester,
        child: ExerciseDetailsPage(exercise: supino),
        overrides: [
          workoutTemplateRepositoryProvider.overrideWithValue(repo),
          userWorkoutTemplatesProvider.overrideWith(
            (ref) => Stream.value([ficha]),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Usar no treino'));
      await tester.pumpAndSettleBounded();
      expect(find.text('Adicionar à ficha'), findsOneWidget);

      await tester.tap(find.text('Treino A'));
      await tester.pumpAndSettleBounded();

      expect(repo.saved, hasLength(1));
      final saved = repo.saved.single;
      expect(saved.exercises, hasLength(2));
      expect(saved.exercises.last.exerciseId, 'ex-1');
      expect(saved.exercises.last.exerciseName, 'Supino Reto');
      expect(saved.exercises.last.sortOrder, 1);
      expect(find.text('Adicionado à ficha "Treino A".'), findsOneWidget);
    });

    testWidgets('usar no treino não duplica exercício já presente na ficha', (
      tester,
    ) async {
      final repo = _RecordingTemplateRepository();
      final ficha = WorkoutTemplateEntity(
        id: 'tpl-1',
        userId: 'u1',
        name: 'Treino A',
        exercises: const [
          TemplateExerciseItem(
            id: 'item-1',
            templateId: 'tpl-1',
            exerciseId: 'bench_press',
            exerciseName: 'Supino Reto',
            sortOrder: 0,
          ),
        ],
        updatedAt: now,
      );

      await pumpApp(
        tester,
        child: ExerciseDetailsPage(exercise: supino),
        overrides: [
          workoutTemplateRepositoryProvider.overrideWithValue(repo),
          userWorkoutTemplatesProvider.overrideWith(
            (ref) => Stream.value([ficha]),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Usar no treino'));
      await tester.pumpAndSettleBounded();
      await tester.tap(find.text('Treino A'));
      await tester.pumpAndSettleBounded();

      expect(repo.saved, isEmpty);
      expect(find.text('Já está na ficha "Treino A".'), findsOneWidget);
    });

    testWidgets('usar no treino sem fichas orienta a criar uma', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: ExerciseDetailsPage(exercise: supino),
        overrides: [
          userWorkoutTemplatesProvider.overrideWith(
            (ref) => Stream.value(const <WorkoutTemplateEntity>[]),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Usar no treino'));
      await tester.pumpAndSettleBounded();

      expect(find.textContaining('ainda não tem fichas'), findsOneWidget);
    });
  });
}
