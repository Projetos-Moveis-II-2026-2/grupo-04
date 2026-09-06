import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';

class _MockGateway extends Mock implements SyncRemoteGateway {}

void main() {
  late AppDatabase db;
  late _MockGateway gateway;
  late SyncQueueService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gateway = _MockGateway();
    service = SyncQueueService(
      db,
      gateway: gateway,
      retryScheduler: (_, _) {}, // sem timers reais nos testes
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertLocalSet(String id) {
    final now = DateTime.now();
    return db
        .into(db.exerciseSets)
        .insert(
          ExerciseSetsCompanion.insert(
            id: id,
            sessionId: 'session-1',
            exerciseId: 'exercise-1',
            setNumber: 1,
            weightKg: const Value(60.0),
            reps: const Value(10),
            updatedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<void> enqueueSetUpsert(String id) {
    return service.enqueue('exercise_sets', id, 'upsert', {
      'id': id,
      'session_id': 'session-1',
      'exercise_id': 'exercise-1',
      'set_number': 1,
    });
  }

  test('enqueue persiste item com payload JSON', () async {
    await enqueueSetUpsert('set-1');

    final rows = await db.select(db.syncQueue).get();

    expect(rows, hasLength(1));
    expect(rows.single.targetTable, 'exercise_sets');
    expect(rows.single.operation, 'upsert');
    expect(jsonDecode(rows.single.payload), containsPair('id', 'set-1'));
    expect(rows.single.retryCount, 0);
  });

  test('processQueue drena a fila em FIFO e marca synced localmente', () async {
    await insertLocalSet('set-1');
    await insertLocalSet('set-2');
    await enqueueSetUpsert('set-1');
    await enqueueSetUpsert('set-2');
    when(() => gateway.upsert(any(), any())).thenAnswer((_) async {});

    await service.processQueue();

    final payloads = verify(() => gateway.upsert('exercise_sets', captureAny()))
        .captured;
    expect(payloads, hasLength(2));
    expect((payloads[0] as Map<String, dynamic>)['id'], 'set-1');
    expect((payloads[1] as Map<String, dynamic>)['id'], 'set-2');

    expect(await db.select(db.syncQueue).get(), isEmpty);
    final sets = await db.select(db.exerciseSets).get();
    expect(sets.map((s) => s.synced), everyElement(isTrue));
  });

  test(
    'falha no remoto incrementa retryCount e mantém o item na fila',
    () async {
      await insertLocalSet('set-1');
      await enqueueSetUpsert('set-1');
      when(() => gateway.upsert(any(), any()))
          .thenThrow(const SocketException('offline'));

      await service.processQueue();

      final rows = await db.select(db.syncQueue).get();
      expect(rows, hasLength(1));
      expect(rows.single.retryCount, 1);

      final sets = await db.select(db.exerciseSets).get();
      expect(sets.single.synced, isFalse);
    },
  );

  test(
    'app morto no meio do flush: item ok sai, item com falha permanece',
    () async {
      await insertLocalSet('set-1');
      await insertLocalSet('set-2');
      await enqueueSetUpsert('set-1');
      await enqueueSetUpsert('set-2');

      var calls = 0;
      when(() => gateway.upsert(any(), any())).thenAnswer((_) async {
        calls++;
        if (calls == 2) throw const SocketException('offline no set-2');
      });

      await service.processQueue();

      final queue = await db.select(db.syncQueue).get();
      expect(queue, hasLength(1));
      expect(queue.single.recordId, 'set-2');
      expect(queue.single.retryCount, 1);

      final sets = await db.select(db.exerciseSets).get();
      expect(
        {for (final s in sets) s.id: s.synced},
        {'set-1': isTrue, 'set-2': isFalse},
      );
    },
  );

  test(
    'item excede maxRetries: sai da fila e dispara revisão manual',
    () async {
      var giveUpCalls = 0;
      service.onGiveUp = (_, _) => giveUpCalls++;

      await insertLocalSet('set-1');
      await enqueueSetUpsert('set-1');
      await (db.update(db.syncQueue)..where((q) => q.id.isNotNull())).write(
        const SyncQueueCompanion(retryCount: Value(5)),
      );
      when(() => gateway.upsert(any(), any()))
          .thenThrow(const SocketException('offline'));

      await service.processQueue();

      expect(giveUpCalls, 1);
      expect(await db.select(db.syncQueue).get(), isEmpty);
    },
  );
}
