import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/workout/domain/entities/catalog_exercise.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';

/// Resultado da persistência local de uma ficha, usado pelo repositório
/// para enfileirar upserts e deletes correspondentes na `SyncQueueService`.
class TemplateLocalSaveResult {
  const TemplateLocalSaveResult({
    required this.savedTemplate,
    required this.deletedExerciseItemIds,
    required this.resolvedExerciseIds,
  });

  final WorkoutTemplateEntity savedTemplate;
  final List<String> deletedExerciseItemIds;
  final Map<String, String> resolvedExerciseIds;
}

class WorkoutTemplateLocalDataSource {
  WorkoutTemplateLocalDataSource(this._db);

  final AppDatabase _db;

  /// Observa todas as fichas do usuário [userId] com seus exercícios ordenados por `sort_order`.
  Stream<List<WorkoutTemplateEntity>> watchTemplates(String userId) {
    final query = (_db.select(_db.workoutTemplates)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .join([
          leftOuterJoin(
            _db.templateExercises,
            _db.templateExercises.templateId.equalsExp(_db.workoutTemplates.id),
          ),
          leftOuterJoin(
            _db.exerciseLibraryTable,
            _db.exerciseLibraryTable.id.equalsExp(
                  _db.templateExercises.exerciseId,
                ) |
                _db.exerciseLibraryTable.externalId.equalsExp(
                  _db.templateExercises.exerciseId,
                ),
          ),
        ]);

    return query.watch().map(_groupJoinedRows);
  }

  /// Busca uma ficha pelo [templateId] com seus exercícios ordenados.
  Future<WorkoutTemplateEntity?> getTemplateById(String templateId) async {
    final query = (_db.select(_db.workoutTemplates)
          ..where((t) => t.id.equals(templateId)))
        .join([
          leftOuterJoin(
            _db.templateExercises,
            _db.templateExercises.templateId.equalsExp(_db.workoutTemplates.id),
          ),
          leftOuterJoin(
            _db.exerciseLibraryTable,
            _db.exerciseLibraryTable.id.equalsExp(
                  _db.templateExercises.exerciseId,
                ) |
                _db.exerciseLibraryTable.externalId.equalsExp(
                  _db.templateExercises.exerciseId,
                ),
          ),
        ]);

    final rows = await query.get();
    final grouped = _groupJoinedRows(rows);
    return grouped.isEmpty ? null : grouped.first;
  }

  /// Salva/atualiza a ficha e seus exercícios em transação atômica no Drift.
  Future<TemplateLocalSaveResult> saveTemplate(
    WorkoutTemplateEntity template,
  ) async {
    final now = DateTime.now().toUtc();

    return _db.transaction(() async {
      final existingRows = await (_db.select(
        _db.templateExercises,
      )..where((e) => e.templateId.equals(template.id))).get();

      final incomingIds = template.exercises.map((e) => e.id).toSet();
      final deletedIds = existingRows
          .map((r) => r.id)
          .where((id) => !incomingIds.contains(id))
          .toList(growable: false);

      if (deletedIds.isNotEmpty) {
        await (_db.delete(
          _db.templateExercises,
        )..where((e) => e.id.isIn(deletedIds))).go();
      }

      await _db
          .into(_db.workoutTemplates)
          .insertOnConflictUpdate(
            WorkoutTemplatesCompanion.insert(
              id: template.id,
              remoteId: Value(template.id),
              userId: template.userId,
              name: template.name,
              description: Value(template.description),
              synced: const Value(false),
              updatedAt: now,
            ),
          );

      final resolvedExerciseIds = <String, String>{};
      final normalizedItems = <TemplateExerciseItem>[];

      for (var i = 0; i < template.exercises.length; i++) {
        final item = template.exercises[i];
        final resolvedExId = await _resolveLocalExerciseUuid(item.exerciseId);
        resolvedExerciseIds[item.id] = resolvedExId;

        final updatedItem = item.copyWith(
          templateId: template.id,
          exerciseId: resolvedExId,
          sortOrder: i,
        );
        normalizedItems.add(updatedItem);

        await _db
            .into(_db.templateExercises)
            .insertOnConflictUpdate(
              TemplateExercisesCompanion.insert(
                id: updatedItem.id,
                remoteId: Value(updatedItem.id),
                templateId: template.id,
                exerciseId: resolvedExId,
                sortOrder: Value(i),
                targetSets: Value(updatedItem.targetSets),
                targetReps: Value(updatedItem.targetReps),
                synced: const Value(false),
                updatedAt: now,
              ),
            );
      }

      return TemplateLocalSaveResult(
        savedTemplate: template.copyWith(
          exercises: normalizedItems,
          synced: false,
          updatedAt: now,
        ),
        deletedExerciseItemIds: deletedIds,
        resolvedExerciseIds: resolvedExerciseIds,
      );
    });
  }

  /// Remove localmente a ficha e seus `template_exercises` em transação.
  /// Retorna os IDs dos `template_exercises` que pertenciam à ficha.
  Future<List<String>> deleteTemplate(String templateId) {
    return _db.transaction(() async {
      final childRows = await (_db.select(
        _db.templateExercises,
      )..where((e) => e.templateId.equals(templateId))).get();
      final childIds = childRows.map((e) => e.id).toList(growable: false);

      await (_db.delete(
        _db.templateExercises,
      )..where((e) => e.templateId.equals(templateId))).go();

      await (_db.delete(
        _db.workoutTemplates,
      )..where((t) => t.id.equals(templateId))).go();

      // Limpa upserts pendentes da SyncQueue para os filhos e a própria ficha
      if (childIds.isNotEmpty) {
        await (_db.delete(_db.syncQueue)..where(
              (q) =>
                  q.targetTable.equals('template_exercises') &
                  q.recordId.isIn(childIds),
            ))
            .go();
      }
      await (_db.delete(_db.syncQueue)..where(
            (q) =>
                q.targetTable.equals('workout_templates') &
                q.recordId.equals(templateId),
          ))
          .go();

      return childIds;
    });
  }

  /// Observa o catálogo local (`exercise_library`) ordenado por nome.
  Stream<List<CatalogExercise>> watchCatalogExercises() {
    return (_db.select(
          _db.exerciseLibraryTable,
        )..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => CatalogExercise(
                  id: (r.remoteId != null && UuidV4.isValid(r.remoteId!))
                      ? r.remoteId!
                      : r.id,
                  externalId: r.externalId,
                  name: r.name,
                  primaryMuscles: r.primaryMuscles,
                  secondaryMuscles: r.secondaryMuscles,
                  equipment: r.equipment,
                  level: r.level,
                  imageUrls: r.imageUrls,
                ),
              )
              .toList(growable: false),
        );
  }

