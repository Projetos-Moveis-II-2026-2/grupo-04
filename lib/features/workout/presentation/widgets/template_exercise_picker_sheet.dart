import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';

/// Abre o modal para buscar e selecionar exercícios da biblioteca (`exercise_library`).
Future<List<CatalogExercise>?> showTemplateExercisePickerSheet(
  BuildContext context,
) {
  return showModalBottomSheet<List<CatalogExercise>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const TemplateExercisePickerSheet(),
  );
}

class TemplateExercisePickerSheet extends ConsumerStatefulWidget {
  const TemplateExercisePickerSheet({super.key});

  @override
  ConsumerState<TemplateExercisePickerSheet> createState() =>
      _TemplateExercisePickerSheetState();
}

class _TemplateExercisePickerSheetState
    extends ConsumerState<TemplateExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String? _selectedMuscleGroup;
  bool _isSyncingCatalog = false;
  String? _syncError;

  final List<CatalogExercise> _selected = <CatalogExercise>[];

  @override
  void initState() {
    super.initState();
    unawaited(_syncCatalogIfNeeded());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncCatalogIfNeeded() async {
    setState(() {
      _isSyncingCatalog = true;
      _syncError = null;
    });
    try {
      await ref.read(workoutTemplateRepositoryProvider).ensureCatalogSynced();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _syncError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingCatalog = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      }
    });
  }

  void _toggleSelection(CatalogExercise exercise) {
    setState(() {
      final index = _selected.indexWhere((e) => e.id == exercise.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(exercise);
      }
    });
  }

  List<CatalogExercise> _filterExercises(List<CatalogExercise> all) {
    return all
        .where((exercise) {
          final matchesQuery =
              _searchQuery.isEmpty ||
              exercise.name.toLowerCase().contains(_searchQuery);
          if (!matchesQuery) return false;

          if (_selectedMuscleGroup == null) return true;
          final englishKeys =
              catalogMuscleGroupTranslation[_selectedMuscleGroup!] ?? const [];
          final ptKey = _selectedMuscleGroup!.toLowerCase();
          final hasPrimary = exercise.primaryMuscleList.any(
            (m) =>
                englishKeys.contains(m.toLowerCase()) ||
                m.toLowerCase().contains(ptKey),
          );
          final hasSecondary =
              exercise.secondaryMuscles != null &&
              (englishKeys.any(
                    (k) => exercise.secondaryMuscles!.toLowerCase().contains(k),
                  ) ||
                  exercise.secondaryMuscles!.toLowerCase().contains(ptKey));
          return hasPrimary || hasSecondary;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogAsync = ref.watch(catalogExercisesStreamProvider);
    final groups = catalogMuscleGroupTranslation.keys.toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Adicionar Exercícios',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar exercício por nome...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: groups.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedMuscleGroup == null;
                    return FilterChip(
                      label: const Text('Todos'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedMuscleGroup = null);
                      },
                    );
                  }
                  final group = groups[index - 1];
                  final isSelected = _selectedMuscleGroup == group;
                  return FilterChip(
                    label: Text(group),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(
                        () => _selectedMuscleGroup = selected ? group : null,
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: catalogAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Erro ao carregar catálogo: $err'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _syncCatalogIfNeeded,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (allExercises) {
                  if (allExercises.isEmpty && _isSyncingCatalog) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Sincronizando biblioteca de exercícios...'),
                        ],
                      ),
                    );
                  }

                  final filtered = _filterExercises(allExercises);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              allExercises.isEmpty
                                  ? (_syncError != null
                                        ? 'Não foi possível baixar o catálogo offline.'
                                        : 'Nenhum exercício disponível no catálogo.')
                                  : 'Nenhum exercício encontrado para o filtro atual.',
                              textAlign: TextAlign.center,
                            ),
                            if (allExercises.isEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _syncCatalogIfNeeded,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Recarregar catálogo'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final ex = filtered[index];
                      final selectedIndex = _selected.indexWhere(
                        (s) => s.id == ex.id,
                      );
                      final isSelected = selectedIndex >= 0;

                      return ListTile(
                        leading: _ExerciseThumbnail(imageUrl: ex.firstImageUrl),
                        title: Text(
                          ex.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (ex.primaryMuscles != null &&
                                ex.primaryMuscles!.isNotEmpty)
                              ex.primaryMuscles!,
                            if (ex.equipment != null &&
                                ex.equipment!.isNotEmpty)
                              ex.equipment!,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? CircleAvatar(
                                radius: 14,
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                child: Text(
                                  '${selectedIndex + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const Icon(Icons.add_circle_outline),
                        selected: isSelected,
                        onTap: () => _toggleSelection(ex),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    icon: const Icon(Icons.check),
                    label: Text(
                      _selected.isEmpty
                          ? 'Selecione exercícios para adicionar'
                          : 'Adicionar ${_selected.length} '
                                '${_selected.length == 1 ? 'exercício' : 'exercícios'}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExerciseThumbnail extends StatelessWidget {
  const _ExerciseThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.fitness_center, color: colorScheme.onSurfaceVariant),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 48,
          height: 48,
          color: colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: 48,
          height: 48,
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.fitness_center,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
