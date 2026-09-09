import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Olimpus'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Alternar tema',
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Olimpus',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (user != null) Text('Logado como: ${user.email}'),
            const SizedBox(height: 24),
            Text('Modo de tema atual: ${themeMode.name}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              label: const Text('Alternar Tema'),
              onPressed: () => ref.read(themeProvider.notifier).toggle(),
            ),
            const SizedBox(height: 48),
            TextButton.icon(
              icon: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Excluir minha conta',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () => context.push('/delete-account'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.fitness_center),
              label: const Text('Biblioteca de Exercícios'),
              onPressed: () => context.push('/exercises'),
            ),
          ],
        ),
      ),
    );
  }
}
