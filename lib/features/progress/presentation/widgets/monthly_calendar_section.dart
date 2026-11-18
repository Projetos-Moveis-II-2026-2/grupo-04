import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';

import '../../domain/utils/calendar_utils.dart';
import '../providers/progress_providers.dart';
import 'monthly_summary_card.dart';
import 'workout_calendar.dart';

/// Seção da aba de Progresso com o resumo e o calendário mensal de treinos
/// concluídos, incluindo navegação entre meses e estado vazio.
class MonthlyCalendarSection extends ConsumerWidget {
  const MonthlyCalendarSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final summaryAsync = ref.watch(monthlyWorkoutSummaryProvider);
    final summary = summaryAsync.value;
    final currentMonth = firstDayOfMonth(DateTime.now());
    final canGoToNextMonth = month.isBefore(currentMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}
