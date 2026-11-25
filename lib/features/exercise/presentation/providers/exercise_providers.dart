import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/i_exercise_repository.dart';
import '../../data/datasources/exercise_local_datasource.dart';
import '../../data/datasources/exercise_remote_datasource_fake.dart';
import '../../data/repositories/exercise_repository_impl.dart';

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

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SelectedMuscleGroupNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void update(String? group) {
    state = group;
  }
}

final selectedMuscleGroupProvider = NotifierProvider<SelectedMuscleGroupNotifier, String?>(SelectedMuscleGroupNotifier.new);

// Lista base (reativa ao banco de dados local)
final baseExercisesStreamProvider = StreamProvider<List<Exercise>>((ref) {
  final repo = ref.watch(exerciseRepositoryProvider);
  return repo.watchExercises();
});

// Mapa de tradução para agrupamento
const muscleGroupTranslation = {
  'Peito': ['chest'],
  'Costas': ['lats', 'middle back', 'lower back'],
  'Ombros': ['shoulders', 'traps'],
  'Pernas': ['quadriceps', 'hamstrings', 'glutes', 'adductors', 'abductors'],
  'Panturrilhas': ['calves'],
  'Bíceps': ['biceps'],
  'Tríceps': ['triceps'],
  'Abdômen': ['abdominals'],
  'Antebraços': ['forearms'],
  'Pescoço': ['neck'],
};

// Provider filtrado (debounced) - combina a lista base com os filtros
final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final asyncBaseList = ref.watch(baseExercisesStreamProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final selectedGroup = ref.watch(selectedMuscleGroupProvider); // ex: 'Peito'

  return asyncBaseList.whenData((list) {
    return list.where((exercise) {
      final matchesQuery = exercise.name.toLowerCase().contains(query);
      
      bool matchesMuscle = true;
      if (selectedGroup != null) {
        final englishKeys = muscleGroupTranslation[selectedGroup] ?? [];
        
        // Verifica se algum músculo primário ou secundário bate com as chaves em inglês
        final hasPrimary = exercise.primaryMuscleList.any((m) => englishKeys.contains(m.toLowerCase()));
        final hasSecondary = exercise.secondaryMuscles != null && 
            englishKeys.any((key) => exercise.secondaryMuscles!.toLowerCase().contains(key));
            
        matchesMuscle = hasPrimary || hasSecondary;
      }
      
      return matchesQuery && matchesMuscle;
    }).toList();
  });
});
