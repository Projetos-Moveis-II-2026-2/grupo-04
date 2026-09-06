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
}
