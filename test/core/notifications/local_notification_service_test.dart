import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/notifications/local_notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group(
    'LocalNotificationService - Proteção contra crashes em desktop/web',
    () {
      test(
        'em desktop/web todos os métodos são no-op seguros sem lançar exceção',
        () async {
          // Força simulação de plataforma desktop modificando debugDefaultTargetPlatformOverride
          debugDefaultTargetPlatformOverride = TargetPlatform.linux;

          try {
            final service = FlutterLocalNotificationService();

            // Nenhum dos métodos abaixo deve lançar erro
            await service.initialize();
            final launchDetails = await service
                .getNotificationAppLaunchDetails();
            expect(launchDetails, isNull);

            final canExact = await service.canScheduleExactAlarms();
            expect(canExact, isFalse);

            await service.cancel(4600);
            await service.cancelRecurringReminders();
            await service.cancelAll();

            final now = tz.TZDateTime.now(tz.local);
            await service.scheduleDaily(
              id: 4600,
              title: 'Título',
              body: 'Corpo',
              scheduledDate: now,
              exact: false,
            );

            await service.scheduleTestNotificationInOneMinute(
              id: 4699,
              title: 'Teste',
              body: 'Corpo',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      test(
        'cancelRecurringReminders opera sem erro em plataforma móvel',
        () async {
          final service = FlutterLocalNotificationService();

          // Testa em plataforma móvel
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            await service.cancelRecurringReminders();
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    },
  );
}
