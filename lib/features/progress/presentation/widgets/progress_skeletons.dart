import 'package:flutter/material.dart';
import 'package:olimpus/core/widgets/skeleton.dart';

/// Skeleton do gráfico de evolução de carga máxima (altura total 260).
class ExerciseLoadChartSkeleton extends StatelessWidget {
  const ExerciseLoadChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SkeletonWrapper(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        child: SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho: Título e Badge de PR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Skeleton(width: 140, height: 16),
                        SizedBox(height: 6),
                        Skeleton(width: 180, height: 12),
                      ],
                    ),
                    Skeleton(
                      width: 72,
                      height: 28,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Estatísticas resumidas (Atual, Sessões, Progresso)
                Row(
                  children: const [
                    Skeleton(width: 50, height: 24),
                    SizedBox(width: 16),
                    Skeleton(width: 50, height: 24),
                    SizedBox(width: 16),
                    Skeleton(width: 50, height: 24),
                  ],
                ),
                const SizedBox(height: 20),

                // Área do gráfico
                Expanded(
                  child: Skeleton(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton completo da [ProgressPage] durante o carregamento inicial.
class ProgressPageSkeleton extends StatelessWidget {
  const ProgressPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Streak Section
            Skeleton(height: 84, borderRadius: BorderRadius.circular(20)),
            const SizedBox(height: 16),

            // Monthly Calendar Section
            Skeleton(height: 210, borderRadius: BorderRadius.circular(20)),
            const SizedBox(height: 24),

            // Seletor de exercício
            const Skeleton(width: 140, height: 14),
            const SizedBox(height: 8),
            Skeleton(height: 56, borderRadius: BorderRadius.circular(12)),
            const SizedBox(height: 20),

            // Gráfico de evolução de carga (altura 260)
            const ExerciseLoadChartSkeleton(),
            const SizedBox(height: 20),

            // Histórico de sessões
            Skeleton(height: 130, borderRadius: BorderRadius.circular(20)),
          ],
        ),
      ),
    );
  }
}
