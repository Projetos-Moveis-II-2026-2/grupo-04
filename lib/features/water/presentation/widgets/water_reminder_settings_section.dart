import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_permission_service.dart';
import '../providers/water_reminder_providers.dart';

/// Seção de configurações dos lembretes de hidratação na tela de Configurações.
class WaterReminderSettingsSection extends ConsumerWidget {
  const WaterReminderSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permService = ref.watch(notificationPermissionServiceProvider);
    if (!permService.areRemindersSupported) {
      return const SizedBox.shrink();
    }

    final settingsAsync = ref.watch(waterReminderSettingsProvider);
    final settings = settingsAsync.value;
    if (settings == null) {
      return const SizedBox.shrink();
    }

    final permStatusAsync = ref.watch(notificationPermissionStatusProvider);
    final permStatus =
        permStatusAsync.value ?? NotificationPermissionStatus.granted;
    final isBlocked =
        permStatus == NotificationPermissionStatus.permanentlyDenied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          secondary: const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFF0288D1),
          ),
          title: const Text('Lembretes de hidratação'),
          subtitle: Text(settings.enabled ? 'Ativados' : 'Desativados'),
          value: settings.enabled && !isBlocked,
          onChanged: (enabled) async {
            if (isBlocked && enabled) {
              _showPermissionDialog(context, ref, isPermanentlyDenied: true);
              return;
            }

            final success = await ref
                .read(waterReminderSettingsProvider.notifier)
                .setEnabled(enabled);

            if (!success && context.mounted) {
              final newStatus = await ref
                  .read(notificationPermissionServiceProvider)
                  .checkPermission();
              final isPermanent =
                  newStatus == NotificationPermissionStatus.permanentlyDenied;
              if (context.mounted) {
                _showPermissionDialog(
                  context,
                  ref,
                  isPermanentlyDenied: isPermanent,
                );
              }
            }
          },
        ),
        if (isBlocked)
          ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Notificações bloqueadas no sistema',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Toque para corrigir nas configurações'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => permService.openSettings(),
          ),
        if (settings.enabled && !isBlocked) ...[
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Intervalo'),
            subtitle: Text('A cada ${settings.intervalHours}h'),
            trailing: PopupMenuButton<int>(
              tooltip: 'Alterar intervalo',
              initialValue: settings.intervalHours,
              onSelected: (hours) {
                ref
                    .read(waterReminderSettingsProvider.notifier)
                    .setIntervalHours(hours);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 1, child: Text('A cada 1 hora')),
                PopupMenuItem(value: 2, child: Text('A cada 2 horas')),
                PopupMenuItem(value: 3, child: Text('A cada 3 horas')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${settings.intervalHours}h',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Horário dos lembretes'),
            subtitle: Text(settings.formattedTimeWindow),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTimeWindow(
              context,
              ref,
              settings.startTime,
              settings.endTime,
            ),
          ),
          if (kDebugMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Enviar lembrete de teste em 1 min'),
                onPressed: () async {
                  await ref
                      .read(waterReminderSettingsProvider.notifier)
                      .sendTestReminder();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Lembrete de teste agendado para daqui a 1 minuto.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickTimeWindow(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay currentStart,
    TimeOfDay currentEnd,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: currentStart,
      helpText: 'Horário de início',
      cancelText: 'Cancelar',
      confirmText: 'Avançar',
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: currentEnd,
      helpText: 'Horário de término',
      cancelText: 'Cancelar',
      confirmText: 'Salvar',
    );
    if (end == null || !context.mounted) return;

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes <= startMinutes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O horário de término deve ser posterior ao horário de início.',
            ),
          ),
        );
      }
      return;
    }

    await ref
        .read(waterReminderSettingsProvider.notifier)
        .setTimeWindow(
          startHour: start.hour,
          startMinute: start.minute,
          endHour: end.hour,
          endMinute: end.minute,
        );
  }

  void _showPermissionDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isPermanentlyDenied,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão de notificações'),
        content: const Text(
          'Para receber lembretes de água, o Olimpus precisa da permissão de notificações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          if (isPermanentlyDenied)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(notificationPermissionServiceProvider).openSettings();
              },
              child: const Text('Abrir configurações'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref
                    .read(waterReminderSettingsProvider.notifier)
                    .setEnabled(true);
              },
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }
}
