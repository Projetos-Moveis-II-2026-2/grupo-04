import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:olimpus/app.dart';
import 'package:olimpus/core/constants/api_endpoints.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_reminder_providers.dart';
import 'package:olimpus/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('pt_BR');

  // Inicializa a base de fusos horários para agendamento local de notificações
  tz.initializeTimeZones();
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  await Supabase.initialize(
    url: ApiEndpoints.supabaseUrl,
    publishableKey: ApiEndpoints.supabasePublishableKey,
    // Explícito (#84): PKCE nos links de confirmação/recuperação e renovação
    // automática do JWT (~1h) com rotação do refresh token. A sessão é
    // persistida no armazenamento local padrão e restaurada no próximo boot.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Inicialização segura das notificações: qualquer falha na plataforma
  // não pode interromper o funcionamento e abertura do aplicativo.
  try {
    final localNotificationService = container.read(
      waterNotificationServiceProvider,
    );
    await localNotificationService.initialize(
      onNotificationTapped: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final context = rootNavigatorKey.currentContext;
          if (context != null) {
            context.push(payload);
          } else {
            container
                .read(pendingNotificationRouteProvider.notifier)
                .setRoute(payload);
          }
        }
      },
    );

    final launchDetails = await localNotificationService
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        container
            .read(pendingNotificationRouteProvider.notifier)
            .setRoute(payload);
      }
    }
  } catch (e) {
    debugPrint('Aviso: falha ao configurar notificações no startup: $e');
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const MainApp()),
  );
}
