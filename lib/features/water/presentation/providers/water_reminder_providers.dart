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
      id: 4699,
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

/// Sincronizador reativo que mantém os alarmes nativos alinhados com o estado do app.
class WaterReminderBindingObserver with WidgetsBindingObserver {
  final Ref _ref;

  WaterReminderBindingObserver(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTimezoneAndPermissions();
    }
  }

  Future<void> _checkTimezoneAndPermissions() async {
    _ref.invalidate(notificationPermissionStatusProvider);
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final currentTz = timezoneInfo.identifier;
      if (tz.local.name != currentTz) {
        tz.setLocalLocation(tz.getLocation(currentTz));
        _ref.invalidate(waterReminderSettingsProvider);
      }
    } catch (_) {}
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
  final notifService = ref.watch(localNotificationServiceProvider);
  final settingsAsync = ref.watch(waterReminderSettingsProvider);
  final totalMl = ref.watch(todayWaterTotalProvider).value ?? 0;
  final goalMl = ref.watch(dailyWaterGoalProvider);

  final isGoalReached = goalMl > 0 && totalMl >= goalMl;

  // Quando não há usuário logado: cancela todos os lembretes
  if (user == null) {
    notifService.cancelAll();
    return;
  }

  final settings = settingsAsync.value;
  if (settings == null || !settings.enabled) {
    notifService.cancelAll();
    return;
  }

  _scheduleWaterReminders(
    notifService: notifService,
    settings: settings,
    goalReachedToday: isGoalReached,
  );
});

Future<void> _scheduleWaterReminders({
  required ILocalNotificationService notifService,
  required WaterReminderSettings settings,
  required bool goalReachedToday,
}) async {
  await notifService.cancelAll();

  if (!settings.isValidWindow || settings.intervalHours <= 0) {
    return;
  }

  final canExact = await notifService.canScheduleExactAlarms();
  final now = tz.TZDateTime.now(tz.local);
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final reminders = buildScheduledReminders(
    settings: settings,
    now: now,
    goalReachedToday: goalReachedToday,
    isAndroid: isAndroid,
  );

  for (final reminder in reminders) {
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
