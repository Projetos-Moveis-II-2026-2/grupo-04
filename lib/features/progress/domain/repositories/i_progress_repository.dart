import '../entities/monthly_workout_summary.dart';

/// Contrato da fonte de dados de progresso de treinos.
abstract interface class IProgressRepository {
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
