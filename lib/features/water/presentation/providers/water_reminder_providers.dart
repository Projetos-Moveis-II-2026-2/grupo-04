import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/notification_permission_service.dart';
import '../../../../core/providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/water_reminder_repository_impl.dart';
import '../../domain/entities/water_reminder_settings.dart';
import '../../domain/repositories/i_water_reminder_repository.dart';
import '../../domain/water_reminder_schedule.dart';
import 'water_providers.dart';

/// Provider do repositório de preferências de lembretes de hidratação.
final waterReminderRepositoryProvider = Provider<IWaterReminderRepository>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return WaterReminderRepositoryImpl(prefs);
});

/// Provider do serviço de notificações locais.
final localNotificationServiceProvider = Provider<ILocalNotificationService>((
  ref,
) {
  return LocalNotificationService();
});

/// Provider do serviço de verificação e solicitação de permissões.
final notificationPermissionServiceProvider =
    Provider<INotificationPermissionService>((ref) {
      final localService = ref.watch(localNotificationServiceProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      final plugin = (localService is LocalNotificationService)
          ? localService.plugin
          : null;
      return NotificationPermissionService(plugin: plugin, prefs: prefs);
    });

/// Status atual da permissão de notificações.
final notificationPermissionStatusProvider =
    FutureProvider.autoDispose<NotificationPermissionStatus>((ref) async {
      final service = ref.watch(notificationPermissionServiceProvider);
      return service.checkPermission();
    });

/// Notifier que gerencia as configurações de lembrete de água do usuário atual.
class WaterReminderSettingsNotifier
    extends AsyncNotifier<WaterReminderSettings> {
  @override
  FutureOr<WaterReminderSettings> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const WaterReminderSettings(enabled: false);
    }
    final repo = ref.watch(waterReminderRepositoryProvider);
    return repo.loadSettings(user.id);
  }

  /// Alterna a ativação dos lembretes.
  ///
  /// Se [enabled] for `true`, solicita a permissão de notificação se necessário.
  /// Retorna `true` se as configurações foram salvas com sucesso, ou `false` se
  /// a permissão foi negada.
  Future<bool> setEnabled(bool enabled) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;

    if (enabled) {
      final permService = ref.read(notificationPermissionServiceProvider);
      var status = await permService.checkPermission();

      if (status == NotificationPermissionStatus.denied) {
        status = await permService.requestPermission();
      }

      ref.invalidate(notificationPermissionStatusProvider);

      if (status != NotificationPermissionStatus.granted) {
        return false;
      }
    }

    final current = state.value ?? const WaterReminderSettings();
    final updated = current.copyWith(enabled: enabled);
    state = AsyncData(updated);

    final repo = ref.read(waterReminderRepositoryProvider);
    await repo.saveSettings(user.id, updated);
    return true;
  }

  /// Atualiza o intervalo em horas entre os lembretes (1, 2 ou 3).
  Future<void> setIntervalHours(int hours) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final current = state.value ?? const WaterReminderSettings();
    final updated = current.copyWith(intervalHours: hours);
    state = AsyncData(updated);

    final repo = ref.read(waterReminderRepositoryProvider);
    await repo.saveSettings(user.id, updated);
  }

  /// Atualiza a janela de horários (início e término).
  Future<void> setTimeWindow({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final current = state.value ?? const WaterReminderSettings();
    final updated = current.copyWith(
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    );
    state = AsyncData(updated);

    final repo = ref.read(waterReminderRepositoryProvider);
    await repo.saveSettings(user.id, updated);
  }

  /// Agenda uma notificação de teste para 1 minuto à frente (Decisão aprovada P7a).
  Future<void> sendTestReminder() async {
    final notifService = ref.read(localNotificationServiceProvider);
    await notifService.scheduleTestNotificationInOneMinute(
      id: kWaterReminderTestId,
      title: kWaterReminderTitle,
      body: 'Lembrete de teste: hora de se hidratar! 💧',
      payload: kWaterReminderPayload,
    );
  }
}

/// Provider do estado das configurações de lembrete de hidratação.
final waterReminderSettingsProvider =
    AsyncNotifierProvider<WaterReminderSettingsNotifier, WaterReminderSettings>(
      WaterReminderSettingsNotifier.new,
    );

/// Gerencia o agendamento serializado e cancelamento seguro de lembretes,
/// descartando execuções obsoletas para evitar condições de corrida.
class WaterReminderScheduler {
  final ILocalNotificationService notifService;
  int _latestExecutionId = 0;
  Future<void> _chain = Future.value();

  WaterReminderScheduler(this.notifService);

  /// Agenda os lembretes de forma serializada, descartando agendamentos obsoletos.
  Future<void> schedule({
    required WaterReminderSettings settings,
    required bool goalReachedToday,
  }) {
    final executionId = ++_latestExecutionId;
    _chain = _chain
        .then((_) async {
          if (executionId != _latestExecutionId) return;
          await _executeSchedule(settings, goalReachedToday, executionId);
        })
        .catchError((error, stackTrace) {
          debugPrint('Aviso: erro na fila de agendamento de lembretes: $error');
        });
    return _chain;
  }

