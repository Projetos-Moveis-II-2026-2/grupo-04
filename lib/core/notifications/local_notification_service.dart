import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Contrato das notificações usadas pelos lembretes de hidratação.
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

/// Canal de notificação usado por um alerta (Android exige canal; no iOS é
/// ignorado).
class AlertChannel {
  const AlertChannel({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;
}

/// Notificações locais com som (alertas do app).
///
/// Inicializa o plugin sob demanda e só atua em Android/iOS; nas demais
/// plataformas toca o som de alerta do sistema (suportado no desktop).
/// Os lembretes de hidratação (#46) usam [ILocalNotificationService]; as duas
/// interfaces são atendidas por [FlutterLocalNotificationService].
abstract interface class LocalNotificationService {
  /// Solicita permissão de notificação (Android 13+/iOS). Retorna se foi
  /// concedida; `true` onde não há permissão a pedir.
  Future<bool> requestPermission();

  /// Exibe imediatamente um alerta com som.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required AlertChannel channel,
  });

  /// Agenda um alerta com som para [at] (funciona com o app em segundo plano).
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required AlertChannel channel,
  });

  Future<void> cancel(int id);
}

/// Implementação única das notificações locais do app.
class FlutterLocalNotificationService
    implements LocalNotificationService, ILocalNotificationService {
  FlutterLocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _initialized;
  void Function(NotificationResponse response)? _onNotificationTapped;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Inicializa o plugin uma única vez. O plugin é um singleton: uma segunda
  /// inicialização substituiria o tratamento de toque nas notificações.
  Future<bool> _ensureInitialized() {
    return _initialized ??= () async {
      if (!_supported) return false;
      try {
        // Permissões são pedidas explicitamente pelo app.
        const darwin = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        );
        final ok =
            await _plugin.initialize(
              settings: const InitializationSettings(
                android: AndroidInitializationSettings('@mipmap/ic_launcher'),
                iOS: darwin,
              ),
              onDidReceiveNotificationResponse: (response) =>
                  _onNotificationTapped?.call(response),
            ) ??
            false;
        if (ok) {
          final android = _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          await android?.createNotificationChannel(
            const AndroidNotificationChannel(
              kWaterReminderChannelId,
              kWaterReminderChannelName,
              description: kWaterReminderChannelDescription,
              importance: Importance.defaultImportance,
            ),
          );
        }
        return ok;
      } on Object catch (e) {
        debugPrint('Aviso: falha ao inicializar as notificações: $e');
        return false;
      }
    }();
  }

  @override
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTapped,
  }) async {
    _onNotificationTapped = onNotificationTapped ?? _onNotificationTapped;
    await _ensureInitialized();
  }

  @override
  Future<void> cancel(int id) async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.cancel(id: id);
    } on Object catch (e) {
      debugPrint('Aviso: falha ao cancelar notificação $id: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? true;
    } on Object {
      return false;
    }
  }

  NotificationDetails _details(AlertChannel channel) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      icon: '@mipmap/ic_launcher',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
    ),
  );

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required AlertChannel channel,
  }) async {
    if (!await _ensureInitialized()) {
      await _systemAlert();
      return;
    }
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(channel),
      );
    } on Object {
      await _systemAlert();
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required AlertChannel channel,
  }) async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: _details(channel),
        // Inexato: dispensa a permissão de alarme exato (negada por padrão
        // no Android 14+). Em primeiro plano o alerta é exibido na hora.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } on Object {
      // Sem agendamento, o alerta em primeiro plano continua funcionando.
    }
  }

  static Future<void> _systemAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on Object {
      // Plataforma sem som de sistema.
    }
  }

  // ── Lembretes de hidratação (#46) ──────────────────────────────

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    if (!await _ensureInitialized()) return null;
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('Aviso: falha ao ler detalhes de lançamento: $e');
      return null;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!await _ensureInitialized()) return false;
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
  Future<void> cancelRecurringReminders() async {
    if (!await _ensureInitialized()) return;
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
    if (!await _ensureInitialized()) return;
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
    if (!await _ensureInitialized()) return;

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
    if (!await _ensureInitialized()) return;

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

/// Instância única compartilhada pelas duas interfaces.
final flutterLocalNotificationServiceProvider =
    Provider<FlutterLocalNotificationService>(
      (ref) => FlutterLocalNotificationService(),
    );

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => ref.watch(flutterLocalNotificationServiceProvider),
);
