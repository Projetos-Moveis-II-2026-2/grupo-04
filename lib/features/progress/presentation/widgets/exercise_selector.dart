import 'package:flutter/material.dart';

import '../../domain/entities/user_exercise_summary.dart';

/// Seletor de exercício em formato Dropdown estilizado em Material 3.
class ExerciseSelector extends StatelessWidget {
  const ExerciseSelector({
    super.key,
    required this.exercises,
    required this.selectedExerciseId,
    required this.onChanged,
  });

  final List<UserExerciseSummary> exercises;
  final String? selectedExerciseId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Garante que o valor selecionado existe na lista de itens para evitar crash no Dropdown
    final effectiveValue =
        exercises.any((e) => e.exerciseId == selectedExerciseId)
        ? selectedExerciseId
        : exercises.firstOrNull?.exerciseId;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.primary,
          ),
          borderRadius: BorderRadius.circular(16),
          hint: Text(
            'Selecione um exercício',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          items: exercises.map((exercise) {
            return DropdownMenuItem<String>(
              value: exercise.exerciseId,
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
