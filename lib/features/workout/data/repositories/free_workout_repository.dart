import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/utils/uuid.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/usecases/compute_volume.dart';

class FreeWorkoutRepository {
  FreeWorkoutRepository(this._db);

  final AppDatabase _db;

  Stream<int> watchCompletedSetCount(String userId) {
    final sessions = _db.workoutSessions;
    final sets = _db.exerciseSets;
    final count = sets.id.count();
    final query =
        _db.selectOnly(sets).join([
            innerJoin(sessions, sessions.id.equalsExp(sets.sessionId)),
          ])
          ..addColumns([count])
          ..where(_activeWorkout(userId) & sets.completed.equals(true));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> completeSet({
    required String userId,
    required String exerciseId,
    required int reps,
    required double weightKg,
  }) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final session =
          await (_db.select(_db.workoutSessions)
                ..where((_) => _activeWorkout(userId))
                ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
                ..limit(1))
              .getSingleOrNull();
      final sessionId = session?.id ?? generateUuid();
      if (session == null) {
        await _db
            .into(_db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                id: sessionId,
                userId: userId,
                startedAt: now,
                updatedAt: now,
              ),
            );
      }

      final lastSet =
          await (_db.select(_db.exerciseSets)
                ..where(
                  (row) =>
                      row.sessionId.equals(sessionId) &
                      row.exerciseId.equals(exerciseId),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.setNumber)])
                ..limit(1))
              .getSingleOrNull();
      await _db
          .into(_db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: generateUuid(),
              sessionId: sessionId,
              exerciseId: exerciseId,
              setNumber: (lastSet?.setNumber ?? 0) + 1,
              weightKg: Value(weightKg),
              reps: Value(reps),
              completed: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  /// Conclui o treino livre gravando `completed_at` e `total_volume_kg`
  /// (mesma regra da execução por ficha, para o histórico somar certo).
  Future<void> finishWorkout(String userId) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final active = await (_db.select(
        _db.workoutSessions,
      )..where((_) => _activeWorkout(userId))).get();

      for (final session in active) {
        final sets = await (_db.select(
          _db.exerciseSets,
        )..where((s) => s.sessionId.equals(session.id))).get();
        final volume = const ComputeVolume().ofSets(
          sets.map(
            (s) => SessionSet(
              id: s.id,
              sessionId: s.sessionId,
              exerciseId: s.exerciseId,
              setNumber: s.setNumber,
              weightKg: s.weightKg,
              reps: s.reps,
              completed: s.completed,
            ),
          ),
        );
        await (_db.update(
          _db.workoutSessions,
        )..where((s) => s.id.equals(session.id))).write(
          WorkoutSessionsCompanion(
            completedAt: Value(now),
            totalVolumeKg: Value(volume),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Expression<bool> _activeWorkout(String userId) {
    final sessions = _db.workoutSessions;
    return sessions.userId.equals(userId) &
        sessions.templateId.isNull() &
        sessions.remoteId.isNull() &
        sessions.completedAt.isNull();
  }
}
