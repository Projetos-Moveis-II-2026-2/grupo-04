import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';

void main() {
  Exercise buildExercise({
    required String id,
    required String name,
    String? primaryMuscles,
    String? secondaryMuscles,
    String? equipment,
    String? level,
  }) {
    return Exercise(
      id: id,
      externalId: 'ext-$id',
      name: name,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
      level: level,
      synced: true,
      updatedAt: DateTime(2026, 9, 16),
    );
  }

  final exercises = [
    buildExercise(
      id: '1',
      name: 'Supino Reto',
      primaryMuscles: 'chest',
      secondaryMuscles: 'triceps',
      equipment: 'barbell',
      level: 'beginner',
    ),
    buildExercise(
      id: '2',
      name: 'Remada Curvada',
      primaryMuscles: 'lats',
      secondaryMuscles: 'biceps',
      equipment: 'barbell',
      level: 'intermediate',
    ),
    buildExercise(
      id: '3',
      name: 'Agachamento Livre',
      primaryMuscles: 'quadriceps',
      secondaryMuscles: 'glutes',
      equipment: 'barbell',
      level: 'beginner',
    ),
    buildExercise(
      id: '5',
      name: 'Crucifixo com Halteres',
      primaryMuscles: 'chest',
      secondaryMuscles: 'shoulders',
      equipment: 'dumbbell',
      level: 'beginner',
    ),
    buildExercise(
      id: '6',
      name: 'Press Inclinado com Halteres',
      primaryMuscles: 'chest, shoulders',
      equipment: 'dumbbell',
      level: 'intermediate',
    ),
    buildExercise(
      id: '4',
      name: 'Rosca Direta',
      primaryMuscles: 'biceps',
      secondaryMuscles: 'chest',
      equipment: 'dumbbell',
      level: 'beginner',
    ),
  ];

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        baseExercisesStreamProvider.overrideWithValue(AsyncData(exercises)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SearchQueryNotifier', () {
    test('should start empty and update the query', () async {
      final container = createContainer();

      expect(container.read(searchQueryProvider), isEmpty);

      container.read(searchQueryProvider.notifier).update('supino');
      expect(container.read(searchQueryProvider), 'supino');
    });
  });

  group('ExerciseFilterNotifier', () {
    test('should start null and update the selected group', () async {
      final container = createContainer();

      expect(container.read(selectedMuscleGroupProvider), isNull);

      container.read(selectedMuscleGroupProvider.notifier).update('Peito');
      expect(container.read(selectedMuscleGroupProvider), 'Peito');

      container.read(selectedMuscleGroupProvider.notifier).update(null);
      expect(container.read(selectedMuscleGroupProvider), isNull);
    });
  });

  group('filteredExercisesProvider', () {
    test('should return all exercises without filters', () async {
      final container = createContainer();

      final result = container.read(filteredExercisesProvider);

      expect(result.value, hasLength(6));
    });

    test('should filter by name case-insensitively', () async {
      final container = createContainer();

      container.read(searchQueryProvider.notifier).update('SUPINO');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result, hasLength(1));
      expect(result.single.id, '1');
    });

    test(
      'should return an empty list when nothing matches the query',
      () async {
        final container = createContainer();

        container.read(searchQueryProvider.notifier).update('inexistente');

        expect(container.read(filteredExercisesProvider).value, isEmpty);
      },
    );

    test('should filter by primary muscle group', () async {
      final container = createContainer();

      container.read(selectedMuscleGroupProvider.notifier).update('Pernas');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result, hasLength(1));
      expect(result.single.name, 'Agachamento Livre');
    });

    test('should match only primary muscles, ignoring secondary', () async {
      final container = createContainer();

      container.read(selectedMuscleGroupProvider.notifier).update('Peito');

      final result = container.read(filteredExercisesProvider).value!;
      // 'Rosca Direta' tem chest só como secundário e fica de fora.
      expect(result.map((e) => e.id), unorderedEquals(['1', '5', '6']));
    });

    test('should match a muscle inside a comma-separated list', () async {
      final container = createContainer();

      container.read(selectedMuscleGroupProvider.notifier).update('Ombros');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result.map((e) => e.id), ['6']);
    });

    test('should filter by equipment', () async {
      final container = createContainer();

      container.read(selectedEquipmentProvider.notifier).update('dumbbell');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result.map((e) => e.id), unorderedEquals(['4', '5', '6']));
    });

    test('should filter by level', () async {
      final container = createContainer();

      container.read(selectedLevelProvider.notifier).update('intermediate');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result.map((e) => e.id), unorderedEquals(['2', '6']));
    });

    test('should combine muscle group, equipment and level', () async {
      final container = createContainer();

      container.read(selectedMuscleGroupProvider.notifier).update('Peito');
      container.read(selectedEquipmentProvider.notifier).update('dumbbell');
      container.read(selectedLevelProvider.notifier).update('beginner');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result.map((e) => e.id), ['5']);
    });

    test('should exclude exercises without equipment or level', () async {
      final container = ProviderContainer(
        overrides: [
          baseExercisesStreamProvider.overrideWithValue(
            AsyncData([buildExercise(id: '9', name: 'Prancha')]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedEquipmentProvider.notifier).update('body only');
      expect(container.read(filteredExercisesProvider).value, isEmpty);

      container.read(selectedEquipmentProvider.notifier).update(null);
      container.read(selectedLevelProvider.notifier).update('beginner');
      expect(container.read(filteredExercisesProvider).value, isEmpty);
    });

    test('should combine query and muscle group filters', () async {
      final container = createContainer();

      container.read(searchQueryProvider.notifier).update('rosca');
      container.read(selectedMuscleGroupProvider.notifier).update('Bíceps');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result, hasLength(1));
      expect(result.single.id, '4');
    });

    test('should return empty when both filters do not intersect', () async {
      final container = createContainer();

      container.read(searchQueryProvider.notifier).update('agachamento');
      container.read(selectedMuscleGroupProvider.notifier).update('Peito');

      expect(container.read(filteredExercisesProvider).value, isEmpty);
    });
  });

  group('activeExerciseFilterCountProvider', () {
    test('counts category filters and ignores the name query', () async {
      final container = createContainer();

      expect(container.read(activeExerciseFilterCountProvider), 0);

      container.read(searchQueryProvider.notifier).update('supino');
      expect(container.read(activeExerciseFilterCountProvider), 0);

      container.read(selectedMuscleGroupProvider.notifier).update('Peito');
      container.read(selectedEquipmentProvider.notifier).update('dumbbell');
      container.read(selectedLevelProvider.notifier).update('beginner');
      expect(container.read(activeExerciseFilterCountProvider), 3);

      container.read(selectedEquipmentProvider.notifier).update(null);
      expect(container.read(activeExerciseFilterCountProvider), 2);
    });
  });
}
