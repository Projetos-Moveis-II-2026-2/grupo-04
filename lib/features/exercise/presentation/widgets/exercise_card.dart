import 'package:flutter/material.dart';

import '../../domain/entities/exercise.dart';
import '../utils/exercise_labels.dart';
import 'exercise_motion_image.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;

  const ExerciseCard({super.key, required this.exercise, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Imagem do Exercício
            SizedBox(
              width: 100,
              height: 100,
              child: ExerciseMotionImage(
                exercise: exercise,
                fit: BoxFit.cover,
                animate: false,
                fallback: const Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            // Informações
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      muscleListLabel(exercise.primaryMuscles),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    if (exercise.equipment != null &&
                        exercise.equipment!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          equipmentLabel(exercise.equipment),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
