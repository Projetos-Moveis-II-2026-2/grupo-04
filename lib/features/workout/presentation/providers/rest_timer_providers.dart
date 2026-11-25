import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/notifications/local_notification_service.dart';
import 'package:olimpus/core/providers/action_feedback_provider.dart';
import 'package:olimpus/core/providers/theme_provider.dart';

// ── Configuração (Settings) ─────────────────────────────────────

typedef RestTimerSettings = ({int seconds, bool autoStart});

const restTimerMinSeconds = 30;
const restTimerMaxSeconds = 180;
const restTimerDefaultSeconds = 90;

const _secondsKey = 'rest_timer_seconds';
const _autoStartKey = 'rest_timer_auto_start';

final restTimerSettingsProvider =
    NotifierProvider<RestTimerSettingsNotifier, RestTimerSettings>(
      RestTimerSettingsNotifier.new,
    );

/// Tempo padrão de descanso (30–180 s) e início automático ao concluir série.
class RestTimerSettingsNotifier extends Notifier<RestTimerSettings> {
  @override
  RestTimerSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (
      seconds: (prefs.getInt(_secondsKey) ?? restTimerDefaultSeconds).clamp(
        restTimerMinSeconds,
        restTimerMaxSeconds,
      ),
      autoStart: prefs.getBool(_autoStartKey) ?? true,
    );
  }

  Future<void> setSeconds(int seconds) async {
    final value = seconds.clamp(restTimerMinSeconds, restTimerMaxSeconds);
    state = (seconds: value, autoStart: state.autoStart);
    await ref.read(sharedPreferencesProvider).setInt(_secondsKey, value);
  }

  Future<void> setAutoStart(bool enabled) async {
    state = (seconds: state.seconds, autoStart: enabled);
    await ref.read(sharedPreferencesProvider).setBool(_autoStartKey, enabled);
  }
}

// ── Cronômetro ──────────────────────────────────────────────────

enum RestTimerStatus { idle, running, paused, finished }

class RestTimerState {
  const RestTimerState({
    required this.status,
    required this.totalSeconds,
    required this.remainingSeconds,
  });

  final RestTimerStatus status;
  final int totalSeconds;
  final int remainingSeconds;

  double get progress =>
      totalSeconds == 0 ? 0 : 1 - remainingSeconds / totalSeconds;
}

/// Relógio injetável (testes avançam o tempo sem esperar).
final restTimerClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

/// ID fixo da notificação de fim de descanso (só existe um descanso por vez).
const restTimerNotificationId = 4101;

const _restChannel = AlertChannel(
  id: 'rest_timer',
  name: 'Descanso entre séries',
  description: 'Aviso sonoro quando o tempo de descanso termina',
);

final restTimerProvider =
    NotifierProvider.autoDispose<RestTimerController, RestTimerState>(
      RestTimerController.new,
    );

/// Cronômetro de descanso: iniciar/pausar/retomar/parar. O restante é
/// calculado pelo horário de término (não por ticks), então não atrasa se o
/// app for para segundo plano. Ao zerar: alerta visual (estado `finished`),
/// vibração e notificação com som — esta também agendada para disparar com
/// o app em segundo plano.
class RestTimerController extends Notifier<RestTimerState> {
  Timer? _ticker;
  DateTime? _endsAt;
  late LocalNotificationService _notifications;
  late DateTime Function() _now;

  @override
  RestTimerState build() {
    // Capturados aqui: `ref` não pode ser usado dentro de onDispose nem
    // depois do dispose (callbacks assíncronos).
    _notifications = ref.read(localNotificationServiceProvider);
    _now = ref.read(restTimerClockProvider);
    ref.onDispose(() {
      _ticker?.cancel();
      if (_endsAt != null) {
        unawaited(_notifications.cancel(restTimerNotificationId));
      }
    });
    final seconds = ref.read(restTimerSettingsProvider).seconds;
    return RestTimerState(
      status: RestTimerStatus.idle,
      totalSeconds: seconds,
      remainingSeconds: seconds,
    );
  }

  /// Inicia (ou reinicia) o descanso com o tempo padrão das configurações.
  void start() {
    final seconds = ref.read(restTimerSettingsProvider).seconds;
    _run(total: seconds, remaining: seconds);
    unawaited(_notifications.requestPermission());
  }

  void pause() {
    if (state.status != RestTimerStatus.running) return;
    _tick();
    if (state.status != RestTimerStatus.running) return; // zerou agora
    _clear();
    state = RestTimerState(
      status: RestTimerStatus.paused,
      totalSeconds: state.totalSeconds,
      remainingSeconds: state.remainingSeconds,
    );
  }

  void resume() {
    if (state.status != RestTimerStatus.paused) return;
    _run(total: state.totalSeconds, remaining: state.remainingSeconds);
  }

  /// Para o descanso (ou dispensa o alerta de fim) e volta ao tempo padrão.
  void stop() {
    _clear();
    final seconds = ref.read(restTimerSettingsProvider).seconds;
    state = RestTimerState(
      status: RestTimerStatus.idle,
      totalSeconds: seconds,
      remainingSeconds: seconds,
    );
  }

  void _run({required int total, required int remaining}) {
    _clear();
    final endsAt = _now().add(Duration(seconds: remaining));
    _endsAt = endsAt;
    state = RestTimerState(
      status: RestTimerStatus.running,
      totalSeconds: total,
      remainingSeconds: remaining,
    );
    unawaited(
      _notifications.schedule(
        id: restTimerNotificationId,
        at: endsAt,
        title: 'Descanso concluído',
        body: 'Hora da próxima série! 💪',
        channel: _restChannel,
      ),
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final remaining = (endsAt.difference(_now()).inMilliseconds / 1000)
        .ceil()
        .clamp(0, state.totalSeconds);
    if (remaining > 0) {
      if (remaining != state.remainingSeconds) {
        state = RestTimerState(
          status: RestTimerStatus.running,
          totalSeconds: state.totalSeconds,
          remainingSeconds: remaining,
        );
      }
      return;
    }
    _finish();
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    state = RestTimerState(
      status: RestTimerStatus.finished,
      totalSeconds: state.totalSeconds,
      remainingSeconds: 0,
    );
    // Em primeiro plano: substitui o agendado (inexato) por um imediato.
    final notifications = _notifications;
    unawaited(() async {
      await notifications.cancel(restTimerNotificationId);
      await notifications.show(
        id: restTimerNotificationId,
        title: 'Descanso concluído',
        body: 'Hora da próxima série! 💪',
        channel: _restChannel,
      );
    }());
    if (ref.read(actionFeedbackProvider).vibration) unawaited(_vibrate());
  }

  static Future<void> _vibrate() async {
    try {
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } on Object {
      // Dispositivo sem vibração.
    }
  }

  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    if (_endsAt != null) {
      _endsAt = null;
      unawaited(_notifications.cancel(restTimerNotificationId));
    }
  }
}
