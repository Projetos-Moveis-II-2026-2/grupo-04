import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/constants/api_endpoints.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/presentation/pages/exercise_details_page.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_card.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_motion_image.dart';

const _catalog =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Flyes';
const _jsDelivrLegacy =
    'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/Dumbbell_Flyes';
const _optimized =
    '${ApiEndpoints.supabaseUrl}/storage/v1/object/public/exercise-media/v1/Dumbbell_Flyes';

Exercise _exercise(String? imageUrls) => Exercise(
  id: 'Dumbbell_Flyes',
  externalId: 'Dumbbell_Flyes',
  name: 'Crucifixo com Halteres',
  imageUrls: imageUrls,
  synced: true,
  updatedAt: DateTime(2026, 9, 16),
);

Iterable<String> _imageUrls(WidgetTester tester) => tester
    .widgetList<Image>(
      find.descendant(
        of: find.byType(ExerciseMotionImage),
        matching: find.byType(Image),
      ),
    )
    .map((image) => (image.image as NetworkImage).url);

void main() {
  final catalogExercise = _exercise('$_catalog/0.jpg,$_catalog/1.jpg');

  testWidgets(
    'seleciona o WebP animado nos detalhes (GitHub legado do Drift)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ExerciseDetailsPage(exercise: catalogExercise)),
      );
      expect(_imageUrls(tester), ['$_optimized/motion.webp']);
      final gallery = tester.widget<PageView>(find.byType(PageView));
      expect(gallery.childrenDelegate.estimatedChildCount, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('seleciona apenas a miniatura no card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseCard(exercise: catalogExercise)),
      ),
    );
    expect(_imageUrls(tester), ['$_optimized/thumbnail.webp']);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('seleciona a miniatura com redução de movimento', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ExerciseDetailsPage(exercise: catalogExercise),
        ),
      ),
    );
    expect(_imageUrls(tester), ['$_optimized/thumbnail.webp']);
    final gallery = tester.widget<PageView>(find.byType(PageView));
    expect(gallery.childrenDelegate.estimatedChildCount, 2);
  });

  testWidgets('preserva a imagem estática quando há um quadro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseDetailsPage(exercise: _exercise('$_catalog/0.jpg')),
      ),
    );
    expect(_imageUrls(tester), ['$_optimized/thumbnail.webp']);
  });

  testWidgets('usa o WebP do catálogo após a publicação no Storage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseDetailsPage(
          exercise: _exercise(
            '$_optimized/thumbnail.webp,$_optimized/motion.webp',
          ),
        ),
      ),
    );
    expect(_imageUrls(tester), ['$_optimized/motion.webp']);
    final gallery = tester.widget<PageView>(find.byType(PageView));
    expect(gallery.childrenDelegate.estimatedChildCount, 2);
  });

  testWidgets(
    'tenta o primeiro JPG do bucket quando o WebP está indisponível',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ExerciseDetailsPage(exercise: catalogExercise)),
      );
      // O cliente HTTP padrão do flutter_test rejeita requisições externas.
      await tester.pump();
      expect(_imageUrls(tester), contains('$_optimized/0.jpg'));
      await tester.pump();
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    },
  );

  testWidgets('a galeria mostra o segundo quadro do bucket sem duplicar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ExerciseDetailsPage(exercise: catalogExercise)),
    );
    final pager = find.byType(PageView);
    for (var page = 0; page < 2; page++) {
      await tester.drag(pager, const Offset(-600, 0));
      await tester.pump(const Duration(seconds: 1));
    }
    final gallery = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((image) => image.imageUrl);
    expect(gallery, ['$_optimized/1.jpg']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('normaliza a entrada relativa do dataset para o bucket', (
    tester,
  ) async {
    final relativeExercise = _exercise(
      'Dumbbell_Flyes/0.jpg,Dumbbell_Flyes/1.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(home: ExerciseDetailsPage(exercise: relativeExercise)),
    );
    expect(_imageUrls(tester), ['$_optimized/motion.webp']);
    final gallery = tester.widget<PageView>(find.byType(PageView));
    expect(gallery.childrenDelegate.estimatedChildCount, 3);
  });

  testWidgets('normaliza a entrada legada do jsDelivr para o bucket', (
    tester,
  ) async {
    final jsDelivrExercise = _exercise(
      '$_jsDelivrLegacy/0.jpg,$_jsDelivrLegacy/1.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseCard(exercise: jsDelivrExercise)),
      ),
    );
    expect(_imageUrls(tester), ['$_optimized/thumbnail.webp']);

    await tester.pumpWidget(
      MaterialApp(home: ExerciseDetailsPage(exercise: jsDelivrExercise)),
    );
    expect(_imageUrls(tester), ['$_optimized/motion.webp']);
  });
}
