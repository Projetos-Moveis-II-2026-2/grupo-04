@Tags(['integration'])
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';

import 'helpers/in_memory_db.dart';
import 'helpers/local_supabase.dart';
import 'helpers/test_env.dart';

class _FakeSyncGateway implements SyncRemoteGateway {
  _FakeSyncGateway({this.fail = false});

  final bool fail;
  final List<String> upsertedRecords = [];

  @override
  Future<void> upsert(String table, Map<String, dynamic> payload) async {
    if (fail) throw const SocketException('offline');
    upsertedRecords.add('$table:${payload['id']}');
  }

  @override
  Future<void> delete(String table, String id) async {
    if (fail) throw const SocketException('offline');
  }

  @override
  Future<void> markSynced(String table, String localId) async {}
}

class _LocalSet {
  const _LocalSet({
    required this.id,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
  });

  final String id;
  final int setNumber;
  final double weightKg;
  final int reps;
}

class _LocalWorkout {
  const _LocalWorkout({
    required this.sessionId,
    required this.startedAt,
    required this.completedAt,
    required this.sets,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<_LocalSet> sets;
}

Future<_LocalWorkout> _createLocalWorkout(
  AppDatabase db,
  String userId,
  String exerciseId, {
  int setCount = 2,
}) async {
  final startedAt = DateTime.now().toUtc();
  final completedAt = startedAt.add(const Duration(minutes: 45));
  final sessionId = randomUuid();
  final sets = List<_LocalSet>.generate(setCount, (index) {
    final setNumber = index + 1;
    return _LocalSet(
      id: randomUuid(),
      setNumber: setNumber,
      weightKg: 40.0 + (setNumber * 10),
      reps: 12 - index,
    );
  });

  await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          id: sessionId,
          userId: userId,
          startedAt: startedAt,
          completedAt: Value(completedAt),
          totalVolumeKg: Value(
            sets.fold<double>(
              0,
              (total, set) => total + (set.weightKg * set.reps),
            ),
          ),
          notes: const Value('Sessão criada offline (teste de integração #56)'),
          updatedAt: startedAt,
        ),
      );

  for (final set in sets) {
    await db
        .into(db.exerciseSets)
        .insert(
          ExerciseSetsCompanion.insert(
            id: set.id,
            sessionId: sessionId,
            exerciseId: exerciseId,
            setNumber: set.setNumber,
            weightKg: Value(set.weightKg),
            reps: Value(set.reps),
            updatedAt: startedAt,
            createdAt: startedAt,
          ),
        );
  }

  return _LocalWorkout(
    sessionId: sessionId,
    startedAt: startedAt,
    completedAt: completedAt,
    sets: sets,
  );
}

Future<void> _enqueueWorkout(
  SyncQueueService service,
  _LocalWorkout workout,
  String userId, {
  required String exerciseId,
}) async {
  final startedAt = workout.startedAt.toIso8601String();
  final completedAt = workout.completedAt.toIso8601String();
  final totalVolumeKg = workout.sets.fold<double>(
    0,
    (total, set) => total + (set.weightKg * set.reps),
  );

  await service.enqueue('workout_sessions', workout.sessionId, 'upsert', {
    'id': workout.sessionId,
    'user_id': userId,
    'started_at': startedAt,
    'completed_at': completedAt,
    'total_volume_kg': totalVolumeKg,
    'notes': 'Sessão criada offline (teste de integração #56)',
    'updated_at': startedAt,
  });

  for (final set in workout.sets) {
    await service.enqueue('exercise_sets', set.id, 'upsert', {
      'id': set.id,
      'session_id': workout.sessionId,
      'exercise_id': exerciseId,
      'set_number': set.setNumber,
      'weight_kg': set.weightKg,
      'reps': set.reps,
      'completed': true,
      'created_at': startedAt,
      'updated_at': startedAt,
    });
  }
}

SyncQueueService _createService(AppDatabase db, SyncRemoteGateway gateway) {
  return SyncQueueService(
    db,
    gateway: gateway,
    retryScheduler: (_, _) {}, // sem timers reais nos testes
  );
}

