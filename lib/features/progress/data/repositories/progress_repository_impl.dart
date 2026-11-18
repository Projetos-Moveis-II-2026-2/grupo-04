import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:olimpus/core/database/app_database.dart';

import '../../domain/entities/exercise_load_point.dart';
import '../../domain/entities/monthly_workout_summary.dart';
import '../../domain/entities/user_exercise_summary.dart';
import '../../domain/repositories/i_progress_repository.dart';
import '../../domain/utils/calendar_utils.dart';

/// Implementação do repositório de progresso e evolução sobre o Drift (SQLite local).
///
/// Todas as consultas são estritamente de leitura sobre [WorkoutSessions],
/// [ExerciseSets] e [ExerciseLibraryTable], respeitando o isolamento do fluxo de treino.
class ProgressRepositoryImpl implements IProgressRepository {
  final AppDatabase db;
  final DateTime Function() _now;

  ProgressRepositoryImpl({required this.db, DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  static const String demoNotesMarker = 'seed-demo';

  @override
  Stream<List<UserExerciseSummary>> watchUserExercisesWithLogs(String userId) {
    final query = db.select(db.workoutSessions).join([
      innerJoin(
        db.exerciseSets,
        db.exerciseSets.sessionId.equalsExp(db.workoutSessions.id),
      ),
      leftOuterJoin(
        db.exerciseLibraryTable,
        db.exerciseLibraryTable.id.equalsExp(db.exerciseSets.exerciseId) |
            db.exerciseLibraryTable.remoteId.equalsExp(
              db.exerciseSets.exerciseId,
            ) |
            db.exerciseLibraryTable.externalId.equalsExp(
              db.exerciseSets.exerciseId,
            ),
      ),
    ])..where(db.workoutSessions.userId.equals(userId));

    return query.watch().map((rows) {
      final Map<String, UserExerciseSummary> exercisesMap = {};

      for (final row in rows) {
        final set = row.readTable(db.exerciseSets);
        final library = row.readTableOrNull(db.exerciseLibraryTable);

        // Chave canônica: usa o ID da biblioteca se disponível, ou o exerciseId da série
        final canonicalId = library?.id ?? set.exerciseId;

        if (!exercisesMap.containsKey(canonicalId)) {
          final name = library?.name ?? 'Exercício (${set.exerciseId})';
          exercisesMap[canonicalId] = UserExerciseSummary(
            exerciseId: canonicalId,
            name: name,
          );
        }
      }

      final list = exercisesMap.values.toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Stream<List<ExerciseLoadPoint>> watchExerciseLoadProgression({
    required String userId,
    required String exerciseId,
  }) {
    final query =
        db.select(db.workoutSessions).join([
            innerJoin(
              db.exerciseSets,
              db.exerciseSets.sessionId.equalsExp(db.workoutSessions.id),
            ),
            leftOuterJoin(
              db.exerciseLibraryTable,
              db.exerciseLibraryTable.id.equalsExp(db.exerciseSets.exerciseId) |
                  db.exerciseLibraryTable.remoteId.equalsExp(
                    db.exerciseSets.exerciseId,
                  ) |
                  db.exerciseLibraryTable.externalId.equalsExp(
                    db.exerciseSets.exerciseId,
                  ),
            ),
          ])
          ..where(
            db.workoutSessions.userId.equals(userId) &
                db.exerciseSets.completed.equals(true) &
                db.exerciseSets.weightKg.isNotNull(),
          )
          ..orderBy([
            OrderingTerm(
              expression: db.workoutSessions.startedAt,
              mode: OrderingMode.asc,
            ),
          ]);

    return query.watch().map((rows) {
      final Map<String, ({DateTime date, double maxWeight})> sessionLoads = {};

      for (final row in rows) {
        final session = row.readTable(db.workoutSessions);
        final set = row.readTable(db.exerciseSets);
        final library = row.readTableOrNull(db.exerciseLibraryTable);

        // Verifica se a série corresponde ao exerciseId selecionado
        // considerando ID local, remoteId e externalId
        final matches =
            set.exerciseId == exerciseId ||
            (library != null &&
                (library.id == exerciseId ||
                    library.remoteId == exerciseId ||
                    library.externalId == exerciseId));

        if (!matches) continue;

        final weight = set.weightKg ?? 0.0;
        if (weight <= 0) continue;

        final current = sessionLoads[session.id];
        if (current == null || weight > current.maxWeight) {
          sessionLoads[session.id] = (
            date: session.startedAt,
            maxWeight: weight,
          );
        }
      }

      final points = sessionLoads.entries.map((entry) {
        return ExerciseLoadPoint(
          sessionId: entry.key,
          date: entry.value.date,
          maxWeightKg: entry.value.maxWeight,
        );
      }).toList();

      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    });
  }

  @override
  Future<void> seedDemoData(String userId) async {
    // Salvaguarda absoluta: nunca executar fora de debug
    if (!kDebugMode) return;

    final now = _now();

    // Obtém exercícios da biblioteca ou insere 2 canônicos caso esteja vazia
    var exercises = await (db.select(db.exerciseLibraryTable)..limit(2)).get();
    if (exercises.isEmpty) {
      final benchId = 'demo-ex-bench';
      final squatId = 'demo-ex-squat';

      await db.batch((batch) {
        batch.insertAll(db.exerciseLibraryTable, [
          ExerciseLibraryTableCompanion.insert(
            id: benchId,
            remoteId: Value(benchId),
            externalId: 'Barbell_Bench_Press',
            name: 'Supino Reto com Barra',
            category: const Value('strength'),
            synced: const Value(false),
            updatedAt: now,
          ),
          ExerciseLibraryTableCompanion.insert(
            id: squatId,
            remoteId: Value(squatId),
            externalId: 'Barbell_Squat',
            name: 'Agachamento Livre com Barra',
            category: const Value('strength'),
            synced: const Value(false),
            updatedAt: now,
          ),
        ], mode: InsertMode.insertOrIgnore);
      });

      exercises = await (db.select(db.exerciseLibraryTable)..limit(2)).get();
    }

    final ex1 = exercises.isNotEmpty ? exercises[0] : null;
    final ex2 = exercises.length > 1 ? exercises[1] : null;

    if (ex1 == null) return;

    // 4 sessões com cargas progressivas (crescentes)
    // Insere sem enfileirar na SyncQueue para não poluir o backend remoto
    await db.transaction(() async {
      final sessionDates = [
        now.subtract(const Duration(days: 12)),
        now.subtract(const Duration(days: 8)),
        now.subtract(const Duration(days: 4)),
        now.subtract(const Duration(days: 1)),
      ];

      final ex1Progression = [
        // Sessão 1: max 52.5 kg (série 3 falhou/não concluída com 55kg)
        [
          (weight: 50.0, reps: 10, completed: true),
          (weight: 52.5, reps: 8, completed: true),
          (weight: 55.0, reps: 6, completed: false),
        ],
        // Sessão 2: max 55.0 kg
        [
          (weight: 52.5, reps: 10, completed: true),
          (weight: 55.0, reps: 8, completed: true),
        ],
        // Sessão 3: max 57.5 kg
        [
          (weight: 55.0, reps: 10, completed: true),
          (weight: 57.5, reps: 8, completed: true),
        ],
        // Sessão 4: max 60.0 kg
        [
          (weight: 57.5, reps: 10, completed: true),
          (weight: 60.0, reps: 8, completed: true),
        ],
      ];

      final ex2Progression = [
        // Sessão 1: max 75.0 kg
        [
          (weight: 70.0, reps: 10, completed: true),
          (weight: 75.0, reps: 8, completed: true),
        ],
        // Sessão 2: max 80.0 kg
        [
          (weight: 75.0, reps: 10, completed: true),
          (weight: 80.0, reps: 8, completed: true),
        ],
        // Sessão 3: max 82.5 kg
        [
          (weight: 80.0, reps: 8, completed: true),
          (weight: 82.5, reps: 8, completed: true),
        ],
        // Sessão 4: max 90.0 kg
        [
          (weight: 85.0, reps: 8, completed: true),
          (weight: 90.0, reps: 6, completed: true),
        ],
      ];

      for (var i = 0; i < sessionDates.length; i++) {
        final sessionId = _generateUuid();
        final startedAt = sessionDates[i];
        final completedAt = startedAt.add(const Duration(minutes: 50));

        await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                id: sessionId,
                userId: userId,
                startedAt: startedAt,
                completedAt: Value(completedAt),
                notes: const Value(demoNotesMarker),
                synced: const Value(false),
                updatedAt: startedAt,
              ),
            );

        // Séries do exercício 1
        final sets1 = ex1Progression[i];
        for (var s = 0; s < sets1.length; s++) {
          final setInfo = sets1[s];
          await db
              .into(db.exerciseSets)
              .insert(
                ExerciseSetsCompanion.insert(
                  id: _generateUuid(),
                  sessionId: sessionId,
                  exerciseId: ex1.id,
                  setNumber: s + 1,
                  weightKg: Value(setInfo.weight),
                  reps: Value(setInfo.reps),
                  completed: Value(setInfo.completed),
                  synced: const Value(false),
                  createdAt: startedAt.add(Duration(minutes: s * 3)),
                  updatedAt: startedAt.add(Duration(minutes: s * 3)),
                ),
              );
        }

        // Séries do exercício 2 (se houver)
        if (ex2 != null) {
          final sets2 = ex2Progression[i];
          for (var s = 0; s < sets2.length; s++) {
            final setInfo = sets2[s];
            await db
                .into(db.exerciseSets)
                .insert(
                  ExerciseSetsCompanion.insert(
                    id: _generateUuid(),
                    sessionId: sessionId,
                    exerciseId: ex2.id,
                    setNumber: s + 1,
                    weightKg: Value(setInfo.weight),
                    reps: Value(setInfo.reps),
                    completed: Value(setInfo.completed),
                    synced: const Value(false),
                    createdAt: startedAt.add(Duration(minutes: 15 + s * 3)),
                    updatedAt: startedAt.add(Duration(minutes: 15 + s * 3)),
                  ),
                );
          }
        }
      }
    });
  }

  @override
  Future<void> clearDemoData(String userId) async {
    if (!kDebugMode) return;

    await db.transaction(() async {
      // 1. Busca os IDs das sessões de demonstração do usuário
      final demoSessions =
          await (db.select(db.workoutSessions)..where(
                (t) =>
                    t.userId.equals(userId) & t.notes.equals(demoNotesMarker),
              ))
              .get();

      final sessionIds = demoSessions.map((s) => s.id).toList();

      if (sessionIds.isNotEmpty) {
        // 2. Apaga as séries associadas a essas sessões
        await (db.delete(
          db.exerciseSets,
        )..where((t) => t.sessionId.isIn(sessionIds))).go();

        // 3. Apaga as sessões de demonstração
        await (db.delete(
          db.workoutSessions,
        )..where((t) => t.id.isIn(sessionIds))).go();
      }
    });
  }

  @override
  Stream<bool> watchHasDemoData(String userId) {
    return (db.select(db.workoutSessions)..where(
          (t) => t.userId.equals(userId) & t.notes.equals(demoNotesMarker),
        ))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  @override
  Stream<MonthlyWorkoutSummary> watchMonthlySummary(
    String userId,
    DateTime month,
  ) {
    final monthStart = firstDayOfMonth(month);
    final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);

    final query = db.select(db.workoutSessions)
      ..where(
        (tbl) =>
            tbl.userId.equals(userId) &
            tbl.completedAt.isNotNull() &
            tbl.completedAt.isBiggerOrEqualValue(monthStart) &
            tbl.completedAt.isSmallerThanValue(nextMonthStart),
      );

    return query.watch().map((sessions) {
      final trainedDays = <DateTime>{};
      var workoutCount = 0;
      var totalVolumeKg = 0.0;

      for (final session in sessions) {
        final completedAt = session.completedAt;
        if (completedAt == null) continue;

        final day = normalizeDay(completedAt);
        // Garante o recorte no fuso local mesmo se o limite do SQL incluir
        // instantes que caem em outro dia local.
        if (day.year != monthStart.year || day.month != monthStart.month) {
          continue;
        }

        trainedDays.add(day);
        workoutCount++;
        totalVolumeKg += session.totalVolumeKg ?? 0;
      }

      return MonthlyWorkoutSummary(
        month: monthStart,
        trainedDays: trainedDays,
        workoutCount: workoutCount,
        totalVolumeKg: totalVolumeKg,
      );
    });
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
