import 'dart:async';

import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/features/workout/data/datasources/workout_session_local_datasource.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_session_repository.dart';

/// Offline-first: grava no Drift (synced: false) e enfileira na SyncQueue.
///
/// Só séries concluídas sobem para o Supabase (lá `weight_kg`/`reps` são
/// NOT NULL); desmarcar uma série enfileira o delete remoto.
class WorkoutSessionRepositoryImpl implements IWorkoutSessionRepository {
  WorkoutSessionRepositoryImpl({
    required this._localDataSource,
    required this._syncQueueService,
  });

  static const _sessionsTable = 'workout_sessions';
  static const _setsTable = 'exercise_sets';

  final WorkoutSessionLocalDataSource _localDataSource;
  final SyncQueueService _syncQueueService;

  @override
  Future<String> startSession({
    required String userId,
    required WorkoutTemplateEntity template,
  }) async {
    final active = await _localDataSource.findActiveSession(
      userId: userId,
      templateId: template.id,
    );
    if (active != null) return active.id;

    final created = await _localDataSource.createSessionFromTemplate(
      userId: userId,
      template: template,
    );
    // A sessão sobe antes das séries (FK exercise_sets.session_id).
    await _enqueueSession(created.session);
    unawaited(_tryFlushQueue());
    return created.session.id;
  }

  @override
  Stream<WorkoutSessionEntity?> watchSession(String sessionId) =>
      _localDataSource.watchSession(sessionId);

  @override
  Future<void> updateSet(SessionSet set) async {
    final saved = await _localDataSource.updateSet(set);
    await _localDataSource.clearPendingSync(_setsTable, saved.id);
    if (saved.completed) {
      await _syncQueueService.enqueue(
        _setsTable,
        saved.id,
        'upsert',
        _setPayload(saved),
      );
    } else {
      await _syncQueueService.enqueue(
        _setsTable,
        saved.id,
        'delete',
        <String, dynamic>{'id': saved.id},
      );
    }
    unawaited(_tryFlushQueue());
  }

  @override
  Future<void> addSet({
    required String sessionId,
    required String exerciseId,
  }) async {
    // Série nova nasce não concluída: nada a sincronizar ainda.
    await _localDataSource.addSet(sessionId: sessionId, exerciseId: exerciseId);
  }

  @override
  Future<void> completeSession(String sessionId) async {
    final session = await _localDataSource.completeSession(sessionId);
    // Não deduplica a sessão: o upsert inicial precisa continuar à frente
    // das séries na fila FIFO.
    await _enqueueSession(session);
    unawaited(_tryFlushQueue());
  }

  Future<void> _enqueueSession(WorkoutSession s) {
    return _syncQueueService.enqueue(
      _sessionsTable,
      s.id,
      'upsert',
      <String, dynamic>{
        'id': s.id,
        'user_id': s.userId,
        'template_id': s.templateId,
        'started_at': s.startedAt.toUtc().toIso8601String(),
        'completed_at': s.completedAt?.toUtc().toIso8601String(),
        'total_volume_kg': s.totalVolumeKg,
        'updated_at': s.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Map<String, dynamic> _setPayload(ExerciseSet s) => <String, dynamic>{
    'id': s.id,
    'session_id': s.sessionId,
    'exercise_id': s.exerciseId,
    'set_number': s.setNumber,
    'weight_kg': s.weightKg ?? 0,
    'reps': s.reps ?? 0,
    'completed': s.completed,
    'updated_at': s.updatedAt.toUtc().toIso8601String(),
  };

  Future<void> _tryFlushQueue() async {
    try {
      await _syncQueueService.processQueue();
    } on Object {
      // Falha silenciosa: o auto-processor retenta ao reconectar.
    }
  }
}