void main() {
  group('Drift em memória (sempre executa)', () {
    late AppDatabase db;

    setUp(() {
      db = createInMemoryDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('gateway falhando mantém a fila e incrementa retryCount', () async {
      final workout = await _createLocalWorkout(
        db,
        'offline-user',
        'exercise-offline',
      );
      final service = _createService(db, _FakeSyncGateway(fail: true));
      await _enqueueWorkout(
        service,
        workout,
        'offline-user',
        exerciseId: 'exercise-offline',
      );

      await service.processQueue();

      final queue = await (db.select(
        db.syncQueue,
      )..orderBy([(q) => OrderingTerm.asc(q.id)])).get();
      expect(queue, hasLength(workout.sets.length + 1));
      expect(queue.first.recordId, workout.sessionId);
      expect(queue.first.retryCount, 1);

      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions.single.synced, isFalse);
      final sets = await db.select(db.exerciseSets).get();
      expect(sets.map((set) => set.synced), everyElement(isFalse));
    });

    test(
      'gateway ok esvazia a fila e marca sessão e sets como synced',
      () async {
        final workout = await _createLocalWorkout(
          db,
          'offline-user',
          'exercise-offline',
        );
        final gateway = _FakeSyncGateway();
        final service = _createService(db, gateway);
        await _enqueueWorkout(
          service,
          workout,
          'offline-user',
          exerciseId: 'exercise-offline',
        );

        await service.processQueue();

        expect(await db.select(db.syncQueue).get(), isEmpty);
        expect(gateway.upsertedRecords, hasLength(workout.sets.length + 1));
        expect(
          gateway.upsertedRecords,
          contains('workout_sessions:${workout.sessionId}'),
        );

        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions.single.synced, isTrue);
        final sets = await db.select(db.exerciseSets).get();
        expect(sets, hasLength(workout.sets.length));
        expect(sets.map((set) => set.synced), everyElement(isTrue));
      },
    );
  });

  group('Supabase local', () {
    late LocalSupabase local;
    late TestUser user;

    setUp(() async {
      local = LocalSupabase();
      user = await local.createUser(prefix: 'sync');
    });

    tearDown(() async {
      await local.dispose();
    });

    test('autentica e cria sessão + sets no Postgres', () async {
      expect(user.client.auth.currentUser?.id, user.id);

      final profile = await user.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      expect(profile, isNotNull);

      final exerciseId = await local.firstExerciseId();
      final now = DateTime.now().toUtc();
      final sessionId = randomUuid();

      await user.client
          .from('workout_sessions')
          .insert({
            'id': sessionId,
            'user_id': user.id,
            'started_at': now.toIso8601String(),
            'completed_at': now
                .add(const Duration(minutes: 40))
                .toIso8601String(),
            'total_volume_kg': 480.0,
            'notes': 'Auth + sessão + sets (teste de integração #56)',
          })
          .select('id')
          .single();

      final setIds = [randomUuid(), randomUuid()];
      for (var index = 0; index < setIds.length; index++) {
        await user.client
            .from('exercise_sets')
            .insert({
              'id': setIds[index],
              'session_id': sessionId,
              'exercise_id': exerciseId,
              'set_number': index + 1,
              'weight_kg': 40.0 + (index * 5),
              'reps': 10 - index,
              'completed': true,
            })
            .select('id')
            .single();
      }

      final sessions = await user.client
          .from('workout_sessions')
          .select('id')
          .eq('id', sessionId);
      expect(sessions, hasLength(1));

      final sets = await user.client
          .from('exercise_sets')
          .select('id, set_number')
          .eq('session_id', sessionId)
          .order('set_number');
      expect(sets, hasLength(setIds.length));
      expect(sets.map((row) => row['id']), containsAll(setIds));
    });

    test(
      'drena a SyncQueue offline e persiste sessão + sets no Postgres',
      () async {
        final db = createInMemoryDatabase();
        addTearDown(db.close);

        final exerciseId = await local.firstExerciseId();
        final workout = await _createLocalWorkout(db, user.id, exerciseId);
        final service = _createService(db, SupabaseSyncGateway(user.client));

        await _enqueueWorkout(
          service,
          workout,
          user.id,
          exerciseId: exerciseId,
        );

        expect(
          await db.select(db.syncQueue).get(),
          hasLength(workout.sets.length + 1),
        );

        await service.processQueue();

        expect(await db.select(db.syncQueue).get(), isEmpty);

        final localSessions = await db.select(db.workoutSessions).get();
        expect(localSessions.single.synced, isTrue);

        final localSets = await db.select(db.exerciseSets).get();
        expect(localSets, hasLength(workout.sets.length));
        expect(localSets.map((set) => set.synced), everyElement(isTrue));

        final remoteSession = await user.client
            .from('workout_sessions')
            .select('id, total_volume_kg')
            .eq('id', workout.sessionId)
            .maybeSingle();
        expect(remoteSession, isNotNull);
        expect(remoteSession!['id'], workout.sessionId);

        final remoteSets = await user.client
            .from('exercise_sets')
            .select('id, set_number')
            .eq('session_id', workout.sessionId)
            .order('set_number');
        expect(remoteSets, hasLength(workout.sets.length));
        expect(
          remoteSets.map((row) => row['id']),
          containsAll(workout.sets.map((set) => set.id)),
        );
      },
    );
  }, skip: supabaseSkipReasonOrNull);
}
