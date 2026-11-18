import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/exercise_load_point.dart';

/// Gráfico de linha para visualização da evolução da carga máxima de um exercício ao longo do tempo.
class ExerciseLoadChart extends StatelessWidget {
  const ExerciseLoadChart({
    super.key,
    required this.exerciseName,
    required this.points,
  });

  final String exerciseName;
  final List<ExerciseLoadPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final isSinglePoint = points.length == 1;

    // Cálculo das métricas estatísticas
    final maxWeight = points.map((p) => p.maxWeightKg).reduce(max);
    final minWeight = points.map((p) => p.maxWeightKg).reduce(min);
    final latestWeight = points.last.maxWeightKg;
    final initialWeight = points.first.maxWeightKg;
    final deltaWeight = latestWeight - initialWeight;

    // Definição dos limites Y para o gráfico
    final double minY;
    final double maxY;
    if (isSinglePoint) {
      minY = max(0.0, maxWeight - 10.0);
      maxY = maxWeight + 10.0;
    } else {
      final range = maxWeight - minWeight;
      final padding = range > 0 ? range * 0.2 : 5.0;
      minY = max(0.0, (minWeight - padding).floorToDouble());
      maxY = (maxWeight + padding).ceilToDouble();
    }

    final double minX = isSinglePoint ? -0.5 : 0.0;
    final double maxX = isSinglePoint ? 0.5 : (points.length - 1).toDouble();

    final dateFormat = DateFormat('dd/MM');
    final numberFormat = NumberFormat('#,##0.#', 'pt_BR');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com nome do exercício e badge de PR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Evolução de carga máxima por sessão',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de Recorde Pessoal (PR)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PR: ${numberFormat.format(maxWeight)} kg',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Linha com estatísticas rápidas
            Row(
              children: [
                _StatTile(
                  label: 'Atual',
                  value: '${numberFormat.format(latestWeight)} kg',
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                _StatTile(
                  label: 'Sessões',
                  value: '${points.length}',
                  color: theme.colorScheme.secondary,
                ),
                if (!isSinglePoint) ...[
                  const SizedBox(width: 16),
                  _StatTile(
                    label: 'Progresso',
                    value:
                        '${deltaWeight >= 0 ? '+' : ''}${numberFormat.format(deltaWeight)} kg',
                    color: deltaWeight >= 0
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Área do LineChart
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY == minY ? minY + 10.0 : maxY,
                  clipData: const FlClipData.none(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((maxY - minY) / 3).clamp(1.0, 100.0),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF263238),
                      tooltipBorderRadius: BorderRadius.circular(8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.round();
                          if (index < 0 || index >= points.length) return null;
                          final point = points[index];
                          final formattedDate = dateFormat.format(point.date);
                          final formattedWeight = numberFormat.format(
                            point.maxWeightKg,
                          );

                          return LineTooltipItem(
                            '$formattedDate\n',
                            const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                            children: [
                              TextSpan(
                                text: '$formattedWeight kg',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(
                              '${value.toInt()}kg',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }

                          // Em listas com muitos pontos, espaça os títulos
                          if (points.length > 5 &&
                              index != 0 &&
                              index != points.length - 1 &&
                              index % 2 != 0) {
                            return const SizedBox.shrink();
                          }

                          final point = points[index];
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              dateFormat.format(point.date),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.maxWeightKg);
                      }).toList(),
                      isCurved: !isSinglePoint,
                      curveSmoothness: 0.35,
                      preventCurveOverShooting: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3.0,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4.5,
                            color: theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: !isSinglePoint,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.25),
                            theme.colorScheme.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Mensagem explicativa quando houver apenas 1 ponto
            if (isSinglePoint) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '1 sessão registrada. São necessárias 2 ou mais sessões para exibir a curva de evolução.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
