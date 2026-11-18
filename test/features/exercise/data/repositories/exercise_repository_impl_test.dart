import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_local_datasource.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_remote_datasource_fake.dart';
import 'package:olimpus/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';

class MockExerciseLocalDataSource extends Mock
    implements ExerciseLocalDataSource {}

class MockExerciseRemoteDataSourceFake extends Mock
    implements ExerciseRemoteDataSourceFake {}

void main() {
  late ExerciseRepositoryImpl repository;
  late MockExerciseLocalDataSource mockLocal;
  late MockExerciseRemoteDataSourceFake mockRemote;

  setUpAll(() {
    registerFallbackValue(<ExerciseLibraryTableCompanion>[]);
  });

  setUp(() {
    mockLocal = MockExerciseLocalDataSource();
    mockRemote = MockExerciseRemoteDataSourceFake();
    when(() => mockLocal.hasExercises()).thenAnswer((_) async => false);
    repository = ExerciseRepositoryImpl(mockLocal, mockRemote);
  });

  Exercise buildExercise({String id = 'ex-1', String? remoteId}) {
    return Exercise(
      id: id,
      remoteId: remoteId,
      externalId: 'ext-$id',
      name: 'Supino Reto',
      force: 'push',
      level: 'intermediate',
      mechanic: 'compound',
      equipment: 'barbell',
      primaryMuscles: 'chest',
      secondaryMuscles: 'triceps, shoulders',
      instructions: '• Deite no banco',
      category: 'strength',
      imageUrls: 'https://img/1.jpg,https://img/2.jpg',
      synced: true,
      updatedAt: DateTime(2026, 9, 16, 10),
    );
  }

  group('watchExercises', () {
    test('should delegate to the local datasource stream', () async {
      // arrange
      final exercises = [buildExercise()];
      when(() => mockLocal.watchAllExercises())
          .thenAnswer((_) => Stream.value(exercises));
      // act
      final result = repository.watchExercises();
      // assert
      await expectLater(result, emits(exercises));
      verify(() => mockLocal.watchAllExercises()).called(1);
    });
  });

  group('syncExercises', () {
    test(
      'should fetch from remote and save mapped companions locally',
      () async {
        // arrange
        final exercise = buildExercise(remoteId: 'remote-1');
        when(() => mockRemote.fetchExercises())
            .thenAnswer((_) async => [exercise]);
        when(() => mockLocal.insertExercises(any())).thenAnswer((_) async {});
        // act
        await repository.syncExercises();
        // assert
        final captured =
            verify(() => mockLocal.insertExercises(captureAny()))
                    .captured
                    .single
                as List<ExerciseLibraryTableCompanion>;

        expect(captured, hasLength(1));
        final companion = captured.single;
        expect(companion.id.value, 'ex-1');
        expect(companion.remoteId.value, 'remote-1');
        expect(companion.externalId.value, 'ext-ex-1');
        expect(companion.name.value, 'Supino Reto');
        expect(companion.force.value, 'push');
        expect(companion.level.value, 'intermediate');
        expect(companion.mechanic.value, 'compound');
        expect(companion.equipment.value, 'barbell');
        expect(companion.primaryMuscles.value, 'chest');
        expect(companion.secondaryMuscles.value, 'triceps, shoulders');
        expect(companion.instructions.value, '• Deite no banco');
        expect(companion.category.value, 'strength');
        expect(
          companion.imageUrls.value,
          'https://img/1.jpg,https://img/2.jpg',
        );
        expect(companion.synced.value, isTrue);
        expect(companion.updatedAt.value, DateTime(2026, 9, 16, 10));
      },
    );

    test(
      'should save an empty list when remote returns no exercises',
      () async {
        // arrange
        when(() => mockRemote.fetchExercises()).thenAnswer((_) async => []);
        when(() => mockLocal.insertExercises(any())).thenAnswer((_) async {});
        // act
        await repository.syncExercises();
        // assert
        final captured =
            verify(() => mockLocal.insertExercises(captureAny()))
                    .captured
                    .single
                as List<ExerciseLibraryTableCompanion>;
        expect(captured, isEmpty);
      },
    );

    test('should keep local cache when remote fails', () async {
      // arrange
      when(() => mockRemote.fetchExercises())
          .thenThrow(Exception('network error'));
      // act
      await repository.syncExercises();
      // assert
      verifyNever(() => mockLocal.insertExercises(any()));
    });

    test('should keep local cache when local save fails', () async {
      // arrange
      when(() => mockRemote.fetchExercises())
          .thenAnswer((_) async => [buildExercise()]);
      when(() => mockLocal.insertExercises(any()))
          .thenThrow(Exception('database error'));
      // act & assert
      await expectLater(repository.syncExercises(), completes);
    });

    test('should skip sync when local catalog already has exercises', () async {
      when(() => mockLocal.hasExercises()).thenAnswer((_) async => true);

      await repository.syncExercises();

      verifyNever(() => mockRemote.fetchExercises());
      verifyNever(() => mockLocal.insertExercises(any()));
    });

    test('should deduplicate concurrent syncExercises calls', () async {
      final fetchCompleter = Completer<List<Exercise>>();
      when(() => mockRemote.fetchExercises())
          .thenAnswer((_) => fetchCompleter.future);
      when(() => mockLocal.insertExercises(any())).thenAnswer((_) async {});

      final firstCall = repository.syncExercises();
      final secondCall = repository.syncExercises();
      await Future<void>.delayed(Duration.zero);

      verify(() => mockRemote.fetchExercises()).called(1);

      fetchCompleter.complete([buildExercise()]);
      await Future.wait([firstCall, secondCall]);

      verify(() => mockLocal.insertExercises(any())).called(1);
    });
  });

  group('searchByName', () {
    test(
      'should delegate lightweight query, limit and offset to local datasource',
      () async {
        const options = [ExerciseOption(id: 'ex-1', name: 'Supino Reto')];
        when(() => mockLocal.searchByName('supino', limit: 15, offset: 30))
            .thenAnswer((_) async => options);

        final result = await repository.searchByName(
          'supino',
          limit: 15,
          offset: 30,
        );

        expect(result, options);
        verify(() => mockLocal.searchByName('supino', limit: 15, offset: 30))
            .called(1);
      },
    );
  });
}
