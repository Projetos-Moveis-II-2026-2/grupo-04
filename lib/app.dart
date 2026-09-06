import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/theme/app_theme.dart';
import 'package:olimpus/router/app_router.dart';

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém o dreno automático da SyncQueue vivo enquanto o app roda.
    ref.watch(appLifecycleSyncBindingProvider);

    return MaterialApp.router(
      title: 'Olimpus',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