  /// Cancela apenas os lembretes recorrentes (IDs 4600..4698).
  /// Preserva notificações já disparadas na bandeja e o lembrete de teste (ID 4699).
  Future<void> cancelRecurring() {
    final executionId = ++_latestExecutionId;
    _chain = _chain
        .then((_) async {
          if (executionId != _latestExecutionId) return;
          await notifService.cancelRecurringReminders();
        })
        .catchError((error, stackTrace) {
          debugPrint('Aviso: erro ao cancelar lembretes recorrentes: $error');
        });
    return _chain;
  }

  /// Cancela todas as notificações do app (usado apenas no logout).
  Future<void> cancelAll() {
    final executionId = ++_latestExecutionId;
    _chain = _chain
        .then((_) async {
          if (executionId != _latestExecutionId) return;
          await notifService.cancelAll();
        })
        .catchError((error, stackTrace) {
          debugPrint('Aviso: erro ao cancelar todas as notificações: $error');
        });
    return _chain;
  }

  Future<void> _executeSchedule(
    WaterReminderSettings settings,
    bool goalReachedToday,
    int executionId,
  ) async {
    // 1. Limpa agendamentos recorrentes anteriores
    await notifService.cancelRecurringReminders();
    if (executionId != _latestExecutionId) return;

    if (!settings.isValidWindow || settings.intervalHours <= 0) {
      return;
    }

    // 2. Consulta permissão de alarmes exatos
    final canExact = await notifService.canScheduleExactAlarms();
    if (executionId != _latestExecutionId) return;

    final now = tz.TZDateTime.now(tz.local);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final reminders = buildScheduledReminders(
      settings: settings,
      now: now,
      goalReachedToday: goalReachedToday,
      isAndroid: isAndroid,
    );

    // 3. Agenda cada horário verificando obsolescência a cada iteração
    for (final reminder in reminders) {
      if (executionId != _latestExecutionId) return;
      await notifService.scheduleDaily(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: reminder.scheduledDateTime,
        exact: canExact,
        payload: kWaterReminderPayload,
      );
    }
  }
}

/// Provider do scheduler de notificações.
final waterReminderSchedulerProvider = Provider<WaterReminderScheduler>((ref) {
  final notifService = ref.watch(localNotificationServiceProvider);
  return WaterReminderScheduler(notifService);
});

/// Sincronizador reativo que mantém os alarmes nativos alinhados com o estado do app.
class WaterReminderBindingObserver with WidgetsBindingObserver {
  final Ref _ref;
  bool _isObserved = false;
  bool _disposed = false;

  WaterReminderBindingObserver(this._ref) {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _isObserved = true;
  }

  void dispose() {
    _disposed = true;
    if (_isObserved) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onAppResumed();
    }
  }

  Future<void> onAppResumed() async {
    // 1. Atualiza timezone caso tenha mudado nas configurações do SO
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final currentTz = timezoneInfo.identifier;
      if (tz.local.name != currentTz) {
        tz.setLocalLocation(tz.getLocation(currentTz));
      }
    } catch (_) {}

    if (_disposed) return;

    // 2. Invalida permissões para refletir alterações feitas no sistema
    _ref.invalidate(notificationPermissionStatusProvider);

    // 3. Invalida o stream do total de hoje para recalcular caso o dia tenha virado
    _ref.invalidate(todayWaterTotalProvider);

    // 4. Invalida as configurações para forçar reagendamento (novos alarmes exatos, virada de dia, etc.)
    _ref.invalidate(waterReminderSettingsProvider);
  }
}

/// Provider do observer de ciclo de vida para sincronizar timezone e permissões.
final waterReminderLifecycleObserverProvider =
    Provider.autoDispose<WaterReminderBindingObserver>((ref) {
      final observer = WaterReminderBindingObserver(ref);
      ref.onDispose(observer.dispose);
      return observer;
    });

/// Binding que escuta usuário, configurações e meta de água para reagendar alarmes.
final waterReminderBindingProvider = Provider<void>((ref) {
  ref.watch(waterReminderLifecycleObserverProvider);

  final user = ref.watch(currentUserProvider);
  final scheduler = ref.watch(waterReminderSchedulerProvider);
  final settingsAsync = ref.watch(waterReminderSettingsProvider);
  final totalAsync = ref.watch(todayWaterTotalProvider);
  final goalMl = ref.watch(dailyWaterGoalProvider);

  // Quando não há usuário logado: cancela todos os alarmes (logout limpa tudo)
  if (user == null) {
    scheduler.cancelAll();
    return;
  }

  final settings = settingsAsync.value;
  if (settings == null || !settings.enabled) {
    scheduler.cancelRecurring();
    return;
  }

  // Se o total de hoje ainda estiver no carregamento inicial sem valor prévio,
  // aguarda a primeira emissão para evitar agendamento com total = 0 caso a meta já tenha sido batida
  if (totalAsync.isLoading && totalAsync.value == null) {
    return;
  }

  final totalMl = totalAsync.value ?? 0;
  final isGoalReached = goalMl > 0 && totalMl >= goalMl;

  scheduler.schedule(settings: settings, goalReachedToday: isGoalReached);
});
