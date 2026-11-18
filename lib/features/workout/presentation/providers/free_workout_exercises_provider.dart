import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';

/// Limite máximo de resultados retornados na busca do seletor de exercícios.
const int kExercisePickerMaxResults = 30;

/// Garante que o catálogo local possui exercícios antes da seleção no Treino
/// livre, verificando apenas 1 registro em vez de abrir um stream completo.
final workoutCatalogReadyProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  final existing = await repository.searchByName('', limit: 1);
  if (existing.isEmpty) {
    await repository.syncExercises();
  }
});

/// Busca opções leves (`id`, `name`) diretamente no banco local com limite de
/// resultados, descartando respostas obsoletas se a consulta for substituída.
final workoutExerciseSearchProvider = FutureProvider.autoDispose
    .family<List<ExerciseOption>, String>((ref, query) async {
      var cancelled = false;
      ref.onDispose(() => cancelled = true);

      final repository = ref.watch(exerciseRepositoryProvider);
      final results = await repository.searchByName(
        query,
        limit: kExercisePickerMaxResults,
      );
      if (cancelled) return const [];
      return results;
    });
