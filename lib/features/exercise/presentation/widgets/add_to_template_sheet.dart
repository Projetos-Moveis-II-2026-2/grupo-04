import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';

/// Abre o seletor de fichas e adiciona [exercise] ao fim da ficha escolhida.
///
/// Mostra um `SnackBar` com o resultado (adicionado, já presente, sem fichas
/// ou erro). Não faz nada se o usuário fechar o seletor.
Future<void> addExerciseToTemplateFlow(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final template = await showModalBottomSheet<WorkoutTemplateEntity>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _TemplatePickerSheet(),
  );
  if (template == null) return;

  if (templateContainsExercise(template, exercise)) {
    messenger.showSnackBar(
      SnackBar(content: Text('Já está na ficha "${template.name}".')),
    );
    return;
  }

  final updated = appendExerciseToTemplate(template, exercise);
  final ok = await ref
      .read(workoutTemplateActionNotifierProvider.notifier)
      .saveTemplate(updated);

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Adicionado à ficha "${template.name}".'
            : 'Não foi possível adicionar à ficha. Tente novamente.',
      ),
    ),
  );
}

/// Indica se [exercise] já faz parte de [template] (por id local, remoto ou externo).
bool templateContainsExercise(
  WorkoutTemplateEntity template,
  Exercise exercise,
) {
  final ids = {exercise.id, exercise.externalId, ?exercise.remoteId};
  return template.exercises.any((item) => ids.contains(item.exerciseId));
}

/// Retorna uma cópia de [template] com [exercise] no fim da lista (3x10 padrão).
WorkoutTemplateEntity appendExerciseToTemplate(
  WorkoutTemplateEntity template,
  Exercise exercise,
) {
  final item = TemplateExerciseItem(
    id: UuidV4.generate(),
    templateId: template.id,
    exerciseId: exercise.id,
    exerciseName: exercise.name,
    primaryMuscles: exercise.primaryMuscles,
    equipment: exercise.equipment,
    imageUrl: exercise.firstImageUrl,
    sortOrder: template.exercises.length,
  );
  return template.copyWith(exercises: [...template.exercises, item]);
}

class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userWorkoutTemplatesProvider);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Adicionar à ficha', style: textTheme.titleLarge),
          ),
          Flexible(
            child: templatesAsync.when(
              data: (templates) {
                if (templates.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Você ainda não tem fichas de treino. '
                      'Crie uma ficha na aba Treino para adicionar exercícios.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final count = template.exercises.length;
                    return ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(template.name),
                      subtitle: Text(
                        count == 1 ? '1 exercício' : '$count exercícios',
                      ),
                      onTap: () => Navigator.of(context).pop(template),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar fichas: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
