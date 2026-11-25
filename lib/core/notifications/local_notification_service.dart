import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Constantes para canais e identificadores de notificação.
const String kWaterReminderChannelId = 'water_reminders';
const String kWaterReminderChannelName = 'Lembretes de hidratação';
const String kWaterReminderChannelDescription =
    'Lembretes periódicos para beber água';
const String kWaterReminderIcon = 'ic_stat_water';
const String kWaterReminderPayload = '/water';

/// Faixa de IDs de notificações para lembretes de hidratação.
const int kWaterReminderRecurringStartId = 4600;
const int kWaterReminderRecurringEndId = 4698;
const int kWaterReminderTestId = 4699;

/// Contrato para o serviço de notificações locais.
abstract class ILocalNotificationService {
  /// Inicializa o plugin de notificações e canais necessários.
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTapped,
  });

  /// Retorna os detalhes caso o app tenha sido lançado por toque em notificação.
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();

  /// Verifica se o dispositivo Android permite o agendamento de alarmes exatos.
  Future<bool> canScheduleExactAlarms();

  /// Cancela uma notificação agendada pelo seu ID.
  Future<void> cancel(int id);

  /// Cancela apenas os lembretes recorrentes agendados (IDs 4600..4698).
  ///
  /// Preserva notificações já disparadas na bandeja e o lembrete de teste (ID 4699).
  Future<void> cancelRecurringReminders();

  /// Cancela todas as notificações do aplicativo (utilizado no logout).
  Future<void> cancelAll();

  /// Agenda uma notificação recorrente diária no horário especificado.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required bool exact,
    String? payload,
  });

  /// Agenda uma notificação única de teste para 1 minuto no futuro.
  Future<void> scheduleTestNotificationInOneMinute({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
}

/// Implementação do serviço de notificações locais utilizando `flutter_local_notifications`.
class LocalNotificationService implements ILocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTapped,
  }) async {
    if (!_isSupportedPlatform) return;
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(kWaterReminderIcon);
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onNotificationTapped,
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        const channel = AndroidNotificationChannel(
          kWaterReminderChannelId,
          kWaterReminderChannelName,
          description: kWaterReminderChannelDescription,
          importance: Importance.defaultImportance,
        );
        await androidPlugin?.createNotificationChannel(channel);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Aviso: falha ao inicializar LocalNotificationService: $e');
    }
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    if (!_isSupportedPlatform) return null;
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('Aviso: falha ao ler detalhes de lançamento: $e');
      return null;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!_isSupportedPlatform) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidPlugin?.canScheduleExactNotifications() ?? false;
      } catch (e) {
        debugPrint('Aviso: falha ao checar alarmes exatos: $e');
        return false;
      }
    }
    return false;
  }

  @override
  Future<void> cancel(int id) async {
    if (!_isSupportedPlatform) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Aviso: falha ao cancelar notificação $id: $e');
    }
  }

  @override
  Future<void> cancelRecurringReminders() async {
    if (!_isSupportedPlatform) return;
    try {
      for (
        var id = kWaterReminderRecurringStartId;
        id <= kWaterReminderRecurringEndId;
        id++
      ) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('Aviso: falha ao cancelar lembretes recorrentes: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_isSupportedPlatform) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Aviso: falha ao cancelar todas as notificações: $e');
    }
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required bool exact,
    String? payload = kWaterReminderPayload,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        kWaterReminderChannelId,
        kWaterReminderChannelName,
        channelDescription: kWaterReminderChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: kWaterReminderIcon,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final scheduleMode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Aviso: falha ao agendar notificação diária $id: $e');
    }
  }

  @override
  Future<void> scheduleTestNotificationInOneMinute({
    required int id,
    required String title,
    required String body,
    String? payload = kWaterReminderPayload,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      final scheduledDate = tz.TZDateTime.now(tz.local)
          .add(const Duration(minutes: 1));
      final exact = await canScheduleExactAlarms();

      final androidDetails = AndroidNotificationDetails(
        kWaterReminderChannelId,
        kWaterReminderChannelName,
        channelDescription: kWaterReminderChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: kWaterReminderIcon,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final scheduleMode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: scheduleMode,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Aviso: falha ao agendar lembrete de teste: $e');
    }
  }
}
