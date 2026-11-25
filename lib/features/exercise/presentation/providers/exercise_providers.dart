import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/i_exercise_repository.dart';
import '../../data/datasources/exercise_local_datasource.dart';
import '../../data/datasources/exercise_remote_datasource_fake.dart';
import '../../data/repositories/exercise_repository_impl.dart';
import '../utils/exercise_labels.dart';

export '../utils/exercise_labels.dart' show muscleGroupTranslation;

// Repositório
final exerciseRepositoryProvider = Provider<IExerciseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final localDS = ExerciseLocalDataSource(db);
  final remoteDSFake = ExerciseRemoteDataSourceFake();
  return ExerciseRepositoryImpl(localDS, remoteDSFake);
});

// Filtros
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) {
    state = query;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Seleção opcional de um valor de filtro (`null` = sem filtro).
class ExerciseFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void update(String? value) {
    state = value;
  }
}

/// Grupo muscular selecionado (chave de [muscleGroupTranslation], ex.: 'Peito').
final selectedMuscleGroupProvider =
    NotifierProvider<ExerciseFilterNotifier, String?>(
      ExerciseFilterNotifier.new,
    );

/// Equipamento selecionado (chave em inglês do dataset, ex.: 'dumbbell').
final selectedEquipmentProvider =
    NotifierProvider<ExerciseFilterNotifier, String?>(
      ExerciseFilterNotifier.new,
    );

/// Nível selecionado (chave em inglês do dataset, ex.: 'beginner').
final selectedLevelProvider = NotifierProvider<ExerciseFilterNotifier, String?>(
  ExerciseFilterNotifier.new,
);

/// Quantidade de filtros de categoria ativos (grupo, equipamento e nível).
/// A busca por nome não entra na contagem.
final activeExerciseFilterCountProvider = Provider<int>((ref) {
  return [
    ref.watch(selectedMuscleGroupProvider),
    ref.watch(selectedEquipmentProvider),
    ref.watch(selectedLevelProvider),
  ].where((value) => value != null).length;
});

// Lista base (reativa ao banco de dados local)
final baseExercisesStreamProvider = StreamProvider<List<Exercise>>((ref) {
  final repo = ref.watch(exerciseRepositoryProvider);
  return repo.watchExercises();
});

/// Lista filtrada: combina a lista base com busca, grupo muscular,
/// equipamento e nível (todos os filtros em AND).
///
/// O catálogo inteiro (~900 itens) já fica em memória pelo stream base, então
/// filtrar aqui é uma passada O(n) sem nova consulta ao SQLite a cada toque.
final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final asyncBaseList = ref.watch(baseExercisesStreamProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final selectedGroup = ref.watch(selectedMuscleGroupProvider);
  final equipment = ref.watch(selectedEquipmentProvider);
  final level = ref.watch(selectedLevelProvider);

  final muscleKeys = selectedGroup == null
      ? null
      : (muscleGroupTranslation[selectedGroup] ?? const <String>[]).toSet();

  return asyncBaseList.whenData((list) {
    return list
        .where((exercise) {
          if (query.isNotEmpty &&
              !exercise.name.toLowerCase().contains(query)) {
            return false;
          }
          if (muscleKeys != null &&
              !exercise.primaryMuscleList.any(
                (m) => muscleKeys.contains(m.toLowerCase()),
              )) {
            return false;
          }
          if (equipment != null && !_sameKey(exercise.equipment, equipment)) {
            return false;
          }
          if (level != null && !_sameKey(exercise.level, level)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  });
});

bool _sameKey(String? raw, String key) =>
    raw != null && raw.trim().toLowerCase() == key;
