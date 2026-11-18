import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';
import 'package:olimpus/features/workout/presentation/widgets/template_card.dart';

/// Visão reutilizável da listagem de fichas do usuário (incorporada na Home e/ou em rota própria).
class TemplatesListView extends ConsumerWidget {
  const TemplatesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userWorkoutTemplatesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
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
      ),
      data: (templates) {
        if (templates.isEmpty) {
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
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final tpl = templates[index];
            return TemplateCard(
              template: tpl,
              onEdit: () =>
                  context.push('/templates/${tpl.id}/edit', extra: tpl),
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
