import 'dart:async';

import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/workout/data/datasources/exercise_catalog_remote_datasource.dart';
import 'package:olimpus/features/workout/data/datasources/workout_template_local_datasource.dart';
import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';

class WorkoutTemplateRepositoryImpl implements IWorkoutTemplateRepository {
  WorkoutTemplateRepositoryImpl({
    required this._localDataSource,
    required this._syncQueueService,
    this._catalogRemoteDataSource,
  });

  final WorkoutTemplateLocalDataSource _localDataSource;
  final SyncQueueService _syncQueueService;
  final IExerciseCatalogRemoteDataSource? _catalogRemoteDataSource;

  @override
  Stream<List<WorkoutTemplateEntity>> watchTemplates(String userId) {
    return _localDataSource.watchTemplates(userId);
  }

  @override
  Future<WorkoutTemplateEntity?> getTemplateById(String templateId) {
    return _localDataSource.getTemplateById(templateId);
  }

  @override
  Future<void> saveTemplate(WorkoutTemplateEntity template) async {
    final result = await _localDataSource.saveTemplate(template);
    final saved = result.savedTemplate;

    // 1. Enfileira o upsert da ficha pai (workout_templates) primeiro por conta da FK/RLS
    await _syncQueueService.enqueue(
      'workout_templates',
      saved.id,
      'upsert',
      <String, dynamic>{
        'id': saved.id,
        'user_id': saved.userId,
        'name': saved.name,
        'description': saved.description,
        'updated_at': saved.updatedAt.toUtc().toIso8601String(),
      },
    );

    // 2. Enfileira deleções de exercícios que foram removidos na edição da ficha
    for (final deletedId in result.deletedExerciseItemIds) {
      await _syncQueueService.enqueue(
        'template_exercises',
        deletedId,
        'delete',
        <String, dynamic>{'id': deletedId},
      );
    }

    // 3. Enfileira upserts dos exercícios da ficha preservando sort_order, target_sets e target_reps
    for (final item in saved.exercises) {
      var remoteExerciseId = item.exerciseId;
      if (!UuidV4.isValid(remoteExerciseId) &&
          _catalogRemoteDataSource != null) {
        try {
          final resolved = await _catalogRemoteDataSource.resolveExerciseUuid(
            remoteExerciseId,
          );
          if (resolved != null && UuidV4.isValid(resolved)) {
            remoteExerciseId = resolved;
          }
        } on Object {
          // Offline ou falha de rede: mantém o ID atual na fila
        }
      }

      await _syncQueueService.enqueue(
        'template_exercises',
        item.id,
        'upsert',
        <String, dynamic>{
          'id': item.id,
          'template_id': saved.id,
          'exercise_id': remoteExerciseId,
          'sort_order': item.sortOrder,
          'target_sets': item.targetSets,
          'target_reps': item.targetReps,
        },
      );
    }

    unawaited(_tryFlushQueue());
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    await _localDataSource.deleteTemplate(templateId);

    // No Postgres, `template_exercises.template_id` possui ON DELETE CASCADE.
    await _syncQueueService.enqueue(
      'workout_templates',
      templateId,
      'delete',
      <String, dynamic>{'id': templateId},
    );

    unawaited(_tryFlushQueue());
  }

  @override
  Stream<List<CatalogExercise>> watchCatalogExercises() {
    return _localDataSource.watchCatalogExercises();
  }

  @override
  Future<void> ensureCatalogSynced() async {
    if (_catalogRemoteDataSource == null) return;
    final count = await _localDataSource.countUuidCatalogExercises();
    if (count >= 10) return;

    final entries = await _catalogRemoteDataSource.fetchCatalog();
    if (entries.isNotEmpty) {
      await _localDataSource.upsertCatalogExercises(entries);
    }
  }

  Future<void> _tryFlushQueue() async {
    try {
      await _syncQueueService.processQueue();
    } on Object {
      // Falha silenciosa: o auto-processor retenta ao reconectar.
    }
  }
}
