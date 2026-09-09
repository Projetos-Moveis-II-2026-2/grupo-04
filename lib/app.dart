import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/theme/app_theme.dart';
import 'package:olimpus/router/app_router.dart';

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém o dreno automático da SyncQueue e o pull inicial (auth) vivos.
    ref.watch(appLifecycleSyncBindingProvider);
    ref.watch(authSyncBindingProvider);

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