  /// Conta quantos exercícios no catálogo local já possuem UUID válido do Supabase.
  Future<int> countUuidCatalogExercises() async {
    final rows = await _db.select(_db.exerciseLibraryTable).get();
    return rows
        .where(
          (r) =>
              UuidV4.isValid(r.id) ||
              (r.remoteId != null && UuidV4.isValid(r.remoteId!)),
        )
        .length;
  }

  /// Atualiza o cache local do catálogo de exercícios (`exercise_library`),
  /// reconciliando por `external_id` caso já existam linhas com ID de slug.
  Future<void> upsertCatalogExercises(
    List<ExerciseLibraryTableCompanion> entries,
  ) async {
    await _db.transaction(() async {
      for (final entry in entries) {
        final extId = entry.externalId.value;
        final existingByExt = await (_db.select(
          _db.exerciseLibraryTable,
        )..where((e) => e.externalId.equals(extId))).getSingleOrNull();

        if (existingByExt != null && existingByExt.id != entry.id.value) {
          await (_db.delete(
            _db.exerciseLibraryTable,
          )..where((e) => e.id.equals(existingByExt.id))).go();
        }

        await _db
            .into(_db.exerciseLibraryTable)
            .insertOnConflictUpdate(entry);
      }
    });
  }

  Future<String> _resolveLocalExerciseUuid(String idOrExternalId) async {
    if (UuidV4.isValid(idOrExternalId)) return idOrExternalId;
    final row = await (_db.select(
      _db.exerciseLibraryTable,
    )..where(
          (e) =>
              e.id.equals(idOrExternalId) |
              e.externalId.equals(idOrExternalId),
        )).getSingleOrNull();
    if (row == null) return idOrExternalId;
    if (row.remoteId != null && UuidV4.isValid(row.remoteId!)) {
      return row.remoteId!;
    }
    return row.id;
  }

  List<WorkoutTemplateEntity> _groupJoinedRows(List<TypedResult> rows) {
    final templatesById = <String, WorkoutTemplate>{};
    final itemsByTemplateId = <String, Map<String, TemplateExerciseItem>>{};

    for (final row in rows) {
      final tpl = row.readTable(_db.workoutTemplates);
      templatesById.putIfAbsent(tpl.id, () => tpl);
      final mapForTemplate = itemsByTemplateId.putIfAbsent(
        tpl.id,
        () => <String, TemplateExerciseItem>{},
      );

      final itemRow = row.readTableOrNull(_db.templateExercises);
      if (itemRow != null && !mapForTemplate.containsKey(itemRow.id)) {
        final exerciseRow = row.readTableOrNull(_db.exerciseLibraryTable);
        String? firstImage;
        if (exerciseRow?.imageUrls != null &&
            exerciseRow!.imageUrls!.trim().isNotEmpty) {
          firstImage = exerciseRow.imageUrls!.split(',').first.trim();
        }
        mapForTemplate[itemRow.id] = TemplateExerciseItem(
          id: itemRow.id,
          templateId: itemRow.templateId,
          exerciseId: itemRow.exerciseId,
          exerciseName: exerciseRow?.name ?? itemRow.exerciseId,
          primaryMuscles: exerciseRow?.primaryMuscles,
          equipment: exerciseRow?.equipment,
          imageUrl: firstImage,
          sortOrder: itemRow.sortOrder,
          targetSets: itemRow.targetSets,
          targetReps: itemRow.targetReps,
        );
      }
    }

    return templatesById.values.map((tpl) {
      final items =
          itemsByTemplateId[tpl.id]?.values.toList() ?? <TemplateExerciseItem>[];
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return WorkoutTemplateEntity(
        id: tpl.id,
        userId: tpl.userId,
        name: tpl.name,
        description: tpl.description,
        exercises: items,
        synced: tpl.synced,
        updatedAt: tpl.updatedAt,
      );
    }).toList(growable: false);
  }
}
