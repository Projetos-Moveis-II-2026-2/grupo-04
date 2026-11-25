import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado unificado da permissão de notificações no aplicativo.
enum NotificationPermissionStatus {
  /// Permissão concedida pelo usuário.
  granted,

  /// Permissão negada, mas o diálogo do sistema ainda pode ser solicitado.
  denied,

  /// Permissão negada permanentemente (exige abrir as configurações do sistema).
  permanentlyDenied,
}

/// Contrato para verificação e solicitação de permissões de notificação.
abstract class INotificationPermissionService {
  /// Verifica o estado atual da permissão de notificações.
  Future<NotificationPermissionStatus> checkPermission();

  /// Solicita permissão ao sistema.
  Future<NotificationPermissionStatus> requestPermission();

  /// Abre as configurações do aplicativo no sistema operacional.
  Future<bool> openSettings();

  /// Indica se a plataforma atual suporta lembretes locais de hidratação.
  bool get areRemindersSupported;
}

/// Chave para registrar se a permissão já foi solicitada no iOS.
const _kIosPermissionRequestedKey = 'water_reminder_ios_requested';

/// Implementação do serviço de permissões de notificações.
class NotificationPermissionService implements INotificationPermissionService {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences? prefs;

  NotificationPermissionService({
    FlutterLocalNotificationsPlugin? plugin,
    this.prefs,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  bool get areRemindersSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<NotificationPermissionStatus> checkPermission() async {
    if (!areRemindersSupported) {
      return NotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      return _mapPermissionStatus(status);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final options = await iosPlugin?.checkPermissions();
      if (options?.isEnabled == true) {
        return NotificationPermissionStatus.granted;
      }
      final requested = prefs?.getBool(_kIosPermissionRequestedKey) ?? false;
      if (requested) {
        return NotificationPermissionStatus.permanentlyDenied;
      }
      return NotificationPermissionStatus.denied;
    }

    return NotificationPermissionStatus.denied;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!areRemindersSupported) {
      return NotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return _mapPermissionStatus(status);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted =
          await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;

      await prefs?.setBool(_kIosPermissionRequestedKey, true);

      return granted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.permanentlyDenied;
    }

    return NotificationPermissionStatus.denied;
  }

  @override
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  NotificationPermissionStatus _mapPermissionStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return NotificationPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return NotificationPermissionStatus.permanentlyDenied;
    }
    return NotificationPermissionStatus.denied;
  }
}
