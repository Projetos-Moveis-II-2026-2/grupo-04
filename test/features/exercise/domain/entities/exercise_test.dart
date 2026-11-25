import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';

void main() {
  Exercise buildExercise({
    String? primaryMuscles = 'chest, triceps',
    String? imageUrls = 'https://img/1.jpg, https://img/2.jpg',
    String name = 'Supino Reto',
  }) {
    return Exercise(
      id: 'ex-1',
      externalId: 'ext-1',
      name: name,
      primaryMuscles: primaryMuscles,
      imageUrls: imageUrls,
      synced: false,
      updatedAt: DateTime(2026, 9, 16),
    );
  }

  group('primaryMuscleList', () {
    test('should split, trim and preserve order', () {
      expect(buildExercise().primaryMuscleList, ['chest', 'triceps']);
    });

    test('should return an empty list when primaryMuscles is null', () {
      expect(buildExercise(primaryMuscles: null).primaryMuscleList, isEmpty);
    });

    test('should return an empty list when primaryMuscles is empty', () {
      expect(buildExercise(primaryMuscles: '').primaryMuscleList, isEmpty);
    });

    test('should handle a single muscle', () {
      expect(buildExercise(primaryMuscles: 'lats').primaryMuscleList, ['lats']);
    });
  });

  group('firstImageUrl', () {
    test('should return the first trimmed image url', () {
      expect(buildExercise().firstImageUrl, 'https://img/1.jpg');
    });

    test('should return null when imageUrls is null', () {
      expect(buildExercise(imageUrls: null).firstImageUrl, isNull);
    });

    test('should return null when imageUrls is empty', () {
      expect(buildExercise(imageUrls: '').firstImageUrl, isNull);
    });
  });

  group('Equatable', () {
    test('should be equal when all props match', () {
      expect(buildExercise(), buildExercise());
    });

    test('should differ when a prop changes', () {
      expect(buildExercise(), isNot(buildExercise(name: 'Agachamento')));
    });

    test('props should include all fields', () {
      final exercise = buildExercise();
      expect(exercise.props, hasLength(15));
    });
  });
  group('imageUrlList', () {
    test('returns every trimmed url in order', () {
      expect(buildExercise().imageUrlList, [
        'https://img/1.jpg',
        'https://img/2.jpg',
      ]);
    });

    test('returns an empty list when imageUrls is null or blank', () {
      expect(buildExercise(imageUrls: null).imageUrlList, isEmpty);
      expect(buildExercise(imageUrls: '  ').imageUrlList, isEmpty);
    });
  });

  group('secondaryMuscleList', () {
    Exercise withSecondary(String? value) => Exercise(
      id: 'ex-1',
      externalId: 'ext-1',
      name: 'Supino',
      secondaryMuscles: value,
      synced: false,
      updatedAt: DateTime(2026, 9, 16),
    );

    test('splits and trims, dropping empty entries', () {
      expect(withSecondary('shoulders, triceps,').secondaryMuscleList, [
        'shoulders',
        'triceps',
      ]);
    });

    test('returns an empty list when null', () {
      expect(withSecondary(null).secondaryMuscleList, isEmpty);
    });
  });

  group('instructionSteps', () {
    Exercise withInstructions(String? value) => Exercise(
      id: 'ex-1',
      externalId: 'ext-1',
      name: 'Supino',
      instructions: value,
      synced: false,
      updatedAt: DateTime(2026, 9, 16),
    );

    test('strips bullet markers from the local catalog format', () {
      expect(
        withInstructions('• Deite no banco.\n• Empurre a barra.')
            .instructionSteps,
        ['Deite no banco.', 'Empurre a barra.'],
      );
    });

    test('accepts plain and numbered lines from the remote catalog', () {
      expect(
        withInstructions('1. Primeiro passo\n\n2) Segundo passo\nTerceiro')
            .instructionSteps,
        ['Primeiro passo', 'Segundo passo', 'Terceiro'],
      );
    });

    test('returns an empty list when instructions are missing', () {
      expect(withInstructions(null).instructionSteps, isEmpty);
      expect(withInstructions('   ').instructionSteps, isEmpty);
    });
  });
}
