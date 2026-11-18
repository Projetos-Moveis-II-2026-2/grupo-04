import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_option.dart';

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

  /// Busca opções leves (`id` e `name`) diretamente no SQLite usando projeção
  /// de colunas, `LIKE` case-insensitive e `LIMIT`.
  Future<List<ExerciseOption>> searchByName(
    String query, {
    int limit = 30,
  }) async {
    if (limit <= 0) return const [];
    final normalized = query.trim().toLowerCase();
    final table = _db.exerciseLibraryTable;
    final select = _db.selectOnly(table)
      ..addColumns([table.id, table.name])
      ..orderBy([OrderingTerm.asc(table.name)])
      ..limit(limit);

    if (normalized.isNotEmpty) {
      final escaped = _escapeLikePattern(normalized);
      select.where(table.name.lower().like('%$escaped%', escapeChar: r'\'));
    }

    final rows = await select.get();
    return rows
        .map(
          (row) => ExerciseOption(
            id: row.read(table.id)!,
            name: row.read(table.name)!,
          ),
        )
        .toList(growable: false);
  }

  static String _escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// Insert or replace multiple exercises
  Future<void> insertExercises(
    List<ExerciseLibraryTableCompanion> exercises,
  ) async {
    await _db.batch((batch) {
      batch.insertAll(
        _db.exerciseLibraryTable,
        exercises,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}
