import '../entities/exercise.dart';
import '../entities/exercise_option.dart';

abstract class IExerciseRepository {
  /// Stream que reage a atualizações no banco local de exercícios.
  Stream<List<Exercise>> watchExercises();

  /// Busca opções leves (`id` e `name`) filtradas por [query]
  /// (case-insensitive), ordenadas por nome (desempate por `id`), com
  /// paginação via [limit] e [offset].
  Future<List<ExerciseOption>> searchByName(
    String query, {
    int limit = 30,
    int offset = 0,
  });

  /// Sincroniza os exercícios com o servidor remoto (ou fake).
  Future<void> syncExercises();
}
