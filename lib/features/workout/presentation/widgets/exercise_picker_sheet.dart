import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';
import 'package:olimpus/features/workout/presentation/providers/free_workout_exercises_provider.dart';

/// Exibe um bottom sheet modal com busca paginada no banco e lista lazy para
/// seleção de exercício.
///
/// Retorna a opção escolhida ou `null` caso o usuário feche sem selecionar.
Future<ExerciseOption?> showExercisePickerSheet(BuildContext context) {
  return showModalBottomSheet<ExerciseOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) =>
          _ExercisePickerSheetBody(scrollController: controller),
    ),
  );
}

class _ExercisePickerSheetBody extends ConsumerStatefulWidget {
  const _ExercisePickerSheetBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_ExercisePickerSheetBody> createState() =>
      _ExercisePickerSheetBodyState();
}

class _ExercisePickerSheetBodyState
    extends ConsumerState<_ExercisePickerSheetBody> {
  static const _debounceDuration = Duration(milliseconds: 250);
  static const double _loadMoreScrollThreshold = 200;

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ExercisePickerSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions || !position.hasPixels) return;
    if (position.pixels < position.maxScrollExtent - _loadMoreScrollThreshold) {
      return;
    }

    final pageState = ref.read(workoutExerciseSearchProvider(_query)).value;
    if (pageState == null ||
        pageState.isLoadingMore ||
        !pageState.hasMore ||
        pageState.loadMoreError != null) {
      return;
    }

    unawaited(
      ref.read(workoutExerciseSearchProvider(_query).notifier).loadMore(),
    );
  }

  void _applyQuery(String rawQuery) {
    final normalized = rawQuery.trim();
    if (normalized == _query) return;
    if (widget.scrollController.hasClients) {
      widget.scrollController.jumpTo(0);
    }
    setState(() => _query = normalized);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      _applyQuery(value);
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();
    _applyQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final catalogReady = ref.watch(workoutCatalogReadyProvider);
    final theme = Theme.of(context);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Selecionar exercício',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                return TextField(
                  key: const Key('free_workout_exercise_search_field'),
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  onSubmitted: (submitted) {
                    _debounce?.cancel();
                    _applyQuery(submitted);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar exercício',
                    hintText: 'Digite o nome do exercício...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.clear),
                            onPressed: _clearQuery,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: switch (catalogReady) {
              AsyncValue(isLoading: true, hasValue: false) => _buildLoading(),
              AsyncValue(hasError: true, hasValue: false) => _buildError(
                theme,
                onRetry: () => ref.invalidate(workoutCatalogReadyProvider),
              ),
              _ => _buildSearchBody(theme),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody(ThemeData theme) {
    final asyncResults = ref.watch(workoutExerciseSearchProvider(_query));
    return switch (asyncResults) {
      AsyncValue(isLoading: true, hasValue: false) => _buildLoading(),
      AsyncValue(:final value?) => _buildResults(context, value, theme),
      AsyncValue(hasError: true) => _buildError(
        theme,
        onRetry: () => ref.invalidate(workoutExerciseSearchProvider(_query)),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Carregando catálogo…'),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Erro ao carregar exercícios.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    ExerciseSearchPageState pageState,
    ThemeData theme,
  ) {
    if (pageState.items.isEmpty) {
      return Center(
        child: Text(
          'Nenhum exercício encontrado',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final hasFooter =
        pageState.hasMore ||
        pageState.isLoadingMore ||
        pageState.loadMoreError != null;
    final itemCount = pageState.items.length + (hasFooter ? 1 : 0);

    return ListView.builder(
      key: const Key('free_workout_exercise_results_list'),
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= pageState.items.length) {
          return _buildLoadMoreFooter(theme, pageState);
        }
        final option = pageState.items[index];
        return ListTile(
          title: Text(option.name),
          onTap: () => Navigator.of(context).pop(option),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter(
    ThemeData theme,
    ExerciseSearchPageState pageState,
  ) {
    if (pageState.loadMoreError != null) {
      return Padding(
        key: const Key('free_workout_exercise_load_more_error'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Erro ao carregar mais exercícios.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => ref
                  .read(workoutExerciseSearchProvider(_query).notifier)
                  .loadMore(),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      key: const Key('free_workout_exercise_load_more'),
      height: 56,
      child: pageState.isLoadingMore
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }
}
