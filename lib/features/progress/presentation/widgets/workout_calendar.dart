import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/utils/calendar_utils.dart';

/// Grade mensal de treinos realizados.
///
/// Exibe o cabeçalho com navegação entre meses, a linha de dias da semana e
/// os dias do mês, destacando os dias com treino concluído e o dia de hoje.
class WorkoutCalendar extends StatelessWidget {
  const WorkoutCalendar({
    required this.month,
    required this.trainedDays,
    required this.onPreviousMonth,
    this.onNextMonth,
    super.key,
  });

  /// Mês exibido (qualquer dia do mês).
  final DateTime month;

  /// Dias com treino concluído, normalizados para 00:00 no fuso local.
  final Set<DateTime> trainedDays;

  /// Callback ao tocar na seta de mês anterior.
  final VoidCallback onPreviousMonth;

  /// Callback ao tocar na seta de próximo mês. `null` desabilita a seta.
  final VoidCallback? onNextMonth;

  static const List<String> _weekDayLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  static const List<String> _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedMonth = firstDayOfMonth(month);
    final cells = monthGrid(selectedMonth);
    final today = normalizeDay(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('calendar-previous-month'),
                  tooltip: 'Mês anterior',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onPreviousMonth,
                ),
                Expanded(
                  child: Text(
                    _monthLabel(selectedMonth),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('calendar-next-month'),
                  tooltip: 'Próximo mês',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: onNextMonth,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final label in _weekDayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 44,
              ),
              itemBuilder: (context, index) {
                final day = cells[index];
                if (day == null) return const SizedBox.shrink();
                return _DayCell(
                  day: day,
                  hasWorkout: trainedDays.contains(day),
                  isToday: day == today,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _monthLabel(DateTime month) {
    try {
      final formatted = DateFormat('MMMM yyyy', 'pt_BR').format(month);
      if (formatted.isEmpty) return formatted;
      return '${formatted[0].toUpperCase()}${formatted.substring(1)}';
    } catch (_) {
      // Em contextos onde os dados de locale não foram inicializados (por
      // exemplo, testes isolados), usa os nomes em português embutidos.
      return '${_monthNames[month.month - 1]} ${month.year}';
    }
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasWorkout,
    required this.isToday,
  });

  final DateTime day;
  final bool hasWorkout;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final foregroundColor = hasWorkout
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final borderColor = hasWorkout
        ? colorScheme.onPrimary
        : colorScheme.primary;

    return Center(
      child: Container(
        key: ValueKey('${hasWorkout ? 'trained' : 'regular'}-day-${day.day}'),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasWorkout ? colorScheme.primary : null,
          border: isToday ? Border.all(color: borderColor, width: 2) : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: foregroundColor,
            fontWeight: isToday || hasWorkout
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
