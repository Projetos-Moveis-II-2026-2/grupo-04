import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/monthly_workout_summary.dart';

/// Card com o total de treinos e o volume acumulado no mês.
class MonthlySummaryCard extends StatelessWidget {
  const MonthlySummaryCard({required this.summary, super.key});

  final MonthlyWorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final countLabel = summary.workoutCount == 1 ? 'treino' : 'treinos';
    final volumeLabel = NumberFormat(
      '#,##0.#',
      'pt_BR',
    ).format(summary.totalVolumeKg);

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.fitness_center_rounded,
                value: '${summary.workoutCount} $countLabel',
                label: 'no mês',
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _SummaryItem(
                icon: Icons.monitor_weight_outlined,
                value: '$volumeLabel kg de volume',
                label: 'acumulado',
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.foregroundColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Icon(icon, color: foregroundColor, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            color: foregroundColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
