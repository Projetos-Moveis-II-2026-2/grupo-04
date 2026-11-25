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
import 'package:olimpus/features/water/presentation/providers/water_reminder_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/water_reminder_settings_section.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeLocalNotificationService implements ILocalNotificationService {
  bool testReminderCalled = false;

  @override
  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTapped,
  }) async {}

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelRecurringReminders() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required bool exact,
    String? payload,
  }) async {}

  @override
  Future<void> scheduleTestNotificationInOneMinute({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    testReminderCalled = true;
  }
}

class FakeNotificationPermissionService
    implements INotificationPermissionService {
  NotificationPermissionStatus currentStatus =
      NotificationPermissionStatus.granted;
  bool supported = true;
  bool openSettingsCalled = false;

  @override
  bool get areRemindersSupported => supported;

  @override
  Future<NotificationPermissionStatus> checkPermission() async => currentStatus;

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      currentStatus;

  @override
  Future<bool> openSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  late SharedPreferences prefs;
  late FakeLocalNotificationService fakeNotifService;
  late FakeNotificationPermissionService fakePermService;

  final testUser = AppUser(
    id: 'user-widgets-123',
    email: 'teste@olimpus.app',
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeNotifService = FakeLocalNotificationService();
    fakePermService = FakeNotificationPermissionService();
  });

  Widget createWidget({
    NotificationPermissionStatus status = NotificationPermissionStatus.granted,
    bool remindersSupported = true,
  }) {
    fakePermService.currentStatus = status;
    fakePermService.supported = remindersSupported;

    final repo = WaterReminderRepositoryImpl(prefs);

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        waterReminderRepositoryProvider.overrideWithValue(repo),
        waterNotificationServiceProvider.overrideWithValue(fakeNotifService),
        notificationPermissionServiceProvider.overrideWithValue(
          fakePermService,
        ),
        currentUserProvider.overrideWith((ref) => testUser),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WaterReminderSettingsSection()),
        ),
      ),
    );
  }

  group('WaterReminderSettingsSection Widget', () {
    testWidgets('não renderiza nada se plataforma não suportar lembretes', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget(remindersSupported: false));
      await tester.pumpAndSettle();

      expect(find.text('Lembretes de hidratação'), findsNothing);
    });

    testWidgets('renderiza switch desativado por padrão', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Lembretes de hidratação'), findsOneWidget);
      expect(find.text('Desativados'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('ativar o switch exibe opções de intervalo e horários', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Toca no switch para ligar
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Ativados'), findsOneWidget);
      expect(find.text('Intervalo'), findsOneWidget);
      expect(find.text('A cada 2h'), findsOneWidget);
      expect(find.text('Horário dos lembretes'), findsOneWidget);
      expect(find.text('08:00 - 22:00'), findsOneWidget);
    });

    testWidgets(
      'exibe aviso de notificações bloqueadas quando negado permanentemente',
      (tester) async {
        await tester.pumpWidget(
          createWidget(status: NotificationPermissionStatus.permanentlyDenied),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notificações bloqueadas no sistema'), findsOneWidget);
        expect(
          find.text('Toque para corrigir nas configurações'),
          findsOneWidget,
        );

        // Tocar no aviso chama openSettings
        await tester.tap(find.text('Notificações bloqueadas no sistema'));
        await tester.pump();

        expect(fakePermService.openSettingsCalled, isTrue);
      },
    );

    testWidgets('tentar ativar com permissão negada abre diálogo explicativo', (
      tester,
    ) async {
      fakePermService.currentStatus = NotificationPermissionStatus.denied;

      await tester.pumpWidget(
        createWidget(status: NotificationPermissionStatus.denied),
      );
      await tester.pumpAndSettle();

      // Tenta ativar o switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Permissão de notificações'), findsOneWidget);
      expect(
        find.text(
          'Para receber lembretes de água, o Olimpus precisa da permissão de notificações.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('botão de teste em debug agenda notificação de teste', (
      tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Ativa o switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(
        OutlinedButton,
        'Enviar lembrete de teste em 1 min',
      );
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(fakeNotifService.testReminderCalled, isTrue);
      expect(
        find.text('Lembrete de teste agendado para daqui a 1 minuto.'),
        findsOneWidget,
      );
    });
  });
}
