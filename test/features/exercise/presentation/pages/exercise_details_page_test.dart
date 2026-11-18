import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/presentation/pages/exercise_details_page.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_motion_image.dart';

import '../../../../helpers/pump_app.dart';

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
        expect(find.text('CHEST'), findsOneWidget);
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
        expect(find.text('N/A'), findsOneWidget);
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
        imageUrls: 'assets/images/inexistente.jpg',
        synced: true,
        updatedAt: now,
      );

      await pumpApp(tester, child: ExerciseDetailsPage(exercise: comAsset));
      await tester.pumpAndSettleBounded();

      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
      expect(find.textContaining('assets/gifs'), findsNothing);
    });

    testWidgets(
      'anima alternância entre os dois quadros do exercício na tela de detalhe',
      (tester) async {
        final comDoisQuadros = Exercise(
          id: 'ex-4',
          externalId: 'dumbbell_flyes',
          name: 'Crucifixo com Halteres',
          imageUrls: 'assets/flyes/0.jpg, assets/flyes/1.jpg',
          synced: true,
          updatedAt: now,
        );

        await pumpApp(
          tester,
          child: ExerciseDetailsPage(exercise: comDoisQuadros),
        );
        await tester.pump();

        final motion = tester.widget<ExerciseMotionImage>(
          find.byType(ExerciseMotionImage),
        );
        expect(motion.animate, isTrue);
        expect(motion.frames, ['assets/flyes/0.jpg', 'assets/flyes/1.jpg']);

        AnimatedSwitcher switcher() =>
            tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));

        expect(
          switcher().child?.key,
          const ValueKey<String>('assets/flyes/0.jpg'),
        );

        await tester.pump(const Duration(milliseconds: 700));
        expect(
          switcher().child?.key,
          const ValueKey<String>('assets/flyes/1.jpg'),
        );

        await tester.pump(const Duration(milliseconds: 700));
        expect(
          switcher().child?.key,
          const ValueKey<String>('assets/flyes/0.jpg'),
        );
      },
    );
  });
}
