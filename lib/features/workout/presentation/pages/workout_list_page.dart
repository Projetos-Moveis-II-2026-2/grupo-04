import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WorkoutListPage extends StatelessWidget {
  const WorkoutListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Treinos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
        ],
      ),
    );
  }
}
