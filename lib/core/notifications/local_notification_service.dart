import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

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
/// Pensado para ser reaproveitado pelos lembretes da issue de notificações.
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

class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _initialized;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _ensureInitialized() {
    return _initialized ??= () async {
      if (!_supported) return false;
      try {
        // Permissões são pedidas explicitamente em [requestPermission].
        const darwin = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        );
        return await _plugin.initialize(
              settings: const InitializationSettings(
                android: AndroidInitializationSettings('@mipmap/ic_launcher'),
                iOS: darwin,
              ),
            ) ??
            false;
      } on Object {
        return false;
      }
    }();
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

  @override
  Future<void> cancel(int id) async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.cancel(id: id);
    } on Object {
      // Nada a cancelar.
    }
  }

  static Future<void> _systemAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on Object {
      // Plataforma sem som de sistema.
    }
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => FlutterLocalNotificationService(),
);
