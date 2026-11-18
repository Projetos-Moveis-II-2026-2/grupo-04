import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';
import 'package:olimpus/features/exercise/domain/repositories/i_exercise_repository.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';
import 'package:olimpus/features/workout/presentation/providers/free_workout_exercises_provider.dart';

typedef _SearchHandler = Future<List<ExerciseOption>> Function(
  String query,
  int limit,
  int offset,
);

class _FakeExerciseRepository implements IExerciseRepository {
  _FakeExerciseRepository({required this.onSearch, this.onSync});

  final _SearchHandler onSearch;
  final Future<void> Function()? onSync;
  final List<({String query, int limit, int offset})> calls = [];
  int syncCalls = 0;

  @override
  Future<List<ExerciseOption>> searchByName(
    String query, {
    int limit = 30,
    int offset = 0,
  }) {
    calls.add((query: query, limit: limit, offset: offset));
    return onSearch(query, limit, offset);
  }

  @override
  Future<void> syncExercises() async {
    syncCalls++;
    await onSync?.call();
  }

  @override
  Stream<List<Exercise>> watchExercises() => const Stream.empty();
}

List<ExerciseOption> _buildOptions(
  int count, {
  String prefix = 'Exercicio',
  int startIndex = 0,
}) {
  return List.generate(count, (i) {
    final index = startIndex + i;
    final padded = index.toString().padLeft(3, '0');
    return ExerciseOption(id: 'id-$padded', name: '$prefix $padded');
  });
}

