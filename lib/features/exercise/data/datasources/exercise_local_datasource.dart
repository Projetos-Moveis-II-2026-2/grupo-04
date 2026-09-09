import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/exercise.dart';

class ExerciseLocalDataSource {
  final AppDatabase _db;

  ExerciseLocalDataSource(this._db);

  /// Helper to convert Drift generated class to Domain Entity
  Exercise _toEntity(ExerciseLibrary exercise) {
    return Exercise(
      id: exercise.id,
      remoteId: exercise.remoteId,
      externalId: exercise.externalId,
      name: exercise.name,
      force: exercise.force,
      level: exercise.level,
      mechanic: exercise.mechanic,
      equipment: exercise.equipment,
      primaryMuscles: exercise.primaryMuscles,
      secondaryMuscles: exercise.secondaryMuscles,
      instructions: exercise.instructions,
      category: exercise.category,
      imageUrls: exercise.imageUrls,
      synced: exercise.synced,
      updatedAt: exercise.updatedAt,
    );
  }

  /// Watch all exercises ordered by name
  Stream<List<Exercise>> watchAllExercises() {
    return (_db.select(_db.exerciseLibraryTable)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }

  /// Insert or replace multiple exercises
  Future<void> insertExercises(List<ExerciseLibraryTableCompanion> exercises) async {
    await _db.batch((batch) {
      batch.insertAll(
        _db.exerciseLibraryTable,
        exercises,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}
