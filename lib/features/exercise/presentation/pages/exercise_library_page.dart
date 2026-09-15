import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';
import '../providers/exercise_providers.dart';
import '../widgets/exercise_card.dart';
import '../widgets/muscle_group_filter.dart';

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  ConsumerState<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
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
      appBar: AppBar(
        title: const Text('Biblioteca de Exercícios'),
      ),
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

          // Lista
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(
                    child: Text('Nenhum exercício encontrado.'),
                  );
                }
                return ListView.builder(
                  cacheExtent: 1500.0, // Pre-caches elements that are 1500 pixels away from the viewport (Lazy Image Loading optimized)
                  padding: const EdgeInsets.all(16),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        context.push('/exercises/${exercise.id}', extra: exercise);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Erro ao carregar: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
