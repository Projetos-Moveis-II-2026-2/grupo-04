import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';

/// Volume de uma sessão: por exercício e total.
class SessionVolume {
  const SessionVolume({required this.byExercise, required this.total});

  /// Volume (kg) por `exerciseId`.
  final Map<String, double> byExercise;

  /// Volume total da sessão (kg).
  final double total;

  double of(String exerciseId) => byExercise[exerciseId] ?? 0;
}

/// Regra única de volume (Σ peso × reps das séries **concluídas**), usada na
/// tela de execução, no `total_volume_kg` gravado ao concluir e no treino
/// livre — para que tela, banco e histórico (Progresso) batam.
class ComputeVolume {
  const ComputeVolume();

  /// Volume de uma série; séries sem peso ou reps contam 0.
  static double setVolume(double? weightKg, int? reps) =>
      (weightKg ?? 0) * (reps ?? 0);

  /// Arredonda para 2 casas, como a coluna `DECIMAL(10,2)` do Supabase.
  static double round(double kg) => (kg * 100).roundToDouble() / 100;

  /// Volume das séries concluídas de [sets].
  double ofSets(Iterable<SessionSet> sets) => round(
    sets
        .where((s) => s.completed)
        .fold<double>(0, (sum, s) => sum + setVolume(s.weightKg, s.reps)),
  );

  SessionVolume call(Iterable<SessionExercise> exercises) {
    final byExercise = <String, double>{};
    var total = 0.0;
    for (final e in exercises) {
      final v = ofSets(e.sets);
      byExercise[e.exerciseId] = (byExercise[e.exerciseId] ?? 0) + v;
      total += v;
    }
    return SessionVolume(byExercise: byExercise, total: round(total));
  }
}
