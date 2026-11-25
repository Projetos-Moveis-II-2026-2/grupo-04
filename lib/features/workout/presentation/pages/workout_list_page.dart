import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/workout/presentation/pages/templates_page.dart';

class WorkoutListPage extends StatelessWidget {
  const WorkoutListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Treinos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Treino livre'),
              subtitle: const Text(
                'Registre séries e cronometre seus descansos',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/workout/free'),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fichas de Treino',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/templates/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova ficha'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TemplatesListView(shrinkWrap: true, compact: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Ficha'),
      ),
    );
  }
}
