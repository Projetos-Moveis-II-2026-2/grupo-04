import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/core/providers/action_feedback_provider.dart';

import '../../../../core/providers.dart';

import 'package:olimpus/features/profile/presentation/providers/profile_providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';
import 'package:olimpus/features/water/presentation/widgets/edit_water_goal_dialog.dart';
import 'package:olimpus/features/workout/presentation/providers/rest_timer_providers.dart';

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
    final userProfileAsync = ref.watch(userProfileProvider);
    final displayName = userProfileAsync.value?.displayName;
    final feedback = ref.watch(actionFeedbackProvider);
    final restTimer = ref.watch(restTimerSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
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
                        if (displayName != null &&
                            displayName.trim().isNotEmpty) ...[
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          Text(
                            'Conta',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibração'),
            value: feedback.vibration,
            onChanged: ref.read(actionFeedbackProvider.notifier).setVibration,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Som de feedback'),
            value: feedback.sound,
            onChanged: ref.read(actionFeedbackProvider.notifier).setSound,
          ),
          const Divider(),
          ListTile(
            key: const ValueKey('settings-rest-seconds'),
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Descanso entre séries'),
            subtitle: Text('${restTimer.seconds} segundos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editRestSeconds(context, ref, restTimer.seconds),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline),
            title: const Text('Iniciar descanso ao concluir série'),
            value: restTimer.autoStart,
            onChanged: ref
                .read(restTimerSettingsProvider.notifier)
                .setAutoStart,
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

/// Diálogo para escolher o tempo padrão de descanso (30–180 s, passo 15 s).
Future<void> _editRestSeconds(
  BuildContext context,
  WidgetRef ref,
  int current,
) async {
  var value = current.toDouble();
  final result = await showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Descanso entre séries'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.round()} segundos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Slider(
              key: const ValueKey('rest-seconds-slider'),
              value: value,
              min: restTimerMinSeconds.toDouble(),
              max: restTimerMaxSeconds.toDouble(),
              divisions: (restTimerMaxSeconds - restTimerMinSeconds) ~/ 15,
              label: '${value.round()} s',
              onChanged: (v) => setState(() => value = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(value.round()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
  if (result != null) {
    await ref.read(restTimerSettingsProvider.notifier).setSeconds(result);
  }
}
