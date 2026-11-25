import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/workout/presentation/providers/rest_timer_providers.dart';

String formatRest(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Barra do cronômetro de descanso: iniciar/pausar/retomar/parar e alerta
/// visual destacado quando o tempo termina.
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final controller = ref.read(restTimerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = timer.status == RestTimerStatus.finished;

    final (Color background, Color foreground) = finished
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
        : (scheme.surfaceContainerHighest, scheme.onSurface);

    final label = switch (timer.status) {
      RestTimerStatus.idle => 'Descanso · ${formatRest(timer.totalSeconds)}',
      RestTimerStatus.running => formatRest(timer.remainingSeconds),
      RestTimerStatus.paused =>
        'Pausado · ${formatRest(timer.remainingSeconds)}',
      RestTimerStatus.finished => 'Descanso concluído!',
    };

    return AnimatedContainer(
      key: const ValueKey('rest-timer'),
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: finished ? Border.all(color: scheme.tertiary, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                finished ? Icons.alarm_on : Icons.timer_outlined,
                color: finished ? scheme.tertiary : foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  key: const ValueKey('rest-timer-label'),
                  style:
                      (timer.status == RestTimerStatus.running
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.titleSmall)
                          ?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                ),
              ),
              ..._actions(timer.status, controller),
            ],
          ),
          if (timer.status == RestTimerStatus.running ||
              timer.status == RestTimerStatus.paused)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: LinearProgressIndicator(
                value: timer.progress,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(RestTimerStatus status, RestTimerController c) {
    IconButton button(String key, IconData icon, String tip, VoidCallback f) =>
        IconButton(
          key: ValueKey(key),
          icon: Icon(icon),
          tooltip: tip,
          onPressed: f,
        );

    return switch (status) {
      RestTimerStatus.idle => [
        button('rest-start', Icons.play_arrow, 'Iniciar descanso', c.start),
      ],
      RestTimerStatus.running => [
        button('rest-pause', Icons.pause, 'Pausar', c.pause),
        button('rest-stop', Icons.stop, 'Parar', c.stop),
      ],
      RestTimerStatus.paused => [
        button('rest-resume', Icons.play_arrow, 'Retomar', c.resume),
        button('rest-stop', Icons.stop, 'Parar', c.stop),
      ],
      RestTimerStatus.finished => [
        button('rest-restart', Icons.replay, 'Reiniciar', c.start),
        button('rest-dismiss', Icons.close, 'Dispensar', c.stop),
      ],
    };
  }
}
