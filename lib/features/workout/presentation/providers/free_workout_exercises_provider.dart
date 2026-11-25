import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';
import 'package:olimpus/features/exercise/domain/repositories/i_exercise_repository.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';

/// Quantidade de exercícios carregados por página no seletor do Treino livre.
const int kExercisePickerPageSize = 30;

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

/// Estado imutável da busca paginada de exercícios no seletor do Treino livre.
@immutable
class ExerciseSearchPageState extends Equatable {
  const ExerciseSearchPageState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<ExerciseOption> items;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  static const _unset = Object();

  ExerciseSearchPageState copyWith({
    List<ExerciseOption>? items,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError = _unset,
  }) {
    return ExerciseSearchPageState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: identical(loadMoreError, _unset)
          ? this.loadMoreError
          : loadMoreError,
    );
  }

  @override
  List<Object?> get props => [items, hasMore, isLoadingMore, loadMoreError];
}

/// Gerencia a busca paginada de exercícios para uma [query] específica.
///
/// Carrega a primeira página em [build] garantindo que o catálogo esteja
/// sincronizado e expõe [loadMore] para carregar páginas subsequentes sob
/// demanda, descartando respostas obsoletas e deduplicando itens por `id`.
class WorkoutExerciseSearchNotifier
    extends AsyncNotifier<ExerciseSearchPageState> {
  WorkoutExerciseSearchNotifier(this.query);

  final String query;
  int _generation = 0;

  @override
  Future<ExerciseSearchPageState> build() async {
    var active = true;
    final generation = ++_generation;
    ref.onDispose(() {
      active = false;
      _generation++;
    });

    final repository = ref.watch(exerciseRepositoryProvider);
    final catalogReadyFuture = ref.watch(workoutCatalogReadyProvider.future);

    try {
      await catalogReadyFuture;
      if (!active || !ref.mounted || generation != _generation) {
        return const ExerciseSearchPageState(items: [], hasMore: false);
      }

      final page = await _fetchPage(repository: repository, offset: 0);
      if (!active || !ref.mounted || generation != _generation) {
        return const ExerciseSearchPageState(items: [], hasMore: false);
      }

      final merged = _mergeUnique(const [], page.items);
      return ExerciseSearchPageState(
        items: merged.items,
        hasMore: page.hasMore && merged.addedCount > 0,
      );
    } catch (error, stackTrace) {
      if (!active || !ref.mounted || generation != _generation) {
        return const ExerciseSearchPageState(items: [], hasMore: false);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Carrega a próxima página usando `offset = items.length`.
  ///
  /// Ignora chamadas concorrentes enquanto já está carregando ou quando não há
  /// mais páginas (`hasMore == false`). Em caso de erro, preserva os itens já
  /// carregados e expõe `loadMoreError` para permitir nova tentativa.
  Future<void> loadMore() async {
    final current = state.value;
    if (state.isLoading ||
        current == null ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }

    final generation = _generation;
    final offset = current.items.length;
    final repository = ref.read(exerciseRepositoryProvider);

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: null),
    );

    try {
      final page = await _fetchPage(repository: repository, offset: offset);
      if (!ref.mounted || generation != _generation) return;

      final latest = state.value;
      if (latest == null) return;

      final merged = _mergeUnique(latest.items, page.items);
      state = AsyncData(
        latest.copyWith(
          items: merged.items,
          hasMore: page.hasMore && merged.addedCount > 0,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;

      final latest = state.value;
      if (latest == null) return;

      state = AsyncData(
        latest.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  Future<({List<ExerciseOption> items, bool hasMore})> _fetchPage({
    required IExerciseRepository repository,
    required int offset,
  }) async {
    final fetched = await repository.searchByName(
      query,
      limit: kExercisePickerPageSize + 1,
      offset: offset,
    );
    final hasMore = fetched.length > kExercisePickerPageSize;
    final items = hasMore
        ? fetched.take(kExercisePickerPageSize).toList(growable: false)
        : fetched;
    return (items: items, hasMore: hasMore);
  }

  static ({List<ExerciseOption> items, int addedCount}) _mergeUnique(
    List<ExerciseOption> existing,
    List<ExerciseOption> incoming,
  ) {
    final seenIds = existing.map((item) => item.id).toSet();
    final uniqueIncoming = <ExerciseOption>[];
    for (final item in incoming) {
      if (seenIds.add(item.id)) {
        uniqueIncoming.add(item);
      }
    }
    if (uniqueIncoming.isEmpty) {
      return (items: existing, addedCount: 0);
    }
    return (
      items: List<ExerciseOption>.unmodifiable([
        ...existing,
        ...uniqueIncoming,
      ]),
      addedCount: uniqueIncoming.length,
    );
  }
}

/// Busca paginada de opções leves (`id`, `name`) no banco local para a `query`
/// atual, mantendo estado por consulta e descartando instâncias sem ouvintes.
final workoutExerciseSearchProvider = AsyncNotifierProvider.autoDispose
    .family<WorkoutExerciseSearchNotifier, ExerciseSearchPageState, String>(
      WorkoutExerciseSearchNotifier.new,
    );
