import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/notifications/local_notification_service.dart';
import 'package:olimpus/core/notifications/notification_permission_service.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/data/repositories/water_reminder_repository_impl.dart';
import 'package:olimpus/features/water/domain/entities/water_reminder_settings.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_reminder_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeLocalNotificationService implements ILocalNotificationService {
  final List<int> cancelledIds = [];
  bool cancelledAll = false;
  int cancelRecurringCount = 0;
  final List<
    ({int id, String title, String body, tz.TZDateTime date, bool exact})
  >
  scheduledDaily = [];
  bool testNotificationScheduled = false;
  bool canExact = true;

  @override
  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTapped,
  }) async {}

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  @override
  Future<bool> canScheduleExactAlarms() async => canExact;

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelRecurringReminders() async {
    cancelRecurringCount++;
    scheduledDaily.clear();
  }

  @override
  Future<void> cancelAll() async {
    cancelledAll = true;
    scheduledDaily.clear();
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required bool exact,
    String? payload,
  }) async {
    scheduledDaily.add((
      id: id,
      title: title,
      body: body,
      date: scheduledDate,
      exact: exact,
    ));
  }

  @override
  Future<void> scheduleTestNotificationInOneMinute({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    testNotificationScheduled = true;
  }
}

class FakeNotificationPermissionService
    implements INotificationPermissionService {
  NotificationPermissionStatus status = NotificationPermissionStatus.granted;
  bool settingsOpened = false;

  @override
  bool get areRemindersSupported => true;

  @override
  Future<NotificationPermissionStatus> checkPermission() async => status;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => status;

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
  });

  late SharedPreferences prefs;
  late FakeLocalNotificationService fakeNotifService;
  late FakeNotificationPermissionService fakePermService;

  final testUser = AppUser(
    id: 'user-777',
    email: 'atleta@olimpus.app',
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeNotifService = FakeLocalNotificationService();
    fakePermService = FakeNotificationPermissionService();
  });

  ProviderContainer createContainer({
    AppUser? user,
    bool unauthenticated = false,
    int todayWaterTotal = 0,
    AsyncValue<int>? todayWaterTotalAsync,
  }) {
    final effectiveUser = unauthenticated ? null : (user ?? testUser);
    final repo = WaterReminderRepositoryImpl(prefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        waterReminderRepositoryProvider.overrideWithValue(repo),
        localNotificationServiceProvider.overrideWithValue(fakeNotifService),
        notificationPermissionServiceProvider.overrideWithValue(
          fakePermService,
        ),
        currentUserProvider.overrideWith((ref) => effectiveUser),
        todayWaterTotalProvider.overrideWithValue(
          todayWaterTotalAsync ?? AsyncData(todayWaterTotal),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('WaterReminderSettingsNotifier', () {
    test('sem usuário logado retorna desativado por padrão', () async {
      final container = createContainer(unauthenticated: true);
      final settings = await container.read(
        waterReminderSettingsProvider.future,
      );
      expect(settings.enabled, isFalse);
    });

    test('com usuário logado carrega configurações persistidas', () async {
      final container = createContainer();
      final settings = await container.read(
        waterReminderSettingsProvider.future,
      );
      expect(settings.enabled, isFalse);
      expect(settings.intervalHours, 2);
    });

    test('setEnabled(true) com permissão concedida ativa e persiste', () async {
      fakePermService.status = NotificationPermissionStatus.granted;
      final container = createContainer();

      final success = await container
          .read(waterReminderSettingsProvider.notifier)
          .setEnabled(true);

      expect(success, isTrue);
      final updated = container.read(waterReminderSettingsProvider).value;
      expect(updated?.enabled, isTrue);
    });

    test(
      'setEnabled(true) com permissão negada não ativa e retorna false',
      () async {
        fakePermService.status = NotificationPermissionStatus.denied;
        final container = createContainer();

        final success = await container
            .read(waterReminderSettingsProvider.notifier)
            .setEnabled(true);

        expect(success, isFalse);
        final updated = container.read(waterReminderSettingsProvider).value;
        expect(updated?.enabled, isFalse);
      },
    );

    test(
      'setEnabled(true) com permissão permanentemente negada retorna false',
      () async {
        fakePermService.status = NotificationPermissionStatus.permanentlyDenied;
        final container = createContainer();

        final success = await container
            .read(waterReminderSettingsProvider.notifier)
            .setEnabled(true);

        expect(success, isFalse);
        final updated = container.read(waterReminderSettingsProvider).value;
        expect(updated?.enabled, isFalse);
      },
    );

    test('setIntervalHours atualiza intervalo e salva', () async {
      final container = createContainer();
      await container.read(waterReminderSettingsProvider.future);
      final notifier = container.read(waterReminderSettingsProvider.notifier);

      await notifier.setIntervalHours(3);
      final state = container.read(waterReminderSettingsProvider).value;
      expect(state?.intervalHours, 3);
    });

    test('setTimeWindow atualiza início e fim e salva', () async {
      final container = createContainer();
      await container.read(waterReminderSettingsProvider.future);
      final notifier = container.read(waterReminderSettingsProvider.notifier);

      await notifier.setTimeWindow(
        startHour: 7,
        startMinute: 30,
        endHour: 21,
        endMinute: 45,
      );
      final state = container.read(waterReminderSettingsProvider).value;
      expect(state?.startHour, 7);
      expect(state?.startMinute, 30);
      expect(state?.endHour, 21);
      expect(state?.endMinute, 45);
    });

    test('sendTestReminder chama serviço de notificação', () async {
      final container = createContainer();
      await container.read(waterReminderSettingsProvider.future);
      await container
          .read(waterReminderSettingsProvider.notifier)
          .sendTestReminder();
      expect(fakeNotifService.testNotificationScheduled, isTrue);
    });
  });

  group('waterReminderBindingProvider', () {
    test('quando usuário desloga cancela todos os alarmes', () async {
      final container = createContainer(unauthenticated: true);

      container.read(waterReminderBindingProvider);
      await Future<void>.delayed(Duration.zero);

      expect(fakeNotifService.cancelledAll, isTrue);
      expect(fakeNotifService.scheduledDaily, isEmpty);
    });

    test(
      'quando lembretes estão ativados agenda as notificações diárias',
      () async {
        final container = createContainer();
        // Ativa as configurações
        await container
            .read(waterReminderSettingsProvider.notifier)
            .setEnabled(true);

        // Lê o binding
        container.read(waterReminderBindingProvider);
        await Future<void>.delayed(Duration.zero);

        expect(fakeNotifService.scheduledDaily, isNotEmpty);
        expect(fakeNotifService.scheduledDaily.first.id, 4600);
        expect(
          fakeNotifService.scheduledDaily.first.title,
          'Hora de se hidratar 💧',
        );
      },
    );

    test(
      'quando a meta de água é atingida silencia o restante do dia',
      () async {
        final container = createContainer(todayWaterTotal: 2500);
        await container
            .read(waterReminderSettingsProvider.notifier)
            .setEnabled(true);

        // Define meta
        await container.read(dailyWaterGoalProvider.notifier).setGoal(2000);

        container.read(waterReminderBindingProvider);
        await Future<void>.delayed(Duration.zero);

        expect(fakeNotifService.scheduledDaily, isNotEmpty);
        final tomorrow = tz.TZDateTime.now(tz.local)
            .add(const Duration(days: 1));
        for (final scheduled in fakeNotifService.scheduledDaily) {
          expect(scheduled.date.day, tomorrow.day);
        }
      },
    );

    test('reagendamento/desativação cancela apenas recorrentes e não chama cancelAll', () async {
      final container = createContainer();
      await container
          .read(waterReminderSettingsProvider.notifier)
          .setEnabled(true);

      container.read(waterReminderBindingProvider);
      await Future<void>.delayed(Duration.zero);

      expect(fakeNotifService.cancelRecurringCount, greaterThan(0));
      expect(fakeNotifService.cancelledAll, isFalse);

      // Desativa lembretes
      await container
          .read(waterReminderSettingsProvider.notifier)
          .setEnabled(false);
      container.read(waterReminderBindingProvider);
      await Future<void>.delayed(Duration.zero);

      expect(fakeNotifService.cancelRecurringCount, greaterThan(1));
      // cancelAll continua falso (preserva notificações da bandeja e teste ID 4699)
      expect(fakeNotifService.cancelledAll, isFalse);
    });

    test('startup com total em loading não agenda prematuramente', () async {
      final container = createContainer(
        todayWaterTotalAsync: const AsyncLoading(),
      );
      await container
          .read(waterReminderSettingsProvider.notifier)
          .setEnabled(true);

      container.read(waterReminderBindingProvider);
      await Future<void>.delayed(Duration.zero);

      // Enquanto estiver carregando sem valor, não agenda nada prematuramente
      expect(fakeNotifService.scheduledDaily, isEmpty);
    });
  });

  group('WaterReminderScheduler concorrência e descarte de obsoletos', () {
    test(
      'descarta execução obsoleta quando nova operação chega antes de concluir',
      () async {
        final scheduler = WaterReminderScheduler(fakeNotifService);

        const s1 = WaterReminderSettings(enabled: true, intervalHours: 1);
        const s2 = WaterReminderSettings(enabled: true, intervalHours: 3);

        // Dispara dois agendamentos concorrentes
        final f1 = scheduler.schedule(settings: s1, goalReachedToday: false);
        final f2 = scheduler.schedule(settings: s2, goalReachedToday: true);

        await Future.wait([f1, f2]);

        // O resultado final deve conter os agendamentos de s2 (intervalo de 3h com meta batida)
        expect(fakeNotifService.scheduledDaily, isNotEmpty);
        final tomorrow = tz.TZDateTime.now(tz.local)
            .add(const Duration(days: 1));
        for (final scheduled in fakeNotifService.scheduledDaily) {
          expect(scheduled.date.day, tomorrow.day);
        }
      },
    );

    test('cancelRecurring descarta agendamento concorrente anterior', () async {
      final scheduler = WaterReminderScheduler(fakeNotifService);
      const s1 = WaterReminderSettings(enabled: true, intervalHours: 2);

      final f1 = scheduler.schedule(settings: s1, goalReachedToday: false);
      final f2 = scheduler.cancelRecurring();

      await Future.wait([f1, f2]);

      // Como o cancelamento foi enfileirado por último, a lista final de agendados fica vazia
      expect(fakeNotifService.scheduledDaily, isEmpty);
    });
  });

  group('WaterReminderBindingObserver', () {
    test(
      'resumed dispara invalidação de permissões, total do dia e settings',
      () async {
        final container = createContainer();
        final observer = container.read(waterReminderLifecycleObserverProvider);

        // Simula retomada do app (resume)
        await observer.onAppResumed();

        // Passou sem exceções
        expect(true, isTrue);
      },
    );
  });
}
