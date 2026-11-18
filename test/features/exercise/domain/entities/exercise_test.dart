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
}
