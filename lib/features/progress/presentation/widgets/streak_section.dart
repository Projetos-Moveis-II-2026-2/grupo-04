import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';

import '../../domain/entities/streak.dart';
import '../providers/progress_providers.dart';
import 'streak_card.dart';

/// Seção da aba de Progresso com os streaks de treino e de hidratação.
class StreakSection extends ConsumerWidget {
  const StreakSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StreakCardAsync(
          streakAsync: ref.watch(workoutStreakProvider),
          type: StreakType.workout,
          onRetry: () => ref.invalidate(workoutStreakProvider),
        ),
        const SizedBox(height: 12),
        _StreakCardAsync(
          streakAsync: ref.watch(waterStreakProvider),
          type: StreakType.water,
          onRetry: () => ref.invalidate(waterStreakProvider),
        ),
      ],
    );
  }
}

class _StreakCardAsync extends StatelessWidget {
  const _StreakCardAsync({
    required this.streakAsync,
    required this.type,
    required this.onRetry,
  });

  final AsyncValue<Streak> streakAsync;
  final StreakType type;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return streakAsync.when(
      data: (streak) => StreakCard(streak: streak, type: type),
      loading: () => Card(
        elevation: 0,
        child: SizedBox(
          height: 86,
          child: Center(
            child: Text(
              type == StreakType.workout
                  ? 'Calculando streak de treino...'
                  : 'Calculando streak de hidratação...',
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: AppErrorWidget(
          error: error,
          stackTrace: stackTrace,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
