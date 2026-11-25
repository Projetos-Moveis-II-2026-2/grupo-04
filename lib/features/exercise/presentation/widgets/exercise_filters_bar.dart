import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/exercise_providers.dart';
import '../utils/exercise_labels.dart';

/// Filtros de equipamento e nível, contador de resultados e ação de limpar.
///
/// Fica abaixo dos chips de grupo muscular ([MuscleGroupFilter]); os três
/// filtros se combinam em AND no [filteredExercisesProvider].
class ExerciseFiltersBar extends ConsumerWidget {
  const ExerciseFiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipment = ref.watch(selectedEquipmentProvider);
    final level = ref.watch(selectedLevelProvider);
    final activeCount = ref.watch(activeExerciseFilterCountProvider);
    final resultCount = ref.watch(filteredExercisesProvider).value?.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterMenuChip(
                key: const Key('equipment-filter'),
                placeholder: 'Equipamento',
                allLabel: 'Todos os equipamentos',
                options: equipmentLabels,
                selected: equipment,
                onChanged: (value) =>
                    ref.read(selectedEquipmentProvider.notifier).update(value),
              ),
              _FilterMenuChip(
                key: const Key('level-filter'),
                placeholder: 'Nível',
                allLabel: 'Todos os níveis',
                options: levelLabels,
                selected: level,
                onChanged: (value) =>
                    ref.read(selectedLevelProvider.notifier).update(value),
              ),
            ],
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (resultCount != null)
                  Text(
                    resultCount == 1
                        ? '1 exercício'
                        : '$resultCount exercícios',
                    key: const Key('exercise-result-count'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const Spacer(),
                if (activeCount > 0)
                  TextButton.icon(
                    onPressed: () => resetExerciseFilters(ref),
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Limpar filtros'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Limpa grupo muscular, equipamento e nível. A busca por nome é mantida,
/// pois o texto continua visível no campo de busca.
void resetExerciseFilters(WidgetRef ref) {
  ref.read(selectedMuscleGroupProvider.notifier).update(null);
  ref.read(selectedEquipmentProvider.notifier).update(null);
  ref.read(selectedLevelProvider.notifier).update(null);
}

class _FilterMenuChip extends StatelessWidget {
  final String placeholder;
  final String allLabel;
  final Map<String, String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterMenuChip({
    super.key,
    required this.placeholder,
    required this.allLabel,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return MenuAnchor(
      menuChildren: [
        _item(allLabel, null),
        for (final entry in options.entries) _item(entry.value, entry.key),
      ],
      builder: (context, controller, _) {
        return FilterChip(
          showCheckmark: false,
          selected: current != null,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(current == null ? placeholder : options[current] ?? current),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
          onSelected: (_) =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
    );
  }

  Widget _item(String label, String? value) {
    return MenuItemButton(
      leadingIcon: Icon(
        Icons.check,
        size: 18,
        color: value == selected ? null : Colors.transparent,
      ),
      onPressed: () => onChanged(value),
      child: Text(label),
    );
  }
}
