import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/core/providers.dart';

/// Configuração de rotas do app (go_router).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => const _HomePage())],
);

class _HomePage extends ConsumerWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Olimpus'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Alternar tema',
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Olimpus'),
            const SizedBox(height: 12),
            Text('Modo de tema atual: ${themeMode.name}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              label: const Text('Alternar Tema'),
              onPressed: () => ref.read(themeProvider.notifier).toggle(),
            ),
          ],
        ),
      ),
    );
  }
}
