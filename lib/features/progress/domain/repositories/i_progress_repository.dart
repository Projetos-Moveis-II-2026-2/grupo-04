import '../entities/monthly_workout_summary.dart';

/// Contrato da fonte de dados de progresso de treinos.
abstract interface class IProgressRepository {
  /// Observa o resumo dos treinos concluídos no [month] (fuso local)
  /// para o usuário informado.
  Stream<MonthlyWorkoutSummary> watchMonthlySummary(
    String userId,
    DateTime month,
  );
}
