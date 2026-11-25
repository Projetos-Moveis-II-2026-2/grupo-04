import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:olimpus/features/workout/data/datasources/workout_session_local_datasource.dart';
import 'package:olimpus/features/workout/data/datasources/workout_template_local_datasource.dart';
import 'package:olimpus/features/workout/data/repositories/free_workout_repository.dart';
import 'package:olimpus/features/workout/data/repositories/workout_session_repository_impl.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/usecases/compute_volume.dart';

class _MockSyncGateway extends Mock implements SyncRemoteGateway {}

/// Issue #40 — volume total da sessão (Σ peso × reps) por exercício e treino.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepositoryImpl repository;
  late WorkoutTemplateEntity template;

  const userId = 'user-1';
  final exerciseIds = List<String>.generate(3, (_) => UuidV4.generate());

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final gateway = _MockSyncGateway();
    when(() => gateway.upsert(any(), any())).thenThrow(Exception('offline'));
    repository = WorkoutSessionRepositoryImpl(
      localDataSource: WorkoutSessionLocalDataSource(db),
      syncQueueService: SyncQueueService(
        db,
        gateway: gateway,
        retryScheduler: (_, _) {},
      ),
    );

    final now = DateTime.now();
    const names = ['Agachamento', 'Supino reto', 'Remada curvada'];
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: exerciseIds[i],
              remoteId: Value(exerciseIds[i]),
              externalId: 'slug-$i',
              name: names[i],
              updatedAt: now,
            ),
          );
    }
    final templateId = UuidV4.generate();
    template = WorkoutTemplateEntity(
      id: templateId,
      userId: userId,
      name: 'Treino ABC',
      updatedAt: now,
      exercises: [
        for (var i = 0; i < 3; i++)
          TemplateExerciseItem(
            id: UuidV4.generate(),
            templateId: templateId,
            exerciseId: exerciseIds[i],
            exerciseName: names[i],
            sortOrder: i,
            targetSets: 3,
            targetReps: 10,
          ),
      ],
    );
    await WorkoutTemplateLocalDataSource(db).saveTemplate(template);
  });

  tearDown(() => db.close());

  test(
    'Verificação #40: treino com 3 exercícios → somatórios na tela e no banco',
    () async {
      final id = await repository.startSession(
        userId: userId,
        template: template,
      );
      var session = (await repository.watchSession(id).first)!;

      // Agachamento: 100×5 + 100×5 + 105×4 = 1420
      final squat = session.exercises[0].sets;
      await repository.updateSet(
        squat[0].copyWith(weightKg: 100, reps: 5, completed: true),
      );
      await repository.updateSet(
        squat[1].copyWith(weightKg: 100, reps: 5, completed: true),
      );
      await repository.updateSet(
        squat[2].copyWith(weightKg: 105, reps: 4, completed: true),
      );
      // Supino: 62.5×8 + 60×10 = 1100 (3ª série não concluída não conta)
      final bench = session.exercises[1].sets;
      await repository.updateSet(
        bench[0].copyWith(weightKg: 62.5, reps: 8, completed: true),
      );
      await repository.updateSet(
        bench[1].copyWith(weightKg: 60, reps: 10, completed: true),
      );
      await repository.updateSet(bench[2].copyWith(weightKg: 200, reps: 10));
      // Remada: 40×12 = 480
      final row = session.exercises[2].sets;
      await repository.updateSet(
        row[0].copyWith(weightKg: 40, reps: 12, completed: true),
      );

      // ── Tela (tempo real): o mesmo cálculo que a página usa ──
      session = (await repository.watchSession(id).first)!;
      final live = const ComputeVolume()(session.exercises);
      expect(live.of(exerciseIds[0]), 1420);
      expect(live.of(exerciseIds[1]), 1100);
      expect(live.of(exerciseIds[2]), 480);
      expect(live.total, 3000);

      await repository.completeSession(id);

      // ── Banco: total_volume_kg = Σ peso × reps das séries gravadas ──
      final saved = await (db.select(
        db.workoutSessions,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(saved.totalVolumeKg, 3000);

      final sets = await (db.select(
        db.exerciseSets,
      )..where((s) => s.sessionId.equals(id))).get();
      final dbSum = sets.fold<double>(
        0,
        (sum, s) => sum + s.weightKg! * s.reps!,
      );
      expect(dbSum, saved.totalVolumeKg);
      expect(sets.every((s) => s.completed), isTrue);

      // Payload de sync leva o mesmo total.
      final queued =
          await (db.select(db.syncQueue)
                ..where((q) => q.targetTable.equals('workout_sessions'))
                ..orderBy([(q) => OrderingTerm.desc(q.id)])
                ..limit(1))
              .getSingle();
      expect(
        (jsonDecode(queued.payload) as Map<String, dynamic>)['total_volume_kg'],
        3000,
      );
    },
  );

  test(
    'consistência com o histórico: Progresso soma o volume das sessões',
    () async {
      Future<void> train(double kg) async {
        final id = await repository.startSession(
          userId: userId,
          template: template,
        );
        final s = (await repository.watchSession(id).first)!;
        await repository.updateSet(
          s.exercises[0].sets[0].copyWith(
            weightKg: kg,
            reps: 10,
            completed: true,
          ),
        );
        await repository.completeSession(id);
      }

      await train(50); // 500
      await train(60); // 600

      // Treino livre também grava total_volume_kg ao concluir.
      final free = FreeWorkoutRepository(db);
      await free.completeSet(
        userId: userId,
        exerciseId: exerciseIds[2],
        reps: 10,
        weightKg: 30,
      );
      await free.completeSet(
        userId: userId,
        exerciseId: exerciseIds[2],
        reps: 8,
        weightKg: 35,
      );
      await free.finishWorkout(userId);

      final freeSession = await (db.select(
        db.workoutSessions,
      )..where((s) => s.templateId.isNull())).getSingle();
      expect(freeSession.completedAt, isNotNull);
      expect(freeSession.totalVolumeKg, 300 + 280);

      final summary = await ProgressRepositoryImpl(db: db)
          .watchMonthlySummary(userId, DateTime.now())
          .first;
      expect(summary.workoutCount, 3);
      expect(summary.totalVolumeKg, 500 + 600 + 580);
    },
  );
}
