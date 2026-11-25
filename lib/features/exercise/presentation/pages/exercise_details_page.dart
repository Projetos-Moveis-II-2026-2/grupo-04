import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/exercise.dart';

class ExerciseDetailsPage extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailsPage({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GIF ou Imagem do Exercício
            if (exercise.firstImageUrl != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).cardColor,
                ),
                clipBehavior: Clip.antiAlias,
                child: exercise.firstImageUrl!.startsWith('assets/')
                    ? Image.asset(
                        exercise.firstImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Substitua este arquivo vazio na pasta assets/gifs', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: exercise.firstImageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
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
                  child: Icon(Icons.fitness_center, size: 60, color: Colors.grey),
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
              (exercise.primaryMuscles ?? 'N/A').toUpperCase(),
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
              exercise.instructions ?? 'Nenhuma instrução disponível para este exercício.',
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
