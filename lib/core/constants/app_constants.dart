/// Metas e limites padrão do app.
abstract final class AppConstants {
  /// Meta diária padrão de hidratação, em mililitros.
  static const int dailyWaterGoalMl = 2000;

  /// Limite mínimo da meta diária de hidratação, em mililitros.
  static const int minWaterGoalMl = 500;

  /// Limite máximo da meta diária de hidratação, em mililitros.
  static const int maxWaterGoalMl = 5000;

  /// Consumo de água recomendado por quilograma de peso corporal (ml/kg).
  static const int waterMlPerKg = 35;

  /// Presets recomendados de meta diária de hidratação, em mililitros.
  static const List<int> waterGoalPresets = [1500, 2000, 2500, 3000];

  /// Timeout padrão para chamadas de rede.
  static const Duration networkTimeout = Duration(seconds: 15);

  /// Revisão do conteúdo remoto do catálogo de exercícios (`exercise_library`).
  ///
  /// Incremente sempre que o conteúdo remoto mudar, para que clientes que já
  /// baixaram o catálogo voltem a sincronizá-lo. 2 = catálogo em pt-BR (#124).
  static const int exerciseCatalogRevision = 2;
}
