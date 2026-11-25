import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/theme/app_theme.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_reminder_providers.dart';
import 'package:olimpus/router/app_router.dart';

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém o dreno automático da SyncQueue, o pull inicial (auth) e os lembretes vivos.
    ref.watch(appLifecycleSyncBindingProvider);
    ref.watch(authSyncBindingProvider);
    // Avisa no login quando o refresh token expira/é revogado (#84).
    ref.watch(sessionExpiryBindingProvider);
    ref.watch(waterReminderBindingProvider);

    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Olimpus',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
