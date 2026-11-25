import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/presentation/pages/exercise_details_page.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_card.dart';

void main() {
  Exercise buildExercise({
    String? primaryMuscles = 'chest, triceps',
    String? secondaryMuscles = 'shoulders',
    String? equipment = 'barbell',
    String? level = 'beginner',
    String? mechanic = 'compound',
    String? force = 'push',
    String? category = 'strength',
    String? instructions = '• Deite-se no banco\n• Empurre a barra',
  }) {
    return Exercise(
      id: 'Barbell_Bench_Press_-_Medium_Grip',
      externalId: 'Barbell_Bench_Press_-_Medium_Grip',
      name: 'Supino Reto com Barra - Pegada Média',
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
      level: level,
      mechanic: mechanic,
      force: force,
      category: category,
      instructions: instructions,
      synced: true,
      updatedAt: DateTime(2026, 9, 16),
    );
  }

  group('ExerciseCard', () {
    testWidgets('exibe músculos e equipamento traduzidos em pt-BR', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExerciseCard(exercise: buildExercise())),
        ),
      );

      expect(find.text('Supino Reto com Barra - Pegada Média'), findsOneWidget);
      expect(find.text('Peito, Tríceps'), findsOneWidget);
      expect(find.text('Barra'), findsOneWidget);

      expect(find.textContaining('chest'), findsNothing);
      expect(find.textContaining('barbell'), findsNothing);
      expect(find.text('N/A'), findsNothing);
    });

    testWidgets('exibe traço quando músculos e equipamento são nulos', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseCard(
              exercise: buildExercise(primaryMuscles: null, equipment: null),
            ),
          ),
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.text('N/A'), findsNothing);
    });
  });

  group('ExerciseDetailsPage', () {
    testWidgets('exibe todos os rótulos categóricos em pt-BR sem N/A', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ExerciseDetailsPage(exercise: buildExercise())),
      );

      expect(find.widgetWithText(Chip, 'Peito'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Tríceps'), findsOneWidget);
      expect(find.text('Ombros'), findsOneWidget);
      expect(find.text('Nível: Iniciante'), findsOneWidget);
      expect(find.text('Equipamento: Barra'), findsOneWidget);
      expect(find.text('Categoria: Força'), findsOneWidget);
      expect(find.text('Mecânica: Composto'), findsOneWidget);
      expect(find.text('Força: Empurrar'), findsOneWidget);
      expect(find.text('N/A'), findsNothing);
    });
  });
}
