import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_option.dart';
import '../../domain/repositories/i_exercise_repository.dart';
import '../datasources/exercise_local_datasource.dart';
import '../datasources/exercise_remote_datasource_fake.dart';

class ExerciseRepositoryImpl implements IExerciseRepository {
  final ExerciseLocalDataSource _localDataSource;
  final ExerciseRemoteDataSourceFake _remoteDataSource;

  ExerciseRepositoryImpl(this._localDataSource, this._remoteDataSource);

  @override
  Stream<List<Exercise>> watchExercises() {
    return _localDataSource.watchAllExercises();
  }

  @override
  Future<List<ExerciseOption>> searchByName(String query, {int limit = 30}) {
    return _localDataSource.searchByName(query, limit: limit);
  }

  @override
  Future<void> syncExercises() async {
    try {
      // 1. Fetch from fake API
      final remoteExercises = await _remoteDataSource.fetchExercises();

      // 2. Map to Drift Companions
      final companions = remoteExercises.map((e) {
        return ExerciseLibraryTableCompanion(
          id: Value(e.id),
          remoteId: Value(e.remoteId),
          externalId: Value(e.externalId),
          name: Value(e.name),
          force: Value(e.force),
          level: Value(e.level),
          mechanic: Value(e.mechanic),
          equipment: Value(e.equipment),
          primaryMuscles: Value(e.primaryMuscles),
          secondaryMuscles: Value(e.secondaryMuscles),
          instructions: Value(e.instructions),
          category: Value(e.category),
          imageUrls: Value(e.imageUrls),
          synced: Value(e.synced),
          updatedAt: Value(e.updatedAt),
        );
      }).toList();

      // 3. Save to local DB (upsert)
      await _localDataSource.insertExercises(companions);
    } catch (e) {
      // In a real app, handle error and log
      debugPrint('Erro ao sincronizar exercícios: $e');
    }
  }
}