void main() {
  group('ExerciseSearchPageState', () {
    test('copyWith atualiza e limpa loadMoreError corretamente', () {
      const initial = ExerciseSearchPageState(
        items: [ExerciseOption(id: '1', name: 'Supino')],
        hasMore: true,
        isLoadingMore: true,
        loadMoreError: 'erro',
      );

      final cleared = initial.copyWith(
        isLoadingMore: false,
        loadMoreError: null,
      );
      expect(cleared.items, initial.items);
      expect(cleared.hasMore, isTrue);
      expect(cleared.isLoadingMore, isFalse);
      expect(cleared.loadMoreError, isNull);

      final preserved = initial.copyWith(isLoadingMore: false);
      expect(preserved.loadMoreError, 'erro');
    });
  });

  group('WorkoutExerciseSearchNotifier', () {
    test('carrega página 1 garantindo catálogo pronto e detecta hasMore via limit + 1', () async {
      final catalog = _buildOptions(65);
      var synced = false;
      final repo = _FakeExerciseRepository(
        onSearch: (query, limit, offset) async {
          if (!synced) return const [];
          return catalog.skip(offset).take(limit).toList();
        },
        onSync: () async {
          synced = true;
        },
      );

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [exerciseRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        workoutExerciseSearchProvider(''),
        (_, _) {},
      );
      addTearDown(sub.close);

      final state = await container.read(
        workoutExerciseSearchProvider('').future,
      );

      expect(repo.syncCalls, 1);
      expect(state.items, hasLength(kExercisePickerPageSize));
      expect(state.items.first.id, 'id-000');
      expect(state.items.last.id, 'id-029');
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreError, isNull);
      expect(repo.calls.last, (
        query: '',
        limit: kExercisePickerPageSize + 1,
        offset: 0,
      ));
    });

    test(
      'loadMore concatena páginas subsequentes e para quando hasMore é false',
      () async {
        final catalog = _buildOptions(65);
        final repo = _FakeExerciseRepository(
          onSearch: (query, limit, offset) async =>
              catalog.skip(offset).take(limit).toList(),
        );

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            exerciseRepositoryProvider.overrideWithValue(repo),
            workoutCatalogReadyProvider.overrideWith((ref) async {}),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          workoutExerciseSearchProvider(''),
          (_, _) {},
        );
        addTearDown(sub.close);

        final page1 = await container.read(
          workoutExerciseSearchProvider('').future,
        );
        expect(page1.items, hasLength(30));
        expect(page1.hasMore, isTrue);

        final notifier = container.read(
          workoutExerciseSearchProvider('').notifier,
        );
        await notifier.loadMore();

        final page2 = container.read(workoutExerciseSearchProvider('')).value!;
        expect(page2.items, hasLength(60));
        expect(page2.items.last.id, 'id-059');
        expect(page2.hasMore, isTrue);
        expect(repo.calls, hasLength(2));

        await notifier.loadMore();

        final page3 = container.read(workoutExerciseSearchProvider('')).value!;
        expect(page3.items, hasLength(65));
        expect(page3.items.last.id, 'id-064');
        expect(page3.hasMore, isFalse);
        expect(repo.calls, hasLength(3));

        // Chamada extra após hasMore == false é ignorada.
        await notifier.loadMore();
        expect(repo.calls, hasLength(3));
      },
    );

    test('loadMore ignora chamadas concorrentes enquanto carrega', () async {
      final catalog = _buildOptions(45);
      final page2Completer = Completer<List<ExerciseOption>>();
      final repo = _FakeExerciseRepository(
        onSearch: (query, limit, offset) {
          if (offset == 0) {
            return Future.value(catalog.take(limit).toList());
          }
          return page2Completer.future;
        },
      );

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          exerciseRepositoryProvider.overrideWithValue(repo),
          workoutCatalogReadyProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        workoutExerciseSearchProvider(''),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(workoutExerciseSearchProvider('').future);
      final notifier = container.read(
        workoutExerciseSearchProvider('').notifier,
      );

      final firstLoad = notifier.loadMore();
      expect(
        container.read(workoutExerciseSearchProvider('')).value!.isLoadingMore,
        isTrue,
      );

      // Segunda chamada concorrente deve ser ignorada.
      final secondLoad = notifier.loadMore();
      expect(repo.calls, hasLength(2)); // 1 (offset 0) + 1 (offset 30)

      page2Completer.complete(catalog.skip(30).take(31).toList());
      await Future.wait([firstLoad, secondLoad]);

      final finalState = container
          .read(workoutExerciseSearchProvider(''))
          .value!;
      expect(finalState.items, hasLength(45));
      expect(finalState.hasMore, isFalse);
      expect(finalState.isLoadingMore, isFalse);
    });

    test(
      'erro em loadMore preserva itens carregados e permite tentar novamente',
      () async {
        final catalog = _buildOptions(40);
        var shouldFailPage2 = true;
        final repo = _FakeExerciseRepository(
          onSearch: (query, limit, offset) async {
            if (offset == 30 && shouldFailPage2) {
              throw Exception('falha ao paginar');
            }
            return catalog.skip(offset).take(limit).toList();
          },
        );

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            exerciseRepositoryProvider.overrideWithValue(repo),
            workoutCatalogReadyProvider.overrideWith((ref) async {}),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          workoutExerciseSearchProvider(''),
          (_, _) {},
        );
        addTearDown(sub.close);

        await container.read(workoutExerciseSearchProvider('').future);
        final notifier = container.read(
          workoutExerciseSearchProvider('').notifier,
        );

        await notifier.loadMore();

        final errorState = container
            .read(workoutExerciseSearchProvider(''))
            .value!;
        expect(errorState.items, hasLength(30));
        expect(errorState.hasMore, isTrue);
        expect(errorState.isLoadingMore, isFalse);
        expect(errorState.loadMoreError, isNotNull);

        shouldFailPage2 = false;
        await notifier.loadMore();

        final recoveredState = container
            .read(workoutExerciseSearchProvider(''))
            .value!;
        expect(recoveredState.items, hasLength(40));
        expect(recoveredState.hasMore, isFalse);
        expect(recoveredState.isLoadingMore, isFalse);
        expect(recoveredState.loadMoreError, isNull);
      },
    );

    test('deduplica itens por id ao concatenar páginas', () async {
      final page1WithSentinel = _buildOptions(31);
      final page2WithDuplicate = [
        page1WithSentinel[29], // Duplicado da página 1
        ..._buildOptions(5, startIndex: 30),
      ];

      final repo = _FakeExerciseRepository(
        onSearch: (query, limit, offset) async {
          if (offset == 0) return page1WithSentinel;
          return page2WithDuplicate;
        },
      );

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          exerciseRepositoryProvider.overrideWithValue(repo),
          workoutCatalogReadyProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        workoutExerciseSearchProvider(''),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(workoutExerciseSearchProvider('').future);
      await container
          .read(workoutExerciseSearchProvider('').notifier)
          .loadMore();

      final state = container.read(workoutExerciseSearchProvider('')).value!;
      expect(state.items, hasLength(35));
      expect(state.items.map((e) => e.id).toSet(), hasLength(35));
    });

    test('mudança de query inicia nova paginação em offset 0', () async {
      final allCatalog = _buildOptions(40);
      final filteredCatalog = _buildOptions(15, prefix: 'Supino');
      final repo = _FakeExerciseRepository(
        onSearch: (query, limit, offset) async {
          final source = query == 'supino' ? filteredCatalog : allCatalog;
          return source.skip(offset).take(limit).toList();
        },
      );

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          exerciseRepositoryProvider.overrideWithValue(repo),
          workoutCatalogReadyProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);

      final allSub = container.listen(
        workoutExerciseSearchProvider(''),
        (_, _) {},
      );
      addTearDown(allSub.close);

      await container.read(workoutExerciseSearchProvider('').future);
      await container
          .read(workoutExerciseSearchProvider('').notifier)
          .loadMore();
      expect(
        container.read(workoutExerciseSearchProvider('')).value!.items,
        hasLength(40),
      );

      final filteredSub = container.listen(
        workoutExerciseSearchProvider('supino'),
        (_, _) {},
      );
      addTearDown(filteredSub.close);

      final filteredState = await container.read(
        workoutExerciseSearchProvider('supino').future,
      );
      expect(filteredState.items, hasLength(15));
      expect(filteredState.hasMore, isFalse);
      expect(repo.calls.last, (
        query: 'supino',
        limit: kExercisePickerPageSize + 1,
        offset: 0,
      ));
    });

    test(
      'descarta resposta obsoleta de build e loadMore após invalidação/dispose',
      () async {
        final slowPage2 = Completer<List<ExerciseOption>>();
        var generation = 0;

        final repo = _FakeExerciseRepository(
          onSearch: (query, limit, offset) {
            if (offset == 0) {
              generation++;
              return Future.value(_buildOptions(31, prefix: 'Gen$generation'));
            }
            return slowPage2.future;
          },
        );

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            exerciseRepositoryProvider.overrideWithValue(repo),
            workoutCatalogReadyProvider.overrideWith((ref) async {}),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          workoutExerciseSearchProvider(''),
          (_, _) {},
        );
        addTearDown(sub.close);

        final gen1Page1 = await container.read(
          workoutExerciseSearchProvider('').future,
        );
        expect(gen1Page1.items.first.name, 'Gen1 000');

        // Dispara loadMore da geração 1 e invalida antes da resposta chegar.
        final obsoleteLoadMore = container
            .read(workoutExerciseSearchProvider('').notifier)
            .loadMore();
        container.invalidate(workoutExerciseSearchProvider(''));

        final gen2Page1 = await container.read(
          workoutExerciseSearchProvider('').future,
        );
        expect(gen2Page1.items.first.name, 'Gen2 000');

        // Resposta atrasada da geração 1 não deve contaminar geração 2.
        slowPage2.complete([
          const ExerciseOption(id: 'stale-1', name: 'Obsoleto'),
        ]);
        await obsoleteLoadMore;

        final currentState = container
            .read(workoutExerciseSearchProvider(''))
            .value!;
        expect(currentState.items, hasLength(30));
        expect(currentState.items.first.name, 'Gen2 000');
        expect(currentState.items.any((item) => item.id == 'stale-1'), isFalse);

        // Também descarta resposta atrasada após dispose do container.
        final slowDisposeLoad = Completer<List<ExerciseOption>>();
        final disposeRepo = _FakeExerciseRepository(
          onSearch: (query, limit, offset) {
            if (offset == 0) return Future.value(_buildOptions(31));
            return slowDisposeLoad.future;
          },
        );
        final disposableContainer = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            exerciseRepositoryProvider.overrideWithValue(disposeRepo),
            workoutCatalogReadyProvider.overrideWith((ref) async {}),
          ],
        );
        final disposableSub = disposableContainer.listen(
          workoutExerciseSearchProvider(''),
          (_, _) {},
        );
        await disposableContainer.read(
          workoutExerciseSearchProvider('').future,
        );
        final loadBeforeDispose = disposableContainer
            .read(workoutExerciseSearchProvider('').notifier)
            .loadMore();
        disposableSub.close();
        disposableContainer.dispose();

        slowDisposeLoad.complete([
          const ExerciseOption(id: 'after-dispose', name: 'Após dispose'),
        ]);
        await expectLater(loadBeforeDispose, completes);
      },
    );

    test('descarta resposta e erro obsoletos de build inicial após invalidação', () async {
      final slowBuild1 = Completer<List<ExerciseOption>>();
      final build1Started = Completer<void>();
      var attempt = 0;

      final repo = _FakeExerciseRepository(
        onSearch: (query, limit, offset) {
          attempt++;
          if (attempt == 1) {
            build1Started.complete();
            return slowBuild1.future;
          }
          return Future.value(const [
            ExerciseOption(id: 'fresh-1', name: 'Atualizado'),
          ]);
        },
      );

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          exerciseRepositoryProvider.overrideWithValue(repo),
          workoutCatalogReadyProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        workoutExerciseSearchProvider(''),
        (_, _) {},
      );
      addTearDown(sub.close);

      // Inicia build #1 e aguarda ele alcançar searchByName antes de invalidar.
      final build1Future = container.read(
        workoutExerciseSearchProvider('').future,
      );
      await build1Started.future;

      container.invalidate(workoutExerciseSearchProvider(''));

      final build2State = await container.read(
        workoutExerciseSearchProvider('').future,
      );
      expect(build2State.items, const [
        ExerciseOption(id: 'fresh-1', name: 'Atualizado'),
      ]);

      // Erro atrasado do build #1 é descartado sem sobrescrever build #2.
      slowBuild1.completeError(Exception('erro atrasado do build 1'));
      await expectLater(build1Future, completes);

      final current = container.read(workoutExerciseSearchProvider('')).value!;
      expect(current.items, const [
        ExerciseOption(id: 'fresh-1', name: 'Atualizado'),
      ]);
    });
  });
}
