import '../entities/exercise.dart';

abstract class IExerciseRepository {
  /// Stream que reage a atualizações no banco local de exercícios.
  Stream<List<Exercise>> watchExercises();

  /// Sincroniza os exercícios com o servidor remoto (ou fake).
  Future<void> syncExercises();
}
