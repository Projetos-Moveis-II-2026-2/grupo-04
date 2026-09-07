import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';

/// Snapshot das tabelas user-scoped vindas do cloud (linhas snake_case
/// exatamente como o PostgREST devolve).
class PullSnapshot {
  const PullSnapshot({
    required this.workoutTemplates,
    required this.workoutSessions,
    required this.exerciseSets,
    required this.waterIntake,
  });

  final List<Map<String, dynamic>> workoutTemplates;
  final List<Map<String, dynamic>> workoutSessions;
  final List<Map<String, dynamic>> exerciseSets;
  final List<Map<String, dynamic>> waterIntake;
}

/// Fonte remota do pull inicial (implementação em
/// `features/workout/data/datasources/supabase_workout_datasource.dart`).
abstract interface class CloudPullDataSource {
  Future<PullSnapshot> fetchAll();
}

/// Guarda a bandeira "pull inicial já executado" (implementação com
/// shared_preferences).
abstract interface class InitialPullStateStore {
  Future<bool> hasPulled();
  Future<void> markPulled();
}

/// Pull inicial: baixa as linhas do usuário e as aplica localmente com
/// dedup por `remoteId` e LWW por `updatedAt`.
///
/// - Registro remoto sem correspondente local → INSERT com `id = remoteId`,
///   `synced = true`.
/// - `remoteId` já existe localmente → vence o `updatedAt` mais novo
///   (remoto só sobrescreve se for mais novo).
/// - Registros criados offline (`remoteId` null) nunca são tocados: LWW só
///   se aplica quando o `remoteId` coincide.
/// - A bandeira evita refetch; aplicar o mesmo snapshot 2× também não
///   duplica (dedup por `remoteId`).
class InitialSyncService {
  InitialSyncService(
    this._db, {
    required this.dataSource,
    required this.stateStore,
  });

  final AppDatabase _db;
  final CloudPullDataSource dataSource;
  final InitialPullStateStore stateStore;

  Future<void> pullInitial() async {
    if (await stateStore.hasPulled()) return;
    final snapshot = await dataSource.fetchAll();
    await _db.transaction(() async {
      await _applyTemplates(snapshot.workoutTemplates);
      await _applySessions(snapshot.workoutSessions);
      await _applySets(snapshot.exerciseSets);
      await _applyWater(snapshot.waterIntake);
    });
    await stateStore.markPulled();
  }

  Future<void> _applyTemplates(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final remoteId = row['id'] as String;
      final remoteUpdated = DateTime.parse(row['updated_at'] as String);
      final existing = await (_db.select(
        _db.workoutTemplates,
      )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.workoutTemplates)
            .insert(
              WorkoutTemplatesCompanion.insert(
                id: remoteId,
                remoteId: Value(remoteId),
                userId: row['user_id'] as String,
                name: row['name'] as String,
                description: Value(row['description'] as String?),
                synced: const Value(true),
                updatedAt: remoteUpdated,
              ),
            );
      } else if (remoteUpdated.isAfter(existing.updatedAt)) {
        await (_db.update(
          _db.workoutTemplates,
        )..where((t) => t.remoteId.equals(remoteId))).write(
          WorkoutTemplatesCompanion(
            name: Value(row['name'] as String),
            description: Value(row['description'] as String?),
            synced: const Value(true),
            updatedAt: Value(remoteUpdated),
          ),
        );
      }
    }
  }

  Future<void> _applySessions(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final remoteId = row['id'] as String;
      final remoteUpdated = DateTime.parse(row['updated_at'] as String);
      final existing = await (_db.select(
        _db.workoutSessions,
      )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                id: remoteId,
                remoteId: Value(remoteId),
                userId: row['user_id'] as String,
                templateId: Value(row['template_id'] as String?),
                startedAt: DateTime.parse(row['started_at'] as String),
                completedAt: Value(_dtOrNull(row['completed_at'])),
                totalVolumeKg: Value(_doubleOrNull(row['total_volume_kg'])),
                notes: Value(row['notes'] as String?),
                synced: const Value(true),
                updatedAt: remoteUpdated,
              ),
            );
      } else if (remoteUpdated.isAfter(existing.updatedAt)) {
        await (_db.update(
          _db.workoutSessions,
        )..where((t) => t.remoteId.equals(remoteId))).write(
          WorkoutSessionsCompanion(
            templateId: Value(row['template_id'] as String?),
            completedAt: Value(_dtOrNull(row['completed_at'])),
            totalVolumeKg: Value(_doubleOrNull(row['total_volume_kg'])),
            notes: Value(row['notes'] as String?),
            synced: const Value(true),
            updatedAt: Value(remoteUpdated),
          ),
        );
      }
    }
  }

  Future<void> _applySets(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final remoteId = row['id'] as String;
      final remoteUpdated = DateTime.parse(row['updated_at'] as String);
      final existing = await (_db.select(
        _db.exerciseSets,
      )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.exerciseSets)
            .insert(
              ExerciseSetsCompanion.insert(
                id: remoteId,
                remoteId: Value(remoteId),
                sessionId: row['session_id'] as String,
                exerciseId: row['exercise_id'] as String,
                setNumber: row['set_number'] as int,
                weightKg: Value(_doubleOrNull(row['weight_kg'])),
                reps: Value(row['reps'] as int?),
                completed: Value(row['completed'] as bool? ?? false),
                synced: const Value(true),
                updatedAt: remoteUpdated,
                createdAt: DateTime.parse(row['created_at'] as String),
              ),
            );
      } else if (remoteUpdated.isAfter(existing.updatedAt)) {
        await (_db.update(
          _db.exerciseSets,
        )..where((t) => t.remoteId.equals(remoteId))).write(
          ExerciseSetsCompanion(
            setNumber: Value(row['set_number'] as int),
            weightKg: Value(_doubleOrNull(row['weight_kg'])),
            reps: Value(row['reps'] as int?),
            completed: Value(row['completed'] as bool? ?? false),
            synced: const Value(true),
            updatedAt: Value(remoteUpdated),
          ),
        );
      }
    }
  }

  Future<void> _applyWater(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final remoteId = row['id'] as String;
      final remoteUpdated = DateTime.parse(row['updated_at'] as String);
      final recordedAt = DateTime.parse(row['recorded_at'] as String);
      final existing = await (_db.select(
        _db.waterIntake,
      )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.waterIntake)
            .insert(
              WaterIntakeCompanion.insert(
                id: remoteId,
                remoteId: Value(remoteId),
                userId: row['user_id'] as String,
                amountMl: row['amount_ml'] as int,
                recordedAt: recordedAt,
                date:
                    row['date'] as String? ??
                    recordedAt.toIso8601String().substring(0, 10),
                synced: const Value(true),
                updatedAt: remoteUpdated,
              ),
            );
      } else if (remoteUpdated.isAfter(existing.updatedAt)) {
        await (_db.update(
          _db.waterIntake,
        )..where((t) => t.remoteId.equals(remoteId))).write(
          WaterIntakeCompanion(
            amountMl: Value(row['amount_ml'] as int),
            synced: const Value(true),
            updatedAt: Value(remoteUpdated),
          ),
        );
      }
    }
  }

  static DateTime? _dtOrNull(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static double? _doubleOrNull(dynamic value) =>
      value == null ? null : (value as num).toDouble();
}
