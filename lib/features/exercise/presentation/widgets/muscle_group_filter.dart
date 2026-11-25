import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/exercise_providers.dart';

class MuscleGroupFilter extends ConsumerWidget {
  const MuscleGroupFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lista estática de músculos traduzidos
    final muscles = muscleGroupTranslation.keys.toList();
    final selectedMuscle = ref.watch(selectedMuscleGroupProvider);

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: muscles.length + 1, // +1 for "All"
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Todos'),
                selected: selectedMuscle == null,
                onSelected: (_) {
                  ref.read(selectedMuscleGroupProvider.notifier).update(null);
                },
              ),
            );
          }
          final muscle = muscles[index - 1];
          final isSelected = selectedMuscle == muscle;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(muscle),
              selected: isSelected,
              onSelected: (_) {
                ref.read(selectedMuscleGroupProvider.notifier).update(
                    isSelected ? null : muscle);
              },
            ),
          );
        },
      ),
    );
  }
}
