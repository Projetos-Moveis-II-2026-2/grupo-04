import 'package:flutter/material.dart';
import 'package:olimpus/core/theme/app_theme.dart';
import 'package:olimpus/router/app_router.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Olimpus',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
