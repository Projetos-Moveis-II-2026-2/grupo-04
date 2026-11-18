import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_option.dart';

class ExerciseLocalDataSource {
  static const int defaultInsertBatchSize = 200;

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
  /// de colunas, `LIKE` case-insensitive, `LIMIT` e `OFFSET`.
  ///
  /// Ordena por `name` com desempate por `id` para garantir paginação estável.
  Future<List<ExerciseOption>> searchByName(
    String query, {
    int limit = 30,
    int offset = 0,
  }) async {
    if (limit <= 0) return const [];
    final effectiveOffset = offset < 0 ? 0 : offset;
    final normalized = query.trim().toLowerCase();
    final table = _db.exerciseLibraryTable;
    final select = _db.selectOnly(table)
      ..addColumns([table.id, table.name])
      ..orderBy([OrderingTerm.asc(table.name), OrderingTerm.asc(table.id)])
      ..limit(limit, offset: effectiveOffset);

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

  /// Retorna `true` se o catálogo local já possui ao menos um exercício.
  Future<bool> hasExercises() async {
    final table = _db.exerciseLibraryTable;
    final row =
        await (_db.selectOnly(table)
              ..addColumns([table.id])
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Resolve nomes do catálogo local para uma coleção de chaves (`id`,
  /// `remoteId` ou `externalId`).
  Future<Map<String, String>> findNamesByKeys(Iterable<String> keys) async {
    final uniqueKeys = keys
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueKeys.isEmpty) return const {};

    final table = _db.exerciseLibraryTable;
    final select = _db.selectOnly(table)
      ..addColumns([table.id, table.remoteId, table.externalId, table.name])
      ..where(
        table.id.isIn(uniqueKeys) |
            table.remoteId.isIn(uniqueKeys) |
            table.externalId.isIn(uniqueKeys),
      );

    final rows = await select.get();
    final map = <String, String>{};
    for (final row in rows) {
      final name = row.read(table.name);
      if (name == null || name.isEmpty) continue;
      final id = row.read(table.id);
      final remoteId = row.read(table.remoteId);
      final externalId = row.read(table.externalId);
      if (id != null && id.isNotEmpty) map[id] = name;
      if (remoteId != null && remoteId.isNotEmpty) map[remoteId] = name;
      if (externalId != null && externalId.isNotEmpty) map[externalId] = name;
    }
    return map;
  }

  /// Insert or replace multiple exercises em lotes para evitar travamento da UI.
  Future<void> insertExercises(
    List<ExerciseLibraryTableCompanion> exercises, {
    int batchSize = defaultInsertBatchSize,
  }) async {
    if (exercises.isEmpty) return;
    final effectiveBatchSize = batchSize <= 0
        ? defaultInsertBatchSize
        : batchSize;

    for (var i = 0; i < exercises.length; i += effectiveBatchSize) {
      final end = (i + effectiveBatchSize).clamp(0, exercises.length);
      final chunk = exercises.sublist(i, end);
      await _db.batch((batch) {
        batch.insertAll(
          _db.exerciseLibraryTable,
          chunk,
          mode: InsertMode.insertOrReplace,
        );
      });
      if (end < exercises.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }
}
