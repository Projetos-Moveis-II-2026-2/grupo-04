import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';
import 'package:olimpus/features/workout/presentation/pages/template_form_page.dart';
import 'package:olimpus/features/workout/presentation/pages/templates_page.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';

class _FakeWorkoutTemplateRepository implements IWorkoutTemplateRepository {
  final List<WorkoutTemplateEntity> templates = <WorkoutTemplateEntity>[];

  @override
  Stream<List<WorkoutTemplateEntity>> watchTemplates(String userId) async* {
    yield List<WorkoutTemplateEntity>.from(templates);
  }

  @override
  Future<WorkoutTemplateEntity?> getTemplateById(String templateId) async {
    for (final t in templates) {
      if (t.id == templateId) return t;
    }
    return null;
  }

  @override
  Future<void> saveTemplate(WorkoutTemplateEntity template) async {
    final idx = templates.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      templates[idx] = template;
    } else {
      templates.add(template);
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    templates.removeWhere((t) => t.id == templateId);
  }

  @override
  Stream<List<CatalogExercise>> watchCatalogExercises() =>
      Stream.value(const <CatalogExercise>[]);

  @override
  Future<void> ensureCatalogSynced() async {}
}

void main() {
  testWidgets(
    'TemplatesListView exibe fichas e diálogo de confirmação ao excluir',
    (tester) async {
      final fakeRepo = _FakeWorkoutTemplateRepository();
      final sampleTemplate = WorkoutTemplateEntity(
        id: 'tpl-1',
        userId: 'u1',
        name: 'Treino A',
        description: 'Foco em Peito',
        exercises: const [
          TemplateExerciseItem(
            id: 'item-1',
            templateId: 'tpl-1',
            exerciseId: 'ex-1',
            exerciseName: 'Supino Reto',
            sortOrder: 0,
            targetSets: 4,
            targetReps: 10,
          ),
        ],
        synced: true,
        updatedAt: DateTime(2026, 9, 1),
      );
      fakeRepo.templates.add(sampleTemplate);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutTemplateRepositoryProvider.overrideWithValue(fakeRepo),
            userWorkoutTemplatesProvider.overrideWith(
              (ref) => fakeRepo.watchTemplates('u1'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TemplatesListView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Treino A'), findsOneWidget);
      expect(find.text('Foco em Peito'), findsOneWidget);
      expect(find.text('1 exercício'), findsOneWidget);
      expect(find.text('Supino Reto'), findsOneWidget);
      expect(find.text('4x10'), findsOneWidget);

      // Toca em excluir -> abre confirmação
      await tester.tap(find.byTooltip('Excluir ficha'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir ficha'), findsOneWidget);
      expect(find.textContaining('Tem certeza que deseja excluir'), findsOneWidget);

      // Cancela primeiro
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fakeRepo.templates, hasLength(1));

      // Abre novamente e confirma exclusão
      await tester.tap(find.byTooltip('Excluir ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(fakeRepo.templates, isEmpty);
    },
  );

  testWidgets('TemplateFormPage valida nome obrigatório e salva ficha', (
    tester,
  ) async {
    final fakeRepo = _FakeWorkoutTemplateRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutTemplateRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: TemplateFormPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Tenta salvar sem nome
    await tester.tap(find.text('Criar ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome da ficha'), findsOneWidget);
    expect(fakeRepo.templates, isEmpty);

    // Preenche nome e descrição e salva
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da ficha *'),
      'Treino B',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição (opcional)'),
      'Costas e Bíceps',
    );
    await tester.tap(find.text('Criar ficha'));
    await tester.pumpAndSettle();

    expect(fakeRepo.templates, hasLength(1));
    expect(fakeRepo.templates.single.name, 'Treino B');
    expect(fakeRepo.templates.single.description, 'Costas e Bíceps');
  });
}
