import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/core/utils/ui_feedback_extension.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_session_providers.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';
import 'package:olimpus/features/workout/presentation/widgets/template_card.dart';

/// Visão reutilizável da listagem de fichas do usuário (incorporada na Home,
/// na aba Treinos e na rota `/templates`).
class TemplatesListView extends ConsumerWidget {
  const TemplatesListView({
    super.key,
    this.shrinkWrap = false,
    this.compact = false,
  });

  final bool shrinkWrap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userWorkoutTemplatesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return templatesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) {
        if (compact) {
          return _EmptyTemplatesCard(
            onCreatePressed: () => context.push('/templates/new'),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Erro ao carregar suas fichas: $err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(userWorkoutTemplatesProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        );
      },
      data: (templates) {
        if (templates.isEmpty) {
          if (compact) {
            return _EmptyTemplatesCard(
              onCreatePressed: () => context.push('/templates/new'),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Você ainda não possui fichas de treino',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie suas fichas (ex.: Treino A, B, C) com exercícios, séries e repetições alvo.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.push('/templates/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar primeira ficha'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: shrinkWrap
              ? EdgeInsets.zero
              : const EdgeInsets.only(top: 8, bottom: 88),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final tpl = templates[index];
            return TemplateCard(
              template: tpl,
              onEdit: () =>
                  context.push('/templates/${tpl.id}/edit', extra: tpl),
              onStart: () => _startSession(context, ref, tpl),
              onDelete: () async {
                final ok = await ref
                    .read(workoutTemplateActionNotifierProvider.notifier)
                    .deleteTemplate(tpl.id);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ficha "${tpl.name}" excluída.')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

Future<void> _startSession(
  BuildContext context,
  WidgetRef ref,
  WorkoutTemplateEntity template,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  try {
    final sessionId = await ref.read(startWorkoutSessionUseCaseProvider)(
      userId: user.id,
      template: template,
    );
    if (context.mounted) await context.push('/session/$sessionId');
  } on Object catch (e) {
    if (context.mounted) context.showErrorSnackBar(e);
  }
}

class _EmptyTemplatesCard extends StatelessWidget {
  const _EmptyTemplatesCard({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nenhuma ficha criada',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Monte seu Treino A, B, C com exercícios e séries alvo.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }
}

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Fichas de Treino')),
      body: const TemplatesListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Ficha'),
      ),
    );
  }
}
