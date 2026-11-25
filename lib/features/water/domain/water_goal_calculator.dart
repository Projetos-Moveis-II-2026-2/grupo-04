import 'package:olimpus/core/constants/app_constants.dart';

/// Utilitário de domínio para regras de cálculo e validação da meta diária de água.
abstract final class WaterGoalCalculator {
  /// Calcula a sugestão de meta diária de água (ml) com base no peso corporal (kg).
  ///
  /// Regra: peso * 35 ml/kg, arredondado para o inteiro mais próximo.
  /// O resultado é limitado ao intervalo entre [AppConstants.minWaterGoalMl] (500 ml)
  /// e [AppConstants.maxWaterGoalMl] (5000 ml).
  ///
  /// Retorna `null` se [weightKg] for nulo, menor ou igual a zero, ou não for um número finito.
  static int? calculateSuggestion(double? weightKg) {
    if (weightKg == null || !weightKg.isFinite || weightKg <= 0) {
      return null;
    }

    final rawSuggestion = (weightKg * AppConstants.waterMlPerKg).round();
    return rawSuggestion.clamp(
      AppConstants.minWaterGoalMl,
      AppConstants.maxWaterGoalMl,
    );
  }

  /// Verifica se a meta de água (ml) informada respeita o intervalo permitido de 500 a 5000 ml.
  static bool isValidGoal(int? goalMl) {
    if (goalMl == null) return false;
    return goalMl >= AppConstants.minWaterGoalMl &&
        goalMl <= AppConstants.maxWaterGoalMl;
  }
}
