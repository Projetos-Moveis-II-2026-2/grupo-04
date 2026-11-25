import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/workout/data/datasources/workout_session_local_datasource.dart';
import 'package:olimpus/features/workout/data/datasources/workout_template_local_datasource.dart';
import 'package:olimpus/features/workout/data/repositories/workout_session_repository_impl.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/usecases/workout_session_usecases.dart';

class _MockSyncGateway extends Mock implements SyncRemoteGateway {}

void main() {
  late AppDatabase db;
  late SyncQueueService syncQueue;
  late WorkoutSessionRepositoryImpl repository;
  late WorkoutTemplateEntity template;

  const userId = 'user-1';
  final benchId = UuidV4.generate();
  final squatId = UuidV4.generate();

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Gateway offline: tudo permanece na fila para inspeção.
    final gateway = _MockSyncGateway();
    when(() => gateway.upsert(any(), any())).thenThrow(Exception('offline'));
    when(() => gateway.delete(any(), any())).thenThrow(Exception('offline'));
    syncQueue = SyncQueueService(
      db,
      gateway: gateway,
      retryScheduler: (_, _) {},
    );
    repository = WorkoutSessionRepositoryImpl(
      localDataSource: WorkoutSessionLocalDataSource(db),
      syncQueueService: syncQueue,
    );

    final now = DateTime.now();
    for (final (id, name) in [
      (benchId, 'Supino reto'),
      (squatId, 'Agachamento'),
    ]) {
      await db
          .into(db.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: id,
              remoteId: Value(id),
              externalId: 'slug-$name',
              name: name,
              updatedAt: now,
            ),
          );
    }

    final templateId = UuidV4.generate();
    template = WorkoutTemplateEntity(
      id: templateId,
      userId: userId,
      name: 'Treino A',
      updatedAt: now,
      exercises: [
        TemplateExerciseItem(
          id: UuidV4.generate(),
          templateId: templateId,
          exerciseId: squatId,
          exerciseName: 'Agachamento',
          sortOrder: 0,
          targetSets: 2,
          targetReps: 8,
        ),
        TemplateExerciseItem(
          id: UuidV4.generate(),
          templateId: templateId,
          exerciseId: benchId,
          exerciseName: 'Supino reto',
          sortOrder: 1,
          targetSets: 3,
          targetReps: 10,
        ),
      ],
    );
    await WorkoutTemplateLocalDataSource(db).saveTemplate(template);
  });

  tearDown(() => db.close());

  Future<WorkoutSessionEntity> current(String id) async =>
      (await repository.watchSession(id).first)!;

  Future<List<SyncQueueEntry>> queue() =>
      (db.select(db.syncQueue)..orderBy([(q) => OrderingTerm.asc(q.id)])).get();

  test(
    'inicia sessão a partir da ficha com séries planejadas na ordem da ficha',
    () async {
      final id = await StartWorkoutSession(repository)(
        userId: userId,
        template: template,
      );
      final session = await current(id);

      expect(session.templateName, 'Treino A');
      expect(session.completedAt, isNull);
      expect(session.exercises.map((e) => e.exerciseName), [
        'Agachamento',
        'Supino reto',
      ]);
      expect(session.exercises[0].sets, hasLength(2));
      expect(session.exercises[1].sets, hasLength(3));
      expect(session.exercises[1].sets.first.reps, 10);
      expect(session.exercises[1].sets.first.weightKg, isNull);
      expect(session.exercises[1].previousSets, isEmpty);

      // Retomar: iniciar a mesma ficha de novo devolve a sessão em andamento.
      expect(
        await repository.startSession(userId: userId, template: template),
        id,
      );

      final entries = await queue();
      expect(entries.single.targetTable, 'workout_sessions');
    },
  );

  test(
    'Verificação #39: mesmo exercício em 2 sessões → contraste e histórico',
    () async {
      // ── Sessão 1 ──
      final s1 = await repository.startSession(
        userId: userId,
        template: template,
      );
      var session = await current(s1);
      final benchSets = session.exercises[1].sets;
      await repository.updateSet(
        benchSets[0].copyWith(weightKg: 60, reps: 10, completed: true),
      );
      await repository.updateSet(
        benchSets[1].copyWith(weightKg: 62.5, reps: 8, completed: true),
      );
      // Série 3 fica sem concluir → descartada ao concluir a sessão.
      await repository.completeSession(s1);

      final row1 = await (db.select(
        db.workoutSessions,
      )..where((s) => s.id.equals(s1))).getSingle();
      expect(row1.completedAt, isNotNull);
      expect(row1.totalVolumeKg, 60 * 10 + 62.5 * 8);
      final remaining = await (db.select(
        db.exerciseSets,
      )..where((s) => s.sessionId.equals(s1))).get();
      expect(remaining, hasLength(2));

      // ── Sessão 2 ──
      final s2 = await repository.startSession(
        userId: userId,
        template: template,
      );
      expect(s2, isNot(s1));
      session = await current(s2);
      final bench = session.exercises[1];

      // Contraste: carga anterior lado a lado por número de série.
      expect(bench.previousSets.map((s) => (s.weightKg, s.reps)), [
        (60.0, 10),
        (62.5, 8),
      ]);
      expect(bench.previousFor(1)!.weightKg, 60);
      expect(bench.previousFor(2)!.weightKg, 62.5);
      // Pré-preenchimento a partir da última sessão.
      expect(bench.sets[0].weightKg, 60);
      expect(bench.sets[1].weightKg, 62.5);
      expect(bench.sets[2].weightKg, 62.5);
      // Agachamento não foi treinado na sessão 1.
      expect(session.exercises[0].previousSets, isEmpty);

      await repository.updateSet(
        bench.sets[0].copyWith(weightKg: 65, reps: 10, completed: true),
      );
      await repository.completeSession(s2);

      // Histórico: a próxima sessão compara com a sessão 2, não com a 1.
      final s3 = await repository.startSession(
        userId: userId,
        template: template,
      );
      final next = (await current(s3)).exercises[1];
      expect(next.previousSets.map((s) => s.weightKg), [65.0]);

      final completed = await (db.select(
        db.workoutSessions,
      )..where((s) => s.completedAt.isNotNull())).get();
      expect(completed, hasLength(2));
    },
  );

  test('fila de sync: dedup por série, delete ao desmarcar, sessão antes das séries', () async {
    final id = await repository.startSession(
      userId: userId,
      template: template,
    );
    final set = (await current(id)).exercises[1].sets.first;

    await repository.updateSet(set.copyWith(weightKg: 40, completed: true));
    await repository.updateSet(set.copyWith(weightKg: 42.5, completed: true));
    await repository.updateSet(set.copyWith(weightKg: 45, completed: true));

    var entries = await queue();
    expect(entries.map((e) => e.targetTable), [
      'workout_sessions',
      'exercise_sets',
    ]);
    final payload = jsonDecode(entries.last.payload) as Map<String, dynamic>;
    expect(payload['weight_kg'], 45);
    expect(payload['session_id'], id);
    expect(entries.last.operation, 'upsert');

    await repository.updateSet(set.copyWith(weightKg: 45, completed: false));
    entries = await queue();
    expect(entries.last.operation, 'delete');
    expect(
      entries.where((e) => e.targetTable == 'exercise_sets'),
      hasLength(1),
    );

    final local = await (db.select(
      db.exerciseSets,
    )..where((s) => s.id.equals(set.id))).getSingle();
    expect(local.synced, isFalse);

    await repository.completeSession(id);
    entries = await queue();
    expect(entries.first.targetTable, 'workout_sessions');
    final last = jsonDecode(entries.last.payload) as Map<String, dynamic>;
    expect(entries.last.targetTable, 'workout_sessions');
    expect(last['completed_at'], isNotNull);
  });

  test('adicionar série copia peso/reps da última', () async {
    final id = await repository.startSession(
      userId: userId,
      template: template,
    );
    final squat = (await current(id)).exercises[0];
    await repository.updateSet(squat.sets.last.copyWith(weightKg: 100));
    await AddSessionSet(repository)(sessionId: id, exerciseId: squatId);

    final sets = (await current(id)).exercises[0].sets;
    expect(sets, hasLength(3));
    expect(sets.last.setNumber, 3);
    expect(sets.last.weightKg, 100);
    expect(sets.last.reps, 8);
    expect(sets.last.completed, isFalse);
  });

  test('usecases validam entrada', () {
    expect(
      () => StartWorkoutSession(repository)(
        userId: userId,
        template: template.copyWith(exercises: const []),
      ),
      throwsArgumentError,
    );
    expect(
      () => UpdateSessionSet(repository)(
        const SessionSet(
          id: 'x',
          sessionId: 's',
          exerciseId: 'e',
          setNumber: 1,
          weightKg: -1,
        ),
      ),
      throwsArgumentError,
    );
  });
}
