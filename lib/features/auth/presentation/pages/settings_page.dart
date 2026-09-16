import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/edit_water_goal_dialog.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_providers.dart';

/// Tela de Configurações do aplicativo.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conta',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Tema'),
            subtitle: Text(
              themeMode == ThemeMode.system
                  ? 'Seguir sistema'
                  : isDark
                      ? 'Modo Escuro'
                      : 'Modo Claro',
            ),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.water_drop_outlined,
              color: Color(0xFF0288D1),
            ),
            title: const Text('Meta Diária de Água'),
            subtitle: Text('${ref.watch(dailyWaterGoalProvider)} ml'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => EditWaterGoalDialog.show(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Excluir minha conta',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Esta ação é permanente e irreversível'),
            onTap: () => context.push('/delete-account'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair da conta'),
            onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
