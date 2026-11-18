import '../entities/exercise_load_point.dart';
import '../entities/monthly_workout_summary.dart';
import '../entities/user_exercise_summary.dart';

/// Contrato para o repositório de progresso e evolução de cargas.
abstract interface class IProgressRepository {
  /// Observa a lista de exercícios que possuem séries registradas pelo usuário.
  /// Mapeia o ID do exercício para seu nome na biblioteca local (exercise_library).
  Stream<List<UserExerciseSummary>> watchUserExercisesWithLogs(String userId);

  /// Observa a série temporal de carga máxima por sessão de um exercício específico,
  /// ordenada cronologicamente por `WorkoutSession.startedAt`.
  ///
  /// Considera exclusivamente séries marcadas como `ExerciseSet.completed` == true
  /// e com `ExerciseSet.weightKg` preenchido (> 0).
  Stream<List<ExerciseLoadPoint>> watchExerciseLoadProgression({
    required String userId,
    required String exerciseId,
  });

  /// Insere dados fictícios de treino para demonstração rápida (somente em modo debug).
  ///
  /// Insere com synced = false sem enfileirar na SyncQueue para não poluir o Supabase.
  Future<void> seedDemoData(String userId);

  /// Limpa todos os dados de treino marcados como demonstração (notes = 'seed-demo') do usuário.
  Future<void> clearDemoData(String userId);

  /// Observa se o usuário possui dados de demonstração salvos localmente.
  Stream<bool> watchHasDemoData(String userId);

  /// Observa o resumo dos treinos concluídos no [month] (fuso local)
  /// para o usuário informado.
  Stream<MonthlyWorkoutSummary> watchMonthlySummary(
    String userId,
    DateTime month,
  );

  /// Observa os dias com pelo menos um treino concluído pelo [userId].
  ///
  /// Cada data é normalizada para 00:00 no fuso local e o stream reage a
  /// novas sessões ou alterações de conclusão.
  Stream<Set<DateTime>> watchTrainedDays(String userId);

  /// Observa os dias em que a soma de água consumida pelo [userId] atingiu
  /// [dailyGoalMl].
  ///
  /// O agrupamento usa a coluna `date` (`yyyy-MM-dd`) de `water_intake`,
  /// normalizando cada dia para 00:00 no fuso local.
  Stream<Set<DateTime>> watchWaterGoalDays(String userId, int dailyGoalMl);
}
