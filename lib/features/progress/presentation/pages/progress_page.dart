import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';

import '../../domain/entities/streak.dart';
import '../../domain/utils/calendar_utils.dart';
import '../providers/progress_providers.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/workout_calendar.dart';

/// Tela de progresso com os streaks e o calendário mensal de treinos.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final summaryAsync = ref.watch(monthlyWorkoutSummaryProvider);
    final summary = summaryAsync.value;
    final workoutStreakAsync = ref.watch(workoutStreakProvider);
    final waterStreakAsync = ref.watch(waterStreakProvider);
    final currentMonth = firstDayOfMonth(DateTime.now());
    final canGoToNextMonth = month.isBefore(currentMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StreakCardAsync(
              streakAsync: workoutStreakAsync,
              type: StreakType.workout,
              onRetry: () => ref.invalidate(workoutStreakProvider),
            ),
            const SizedBox(height: 12),
            _StreakCardAsync(
              streakAsync: waterStreakAsync,
              type: StreakType.water,
              onRetry: () => ref.invalidate(waterStreakProvider),
            ),
            const SizedBox(height: 16),
            summaryAsync.when(
              data: (summary) => MonthlySummaryCard(summary: summary),
              loading: () => const Card(
                child: SizedBox(
                  height: 104,
                  child: Center(child: Text('Carregando treinos...')),
                ),
              ),
              error: (error, stackTrace) => Card(
                child: AppErrorWidget(
                  error: error,
                  stackTrace: stackTrace,
                  onRetry: () => ref.invalidate(monthlyWorkoutSummaryProvider),
                ),
              ),
            ),
            const SizedBox(height: 16),
            WorkoutCalendar(
              month: month,
              trainedDays: summary?.trainedDays ?? const <DateTime>{},
              onPreviousMonth: () =>
                  ref.read(selectedMonthProvider.notifier).previous(),
              onNextMonth: canGoToNextMonth
                  ? () => ref.read(selectedMonthProvider.notifier).next()
                  : null,
            ),
            if (summary != null && summary.isEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nenhum treino concluído neste mês',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.water_drop_rounded),
                label: const Text('Ver Consumo de Água'),
                onPressed: () => context.push('/water'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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
