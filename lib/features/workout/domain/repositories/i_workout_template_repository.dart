import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';

abstract interface class IWorkoutTemplateRepository {
  /// Observa em tempo real as fichas do usuário [userId], com seus exercícios ordenados.
  Stream<List<WorkoutTemplateEntity>> watchTemplates(String userId);

  /// Busca uma ficha específica pelo [templateId] com seus exercícios ordenados.
  Future<WorkoutTemplateEntity?> getTemplateById(String templateId);

  /// Cria ou atualiza uma ficha de treino e seus exercícios ordenados (`sort_order`),
  /// persistindo localmente no Drift e enfileirando na `SyncQueueService`.
  Future<void> saveTemplate(WorkoutTemplateEntity template);

  /// Exclui a ficha [templateId] e seus exercícios vinculados localmente e no remoto.
  Future<void> deleteTemplate(String templateId);

  /// Observa o catálogo local de exercícios (`exercise_library`).
  Stream<List<CatalogExercise>> watchCatalogExercises();

  /// Garante que o catálogo local de exercícios está populado a partir do Supabase.
  Future<void> ensureCatalogSynced();
}
