import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:olimpus/core/constants/app_constants.dart';

/// Card em destaque que exibe o total consumido de água no dia atual e o progresso em relação à meta.
class DailyWaterTotalCard extends StatelessWidget {
  const DailyWaterTotalCard({
    super.key,
    required this.totalMl,
    this.goalMl = AppConstants.dailyWaterGoalMl,
    this.onEditGoal,
  });

  final int totalMl;
  final int goalMl;
  final VoidCallback? onEditGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,###', 'pt_BR');
    final formattedTotal = formatter.format(totalMl);
    final formattedGoal = formatter.format(goalMl);

    final progress = goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).toInt();

    const waterPrimaryColor = Color(0xFF0288D1);
    const waterLightColor = Color(0xFFE1F5FE);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF0F2634)
          : waterLightColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: waterPrimaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: waterPrimaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consumo de Hoje',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: onEditGoal,
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Meta diária: $formattedGoal ml',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            if (onEditGoal != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: percentage >= 100
                        ? Colors.green.withValues(alpha: 0.2)
                        : waterPrimaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    percentage >= 100 ? 'Meta atingida! 🎉' : '$percentage%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: percentage >= 100
                          ? Colors.green.shade800
                          : waterPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$formattedTotal ml',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.brightness == Brightness.dark
                        ? Colors.lightBlueAccent
                        : const Color(0xFF01579B),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'hoje',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: theme.brightness == Brightness.dark
                    ? Colors.white12
                    : Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 100 ? Colors.green : waterPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

