import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';

import '../providers/exercise_providers.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_filters_bar.dart';
import '../widgets/exercise_library_skeleton.dart';
import '../widgets/muscle_group_filter.dart';

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  ConsumerState<ExerciseLibraryPage> createState() =>
      _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Dispara a sincronização de dados (Mock -> Drift) ao abrir a tela.
    // O Provider reativo vai automaticamente receber os dados depois.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exerciseRepositoryProvider).syncExercises();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).update(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(filteredExercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de Exercícios')),
      body: Column(
        children: [
          // Barra de Busca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Filtro de Músculos
          const MuscleGroupFilter(),

          const SizedBox(height: 8),

          // Equipamento, nível, contador e limpar filtros
          const ExerciseFiltersBar(),

          // Lista
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  final hasFilters =
                      ref.watch(activeExerciseFilterCountProvider) > 0;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Nenhum exercício encontrado.'),
                        if (hasFilters)
                          TextButton(
                            onPressed: () => resetExerciseFilters(ref),
                            child: const Text('Limpar filtros'),
                          ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1500), // Pre-caches elements that are 1500 pixels away from the viewport (Lazy Image Loading optimized)
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        context.push(
                          '/exercises/${exercise.id}',
                          extra: exercise,
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const ExerciseLibrarySkeleton(),
              error: (error, stack) => AppErrorWidget(
                error: error,
                stackTrace: stack,
                onRetry: () {
                  ref.read(exerciseRepositoryProvider).syncExercises();
                  ref.invalidate(filteredExercisesProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
