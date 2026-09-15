import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/exercise.dart';
import '../providers/exercise_providers.dart';

class ExerciseDetailsPage extends ConsumerWidget {
  final Exercise? exercise;
  final String? exerciseId;

  const ExerciseDetailsPage({
    super.key,
    required Exercise this.exercise,
  }) : exerciseId = null;

  const ExerciseDetailsPage.byId({
    super.key,
    required String this.exerciseId,
  }) : exercise = null;

  factory ExerciseDetailsPage.fromRouteState({
    required String id,
    Object? extra,
  }) {
    if (extra is Exercise) {
      return ExerciseDetailsPage(exercise: extra);
    }
    return ExerciseDetailsPage.byId(exerciseId: id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exercise != null) {
      return _buildScaffold(context, exercise!);
    }

    final exercisesAsync = ref.watch(baseExercisesStreamProvider);
    return exercisesAsync.when(
      data: (exercises) {
        final found = exercises.where((e) => e.id == exerciseId).firstOrNull;
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Exercício')),
            body: const Center(
              child: Text('Exercício não encontrado.'),
            ),
          );
        }
        return _buildScaffold(context, found);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Exercício')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Exercício')),
        body: Center(child: Text('Erro ao carregar exercício: $error')),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, Exercise currentExercise) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentExercise.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GIF ou Imagem do Exercício
            if (currentExercise.firstImageUrl != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                ),
                clipBehavior: Clip.antiAlias,
                child: currentExercise.firstImageUrl!.startsWith('assets/')
                    ? Image.asset(
                        currentExercise.firstImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported,
                                  size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Substitua este arquivo vazio na pasta assets/gifs',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: currentExercise.firstImageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.image_not_supported,
                              size: 50, color: Colors.grey),
                        ),
                      ),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                ),
                child: const Center(
                  child:
                      Icon(Icons.fitness_center, size: 60, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 24),

            // Informações
            Text(
              'Músculo Alvo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              (currentExercise.primaryMuscles ?? 'N/A').toUpperCase(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            const SizedBox(height: 24),

            Text(
              'Instruções',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              currentExercise.instructions ??
                  'Nenhuma instrução disponível para este exercício.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
