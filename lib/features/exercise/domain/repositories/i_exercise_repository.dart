import '../entities/exercise.dart';
import '../entities/exercise_option.dart';

abstract class IExerciseRepository {
  /// Stream que reage a atualizações no banco local de exercícios.
  Stream<List<Exercise>> watchExercises();

  /// Busca opções leves (`id` e `name`) filtradas por [query]
  /// (case-insensitive) e limitadas a [limit] resultados ordenados por nome.
  Future<List<ExerciseOption>> searchByName(String query, {int limit = 30});

  /// Sincroniza os exercícios com o servidor remoto (ou fake).
  Future<void> syncExercises();
}
