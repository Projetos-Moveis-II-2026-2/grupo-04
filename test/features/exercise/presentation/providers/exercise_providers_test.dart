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
  }) {
    return Exercise(
      id: id,
      externalId: 'ext-$id',
      name: name,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
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
    ),
    buildExercise(
      id: '2',
      name: 'Remada Curvada',
      primaryMuscles: 'lats',
      secondaryMuscles: 'biceps',
    ),
    buildExercise(
      id: '3',
      name: 'Agachamento Livre',
      primaryMuscles: 'quadriceps',
      secondaryMuscles: 'glutes',
    ),
    buildExercise(
      id: '4',
      name: 'Rosca Direta',
      primaryMuscles: 'biceps',
      secondaryMuscles: 'chest',
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

  group('SelectedMuscleGroupNotifier', () {
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

      expect(result.value, hasLength(4));
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

    test('should also match secondary muscle groups', () async {
      final container = createContainer();

      container.read(selectedMuscleGroupProvider.notifier).update('Peito');

      final result = container.read(filteredExercisesProvider).value!;
      expect(result.map((e) => e.id), containsAll(['1', '4']));
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
}
