import 'package:flutter/material.dart';

import '../../domain/entities/streak.dart';

/// Tipo de streak exibido pelo [StreakCard].
enum StreakType { workout, water }

/// Card de gamificação com a sequência atual e o recorde de dias.
class StreakCard extends StatelessWidget {
  const StreakCard({
    required this.streak,
    required this.type,
    this.compact = false,
    super.key,
  });

  /// Dados da sequência a exibir.
  final Streak streak;

  /// Define o ícone, a cor e o rótulo do card.
  final StreakType type;

  /// Versão reduzida para resumos na Home.
  final bool compact;

  IconData get _icon => switch (type) {
    StreakType.workout => Icons.local_fire_department_rounded,
    StreakType.water => Icons.water_drop_rounded,
  };

  Color _color(BuildContext context) => switch (type) {
    StreakType.workout => const Color(0xFFF57C00),
    StreakType.water => const Color(0xFF0288D1),
  };

  String get _title => switch (type) {
    StreakType.workout => 'Treino',
    StreakType.water => 'Hidratação',
  };

  String get _currentLabel =>
      streak.current == 1 ? '1 dia seguido' : '${streak.current} dias seguidos';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(context);

    if (compact) {
      return Card(
        elevation: 0,
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(_icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Recorde: ${streak.best}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Recorde: ${streak.best}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
