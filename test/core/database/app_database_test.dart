import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('abre o banco, insere e lê exercise_set', () async {
    final now = DateTime.now();

    await db
        .into(db.exerciseSets)
        .insert(
          ExerciseSetsCompanion.insert(
            id: 'set-1',
            sessionId: 'session-1',
            exerciseId: 'exercise-1',
            setNumber: 1,
            weightKg: const Value(60.0),
            reps: const Value(10),
            updatedAt: now,
            createdAt: now,
          ),
        );

    final rows = await db.select(db.exerciseSets).get();

    expect(rows, hasLength(1));
    expect(rows.first.weightKg, 60.0);
    expect(rows.first.reps, 10);
    expect(rows.first.completed, isFalse);
    expect(rows.first.synced, isFalse);
  });

  test('insere em sync_queue', () async {
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            targetTable: 'exercise_sets',
            recordId: 'set-1',
            operation: 'upsert',
            payload: '{"id":"set-1"}',
            createdAt: DateTime.now(),
          ),
        );

    final rows = await db.select(db.syncQueue).get();

    expect(rows, hasLength(1));
    expect(rows.first.operation, 'upsert');
    expect(rows.first.retryCount, 0);
  });

  test(
    'migração v1 -> v2 limpa exercise_library e preserva exercise_sets',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('olimpus_db_mig_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/test.sqlite');
      final now = DateTime(2026, 9, 16);

      // Popula banco simulando estado na versão 1.
      final dbV1 = AppDatabase(NativeDatabase(dbFile));
      await dbV1
          .into(dbV1.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: 'Barbell_Squat',
              externalId: 'Barbell_Squat',
              name: 'Barbell Squat',
              updatedAt: now,
            ),
          );
      await dbV1
          .into(dbV1.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 'set-user-1',
              sessionId: 'session-1',
              exerciseId: 'Barbell_Squat',
              setNumber: 1,
              weightKg: const Value(100.0),
              reps: const Value(5),
              updatedAt: now,
              createdAt: now,
            ),
          );
      await dbV1.customStatement('PRAGMA user_version = 1');
      await dbV1.close();

      // Reabre na versão 2 e executa onUpgrade.
      final dbV2 = AppDatabase(NativeDatabase(dbFile));
      addTearDown(dbV2.close);

      final libraryRows = await dbV2.select(dbV2.exerciseLibraryTable).get();
      final userSets = await dbV2.select(dbV2.exerciseSets).get();

      expect(dbV2.schemaVersion, 2);
      expect(libraryRows, isEmpty);
      expect(userSets, hasLength(1));
      expect(userSets.single.id, 'set-user-1');
      expect(userSets.single.exerciseId, 'Barbell_Squat');
      expect(userSets.single.weightKg, 100.0);
    },
  );
}
