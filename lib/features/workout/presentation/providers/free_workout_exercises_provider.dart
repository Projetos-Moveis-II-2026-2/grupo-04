import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';

/// Catálogo de exercícios consumido pelo Treino livre.
///
/// Na Fase 2 será substituído por busca paginada/filtrada diretamente no Drift.
final workoutExercisesProvider = StreamProvider.autoDispose<List<Exercise>>((
  ref,
) {
  final repository = ref.watch(exerciseRepositoryProvider);
  var loadedCatalog = false;
  return repository.watchExercises().asyncMap((exercises) async {
    if (!loadedCatalog && exercises.isEmpty) {
      loadedCatalog = true;
      await repository.syncExercises();
    }
    return exercises;
  });
});
