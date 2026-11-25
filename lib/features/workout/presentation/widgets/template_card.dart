import 'package:flutter/material.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';

/// Exibe um diálogo de confirmação antes de excluir uma ficha de treino.
Future<bool> showDeleteTemplateConfirmationDialog(
  BuildContext context, {
  required String templateName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir ficha'),
      content: Text(
        'Tem certeza que deseja excluir a ficha "$templateName"? '
        'Esta ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onDelete,
    this.onStart,
  });

  final WorkoutTemplateEntity template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Inicia uma sessão de execução a partir da ficha (null oculta o botão).
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final exercises = template.exercises;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                template.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: template.synced
                                  ? 'Sincronizada na nuvem'
                                  : 'Aguardando sincronização',
                              child: Icon(
                                template.synced
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_upload_outlined,
                                size: 16,
                                color: template.synced
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        if (template.description != null &&
                            template.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            template.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar ficha',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    tooltip: 'Excluir ficha',
                    onPressed: () async {
                      final confirmed =
                          await showDeleteTemplateConfirmationDialog(
                            context,
                            templateName: template.name,
                          );
                      if (confirmed) {
                        onDelete();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${exercises.length} '
                      '${exercises.length == 1 ? 'exercício' : 'exercícios'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onStart != null && exercises.isNotEmpty)
                    FilledButton.icon(
                      key: ValueKey('start-${template.id}'),
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Iniciar treino'),
                    ),
                ],
              ),
              if (exercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final item in exercises.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${item.sortOrder + 1}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.exerciseName,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.targetSets}x${item.targetReps ?? '-'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (exercises.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${exercises.length - 5} outro(s) exercício(s)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
