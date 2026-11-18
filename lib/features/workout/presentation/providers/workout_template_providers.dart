import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/workout/data/datasources/exercise_catalog_remote_datasource.dart';
import 'package:olimpus/features/workout/data/datasources/workout_template_local_datasource.dart';
import 'package:olimpus/features/workout/data/repositories/workout_template_repository_impl.dart';
import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';
import 'package:olimpus/features/workout/domain/usecases/delete_workout_template.dart';
import 'package:olimpus/features/workout/domain/usecases/get_workout_template.dart';
import 'package:olimpus/features/workout/domain/usecases/save_workout_template.dart';
import 'package:olimpus/features/workout/domain/usecases/watch_workout_templates.dart';

// ── Datasources ──

final workoutTemplateLocalDataSourceProvider =
    Provider<WorkoutTemplateLocalDataSource>((ref) {
      return WorkoutTemplateLocalDataSource(ref.watch(appDatabaseProvider));
    });

final exerciseCatalogRemoteDataSourceProvider =
    Provider<IExerciseCatalogRemoteDataSource>((ref) {
      return SupabaseExerciseCatalogRemoteDataSource(
        ref.watch(supabaseClientProvider),
      );
    });

// ── Repository ──

final workoutTemplateRepositoryProvider = Provider<IWorkoutTemplateRepository>((
  ref,
) {
  return WorkoutTemplateRepositoryImpl(
    localDataSource: ref.watch(workoutTemplateLocalDataSourceProvider),
    syncQueueService: ref.watch(syncQueueServiceProvider),
    catalogRemoteDataSource: ref.watch(exerciseCatalogRemoteDataSourceProvider),
  );
});

// ── UseCases ──

final watchWorkoutTemplatesUseCaseProvider = Provider<WatchWorkoutTemplates>((
  ref,
) {
  return WatchWorkoutTemplates(ref.watch(workoutTemplateRepositoryProvider));
});

final getWorkoutTemplateUseCaseProvider = Provider<GetWorkoutTemplate>((ref) {
  return GetWorkoutTemplate(ref.watch(workoutTemplateRepositoryProvider));
});

final saveWorkoutTemplateUseCaseProvider = Provider<SaveWorkoutTemplate>((ref) {
  return SaveWorkoutTemplate(ref.watch(workoutTemplateRepositoryProvider));
});

final deleteWorkoutTemplateUseCaseProvider = Provider<DeleteWorkoutTemplate>((
  ref,
) {
  return DeleteWorkoutTemplate(ref.watch(workoutTemplateRepositoryProvider));
});

// ── Streams & Queries ──

/// Stream reativa das fichas do usuário autenticado.
final userWorkoutTemplatesProvider = StreamProvider<List<WorkoutTemplateEntity>>(
  (ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Stream.value(const <WorkoutTemplateEntity>[]);
    }
    return ref.watch(watchWorkoutTemplatesUseCaseProvider)(user.id);
  },
);

/// Busca uma ficha pelo ID para tela de edição.
final workoutTemplateByIdProvider =
    FutureProvider.family<WorkoutTemplateEntity?, String>((ref, id) {
      return ref.watch(getWorkoutTemplateUseCaseProvider)(id);
    });

/// Stream do catálogo de exercícios local (`exercise_library`).
final catalogExercisesStreamProvider = StreamProvider<List<CatalogExercise>>((
  ref,
) {
  return ref.watch(workoutTemplateRepositoryProvider).watchCatalogExercises();
});

/// Mapa de grupos musculares para filtro do seletor de exercícios.
const Map<String, List<String>> catalogMuscleGroupTranslation = {
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

// ── Notifier de Ações (Criar / Editar / Excluir) ──

class WorkoutTemplateActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveTemplate(WorkoutTemplateEntity template) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(saveWorkoutTemplateUseCaseProvider)(template),
    );
    return !state.hasError;
  }

  Future<bool> deleteTemplate(String templateId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(deleteWorkoutTemplateUseCaseProvider)(templateId),
    );
    return !state.hasError;
  }
}

final workoutTemplateActionNotifierProvider =
    AsyncNotifierProvider<WorkoutTemplateActionNotifier, void>(
      WorkoutTemplateActionNotifier.new,
    );
