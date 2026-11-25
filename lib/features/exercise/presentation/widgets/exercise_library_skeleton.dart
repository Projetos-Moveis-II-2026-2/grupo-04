import 'package:flutter/material.dart';
import 'package:olimpus/core/widgets/skeleton.dart';

/// Skeleton que replica o layout de um [ExerciseCard] na biblioteca de exercícios.
class ExerciseCardSkeleton extends StatelessWidget {
  const ExerciseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Imagem 100x100
          const Skeleton(
            width: 100,
            height: 100,
            borderRadius: BorderRadius.zero,
          ),

          // Informações do exercício
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(width: 140, height: 16),
                  const SizedBox(height: 8),
                  const Skeleton(width: 90, height: 12),
                  const SizedBox(height: 8),
                  Skeleton(
                    width: 50,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton que replica a lista de exercícios na [ExerciseLibraryPage].
class ExerciseLibrarySkeleton extends StatelessWidget {
  const ExerciseLibrarySkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) => const ExerciseCardSkeleton(),
      ),
    );
  }
}
