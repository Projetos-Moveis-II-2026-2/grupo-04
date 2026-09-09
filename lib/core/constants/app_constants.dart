/// Metas e limites padrão do app.
abstract final class AppConstants {
  /// Meta diária padrão de hidratação, em mililitros.
  static const int dailyWaterGoalMl = 2000;

  /// Timeout padrão para chamadas de rede.
  static const Duration networkTimeout = Duration(seconds: 15);
}
