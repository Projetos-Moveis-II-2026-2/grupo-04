import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/constants/app_constants.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/workout/data/datasources/catalog_revision_store.dart';
import 'package:olimpus/features/workout/data/datasources/exercise_catalog_remote_datasource.dart';
import 'package:olimpus/features/workout/data/datasources/workout_template_local_datasource.dart';
import 'package:olimpus/features/workout/data/repositories/workout_template_repository_impl.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/usecases/delete_workout_template.dart';
import 'package:olimpus/features/workout/domain/usecases/save_workout_template.dart';

class _MockSyncGateway extends Mock implements SyncRemoteGateway {}

class _MockCatalogRemoteDataSource extends Mock
    implements IExerciseCatalogRemoteDataSource {}

class _FakeCatalogRevisionStore implements CatalogRevisionStore {
  _FakeCatalogRevisionStore(this.revision);

  int revision;
  int writes = 0;

  @override
  int read() => revision;

  @override
  Future<void> write(int value) async {
    revision = value;
    writes++;
  }
}

void main() {
  late AppDatabase db;
  late _MockSyncGateway gateway;
  late SyncQueueService syncQueue;
  late WorkoutTemplateLocalDataSource localDataSource;
  late _MockCatalogRemoteDataSource catalogRemoteDataSource;
  late _FakeCatalogRevisionStore catalogRevisionStore;
  late WorkoutTemplateRepositoryImpl repository;
  late SaveWorkoutTemplate saveUseCase;
  late DeleteWorkoutTemplate deleteUseCase;

  final exerciseIds = List<String>.generate(5, (_) => UuidV4.generate());

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gateway = _MockSyncGateway();
    when(() => gateway.upsert(any(), any())).thenAnswer((_) async {});
    when(() => gateway.delete(any(), any())).thenAnswer((_) async {});

    syncQueue = SyncQueueService(
      db,
      gateway: gateway,
      retryScheduler: (_, _) {},
    );
    localDataSource = WorkoutTemplateLocalDataSource(db);
    catalogRemoteDataSource = _MockCatalogRemoteDataSource();
    catalogRevisionStore = _FakeCatalogRevisionStore(0);
    repository = WorkoutTemplateRepositoryImpl(
      localDataSource: localDataSource,
      syncQueueService: syncQueue,
      catalogRevisionStore: catalogRevisionStore,
      catalogRemoteDataSource: catalogRemoteDataSource,
    );
    saveUseCase = SaveWorkoutTemplate(repository);
    deleteUseCase = DeleteWorkoutTemplate(repository);

    final now = DateTime.now().toUtc();
    for (var i = 0; i < 5; i++) {
      await db
          .into(db.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: exerciseIds[i],
              remoteId: Value(exerciseIds[i]),
              externalId: 'ex-slug-${i + 1}',
              name: 'Exercício ${i + 1}',
              primaryMuscles: const Value('chest'),
              equipment: const Value('barbell'),
              synced: const Value(true),
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('Fluxo completo (#38): criar "Treino A" com 5 exercícios -> editar (reordenar e remover) -> excluir', () async {
    final templateId = UuidV4.generate();
    const userId = 'user-123';
    final itemIds = List<String>.generate(5, (_) => UuidV4.generate());

    // 1. CRIAR "Treino A" com 5 exercícios
    final initialTemplate = WorkoutTemplateEntity(
      id: templateId,
      userId: userId,
      name: 'Treino A',
      description: 'Peito e Tríceps',
      exercises: [
        for (var i = 0; i < 5; i++)
          TemplateExerciseItem(
            id: itemIds[i],
            templateId: templateId,
            exerciseId: exerciseIds[i],
            exerciseName: 'Exercício ${i + 1}',
            sortOrder: i,
            targetSets: 3 + (i % 2),
            targetReps: 10 + i,
          ),
      ],
      updatedAt: DateTime.now().toUtc(),
    );

    await saveUseCase(initialTemplate);
    await syncQueue.processQueue();

    final loaded = await repository.getTemplateById(templateId);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Treino A');
    expect(loaded.description, 'Peito e Tríceps');
    expect(loaded.synced, isTrue);
    expect(loaded.exercises, hasLength(5));
    for (var i = 0; i < 5; i++) {
      expect(loaded.exercises[i].id, itemIds[i]);
      expect(loaded.exercises[i].sortOrder, i);
      expect(loaded.exercises[i].exerciseName, 'Exercício ${i + 1}');
      expect(loaded.exercises[i].targetSets, 3 + (i % 2));
      expect(loaded.exercises[i].targetReps, 10 + i);
    }

    verify(() => gateway.upsert('workout_templates', any())).called(1);
    verify(() => gateway.upsert('template_exercises', any())).called(5);

    // 2. EDITAR "Treino A": renomear, inverter ordem dos 2 primeiros e remover o 5º exercício
    final remaining = <TemplateExerciseItem>[
      loaded.exercises[1].copyWith(targetSets: 5, targetReps: 8),
      loaded.exercises[0].copyWith(targetSets: 4, targetReps: 12),
      loaded.exercises[2],
      loaded.exercises[3],
    ];

    await saveUseCase(
      loaded.copyWith(name: 'Treino A - Hipertrofia', exercises: remaining),
    );
    await syncQueue.processQueue();

    final afterEdit = await repository.getTemplateById(templateId);
    expect(afterEdit, isNotNull);
    expect(afterEdit!.name, 'Treino A - Hipertrofia');
    expect(afterEdit.exercises, hasLength(4));
    expect(afterEdit.exercises[0].id, itemIds[1]);
    expect(afterEdit.exercises[0].sortOrder, 0);
    expect(afterEdit.exercises[0].targetSets, 5);
    expect(afterEdit.exercises[0].targetReps, 8);
    expect(afterEdit.exercises[1].id, itemIds[0]);
    expect(afterEdit.exercises[1].sortOrder, 1);
    expect(afterEdit.exercises[2].sortOrder, 2);
    expect(afterEdit.exercises[3].sortOrder, 3);

    verify(() => gateway.delete('template_exercises', itemIds[4])).called(1);

    // 3. EXCLUIR "Treino A"
    await deleteUseCase(templateId);
    await syncQueue.processQueue();

    expect(await repository.getTemplateById(templateId), isNull);
    expect(await db.select(db.workoutTemplates).get(), isEmpty);
    expect(await db.select(db.templateExercises).get(), isEmpty);
    verify(() => gateway.delete('workout_templates', templateId)).called(1);
  });

  test(
    'watchTemplates filtra apenas fichas do userId correspondente',
    () async {
      final now = DateTime.now().toUtc();
      await saveUseCase(
        WorkoutTemplateEntity(
          id: UuidV4.generate(),
          userId: 'user-A',
          name: 'Ficha do A',
          updatedAt: now,
        ),
      );
      await saveUseCase(
        WorkoutTemplateEntity(
          id: UuidV4.generate(),
          userId: 'user-B',
          name: 'Ficha do B',
          updatedAt: now,
        ),
      );

      final listA = await repository.watchTemplates('user-A').first;
      expect(listA, hasLength(1));
      expect(listA.single.name, 'Ficha do A');
    },
  );

  group('ensureCatalogSynced', () {
    ExerciseLibraryTableCompanion remoteEntry(String suffix) {
      final id = UuidV4.generate();
      return ExerciseLibraryTableCompanion.insert(
        id: id,
        remoteId: Value(id),
        externalId: 'remote-$suffix',
        name: 'Exercício remoto $suffix',
        synced: const Value(true),
        updatedAt: DateTime.now().toUtc(),
      );
    }

    Future<void> insertUuidRows(int total, {String prefix = 'catalog'}) async {
      final now = DateTime.now().toUtc();
      final rows = <ExerciseLibraryTableCompanion>[
        for (var i = 0; i < total; i++)
          () {
            final id = UuidV4.generate();
            return ExerciseLibraryTableCompanion.insert(
              id: id,
              remoteId: Value(id),
              externalId: '$prefix-$i',
              name: 'Exercício $prefix $i',
              synced: const Value(true),
              updatedAt: now,
            );
          }(),
      ];
      await db.batch((batch) {
        batch.insertAll(db.exerciseLibraryTable, rows);
      });
    }

    test(
      'revisão antiga + catálogo já baixado refaz o fetch e grava a revisão',
      () async {
        await db.delete(db.exerciseLibraryTable).go();
        await insertUuidRows(876);
        catalogRevisionStore.revision =
            AppConstants.exerciseCatalogRevision - 1;
        when(() => catalogRemoteDataSource.fetchCatalog())
            .thenAnswer((_) async => [remoteEntry('a')]);

        await repository.ensureCatalogSynced();

        verify(() => catalogRemoteDataSource.fetchCatalog()).called(1);
        expect(
          catalogRevisionStore.revision,
          AppConstants.exerciseCatalogRevision,
        );
        expect(catalogRevisionStore.writes, 1);
      },
    );

    test('revisão atual + catálogo presente não refaz o fetch', () async {
      // O setUp já inseriu 5 linhas com UUID; mais 5 atingem o mínimo de 10.
      await insertUuidRows(5, prefix: 'extra');
      catalogRevisionStore.revision = AppConstants.exerciseCatalogRevision;

      await repository.ensureCatalogSynced();

      verifyNever(() => catalogRemoteDataSource.fetchCatalog());
      expect(catalogRevisionStore.writes, 0);
    });

    test('falha no fetch não grava a revisão', () async {
      catalogRevisionStore.revision = AppConstants.exerciseCatalogRevision - 1;
      when(() => catalogRemoteDataSource.fetchCatalog())
          .thenThrow(Exception('offline'));

      await expectLater(repository.ensureCatalogSynced(), throwsException);

      expect(
        catalogRevisionStore.revision,
        AppConstants.exerciseCatalogRevision - 1,
      );
      expect(catalogRevisionStore.writes, 0);
    });
  });
}
