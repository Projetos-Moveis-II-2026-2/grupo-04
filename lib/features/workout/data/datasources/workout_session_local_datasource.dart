import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';

/// Persistência local (Drift) das sessões de execução de treino e suas séries.
/// Toda escrita marca `synced = false`; o repositório enfileira o envio.
class WorkoutSessionLocalDataSource {
  WorkoutSessionLocalDataSource(this._db);

  final AppDatabase _db;

  /// Sessão em andamento (sem `completed_at`) da ficha [templateId], se houver.
  Future<WorkoutSession?> findActiveSession({
    required String userId,
    required String templateId,
  }) {
    return (_db.select(_db.workoutSessions)
          ..where(
            (s) =>
                s.userId.equals(userId) &
                s.templateId.equals(templateId) &
                s.completedAt.isNull(),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Cria a sessão e as séries planejadas da ficha em uma transação.
  /// Peso/reps vêm da última sessão concluída do exercício (mesmo número de
  /// série); sem histórico, usa as repetições alvo da ficha.
  Future<({WorkoutSession session, List<ExerciseSet> sets})>
  createSessionFromTemplate({
    required String userId,
    required WorkoutTemplateEntity template,
  }) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final sessionId = UuidV4.generate();
      await _db
          .into(_db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: sessionId,
              remoteId: Value(sessionId),
              userId: userId,
              templateId: Value(template.id),
              startedAt: now,
              updatedAt: now,
            ),
          );

      for (final item in template.exercises) {
        final previous = await previousSets(
          userId: userId,
          exerciseId: item.exerciseId,
          excludeSessionId: sessionId,
        );
        final total = item.targetSets < 1 ? 1 : item.targetSets;
        for (var n = 1; n <= total; n++) {
          final ref = _matchSet(previous, n);
          final setId = UuidV4.generate();
          await _db
              .into(_db.exerciseSets)
              .insert(
                ExerciseSetsCompanion.insert(
                  id: setId,
                  remoteId: Value(setId),
                  sessionId: sessionId,
                  exerciseId: item.exerciseId,
                  setNumber: n,
                  weightKg: Value(ref?.weightKg),
                  reps: Value(ref?.reps ?? item.targetReps),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }

      final session = await _getSession(sessionId);
      final sets = await _setsOf(sessionId);
      return (session: session!, sets: sets);
    });
  }

  /// Séries concluídas de [exerciseId] na sessão concluída mais recente do
  /// usuário (exceto [excludeSessionId]), ordenadas por número da série.
  Future<List<ExerciseSet>> previousSets({
    required String userId,
    required String exerciseId,
    String? excludeSessionId,
  }) async {
    final sessions = _db.workoutSessions;
    final sets = _db.exerciseSets;

    var filter =
        sessions.userId.equals(userId) &
        sessions.completedAt.isNotNull() &
        sets.exerciseId.equals(exerciseId) &
        sets.completed.equals(true);
    if (excludeSessionId != null) {
      filter = filter & sessions.id.equals(excludeSessionId).not();
    }

    final latest =
        await (_db.selectOnly(sets).join([
                innerJoin(sessions, sessions.id.equalsExp(sets.sessionId)),
              ])
              ..addColumns([sessions.id])
              ..where(filter)
              // Drift grava datas com precisão de segundos: o rowid desempata
              // sessões concluídas no mesmo segundo pela ordem de criação.
              ..orderBy([
                OrderingTerm.desc(sessions.completedAt),
                OrderingTerm.desc(
                  const CustomExpression<int>('"workout_sessions"."rowid"'),
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    final latestId = latest?.read(sessions.id);
    if (latestId == null) return const [];

    return (_db.select(_db.exerciseSets)
          ..where(
            (s) =>
                s.sessionId.equals(latestId) &
                s.exerciseId.equals(exerciseId) &
                s.completed.equals(true),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
        .get();
  }

  /// Observa a sessão com seus exercícios, séries e o histórico anterior.
  Stream<WorkoutSessionEntity?> watchSession(String sessionId) {
    final previousCache = <String, List<SessionSet>>{};

    final query =
        (_db.select(
          _db.workoutSessions,
        )..where((s) => s.id.equals(sessionId))).join([
          leftOuterJoin(
            _db.exerciseSets,
            _db.exerciseSets.sessionId.equalsExp(_db.workoutSessions.id),
          ),
        ]);

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      final session = rows.first.readTable(_db.workoutSessions);
      final sets = [
        for (final row in rows) ?row.readTableOrNull(_db.exerciseSets),
      ];
      return _buildEntity(session, sets, previousCache);
    });
  }

  Future<ExerciseSet> updateSet(SessionSet set) async {
    await (_db.update(
      _db.exerciseSets,
    )..where((s) => s.id.equals(set.id))).write(
      ExerciseSetsCompanion(
        weightKg: Value(set.weightKg),
        reps: Value(set.reps),
        completed: Value(set.completed),
        synced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return (_db.select(
      _db.exerciseSets,
    )..where((s) => s.id.equals(set.id))).getSingle();
  }

  /// Cria a próxima série do exercício copiando peso/reps da última.
  Future<ExerciseSet> addSet({
    required String sessionId,
    required String exerciseId,
  }) {
    return _db.transaction(() async {
      final last =
          await (_db.select(_db.exerciseSets)
                ..where(
                  (s) =>
                      s.sessionId.equals(sessionId) &
                      s.exerciseId.equals(exerciseId),
                )
                ..orderBy([(s) => OrderingTerm.desc(s.setNumber)])
                ..limit(1))
              .getSingleOrNull();
      final now = DateTime.now();
      final id = UuidV4.generate();
      await _db
          .into(_db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: id,
              remoteId: Value(id),
              sessionId: sessionId,
              exerciseId: exerciseId,
              setNumber: (last?.setNumber ?? 0) + 1,
              weightKg: Value(last?.weightKg),
              reps: Value(last?.reps),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return (_db.select(
        _db.exerciseSets,
      )..where((s) => s.id.equals(id))).getSingle();
    });
  }

  /// Conclui a sessão: remove séries não concluídas, calcula o volume total
  /// e grava `completed_at`.
  Future<WorkoutSession> completeSession(String sessionId) {
    return _db.transaction(() async {
      await (_db.delete(_db.exerciseSets)..where(
            (s) => s.sessionId.equals(sessionId) & s.completed.equals(false),
          ))
          .go();

      final done = await _setsOf(sessionId);
      final volume = done.fold<double>(
        0,
        (sum, s) => sum + (s.weightKg ?? 0) * (s.reps ?? 0),
      );
      final now = DateTime.now();
      await (_db.update(
        _db.workoutSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(
          completedAt: Value(now),
          totalVolumeKg: Value(volume),
          synced: const Value(false),
          updatedAt: Value(now),
        ),
      );
      return (await _getSession(sessionId))!;
    });
  }

  /// Remove operações pendentes na SyncQueue para o registro, para que só o
  /// estado mais recente seja enviado (evita uma entrada por toque em +/-).
  Future<void> clearPendingSync(String table, String recordId) {
    return (_db.delete(_db.syncQueue)..where(
          (q) => q.targetTable.equals(table) & q.recordId.equals(recordId),
        ))
        .go();
  }

  Future<WorkoutSession?> _getSession(String id) => (_db.select(
    _db.workoutSessions,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<ExerciseSet>> _setsOf(String sessionId) =>
      (_db.select(_db.exerciseSets)
            ..where((s) => s.sessionId.equals(sessionId))
            ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
          .get();

  ExerciseSet? _matchSet(List<ExerciseSet> previous, int setNumber) {
    if (previous.isEmpty) return null;
    for (final s in previous) {
      if (s.setNumber == setNumber) return s;
    }
    return previous.last;
  }

  Future<WorkoutSessionEntity> _buildEntity(
    WorkoutSession session,
    List<ExerciseSet> sets,
    Map<String, List<SessionSet>> previousCache,
  ) async {
    final templateId = session.templateId;
    String? templateName;
    final orderByExercise = <String, int>{};
    final targetRepsByExercise = <String, int?>{};

    if (templateId != null) {
      final tpl = await (_db.select(
        _db.workoutTemplates,
      )..where((t) => t.id.equals(templateId))).getSingleOrNull();
      templateName = tpl?.name;
      final items = await (_db.select(
        _db.templateExercises,
      )..where((t) => t.templateId.equals(templateId))).get();
      for (final item in items) {
        orderByExercise[item.exerciseId] = item.sortOrder;
        targetRepsByExercise[item.exerciseId] = item.targetReps;
      }
    }

    final setsByExercise = <String, List<ExerciseSet>>{};
    for (final s in sets) {
      setsByExercise.putIfAbsent(s.exerciseId, () => []).add(s);
    }
    final exerciseIds = setsByExercise.keys.toList()
      ..sort(
        (a, b) => (orderByExercise[a] ?? 1 << 20).compareTo(
          orderByExercise[b] ?? 1 << 20,
        ),
      );

    final library = exerciseIds.isEmpty
        ? const <ExerciseLibrary>[]
        : await (_db.select(_db.exerciseLibraryTable)..where(
                (e) =>
                    e.id.isIn(exerciseIds) |
                    e.remoteId.isIn(exerciseIds) |
                    e.externalId.isIn(exerciseIds),
              ))
              .get();
    ExerciseLibrary? libraryFor(String id) {
      for (final e in library) {
        if (e.id == id || e.remoteId == id || e.externalId == id) return e;
      }
      return null;
    }

    final exercises = <SessionExercise>[];
    for (final exerciseId in exerciseIds) {
      final previous = previousCache[exerciseId] ??= (await previousSets(
        userId: session.userId,
        exerciseId: exerciseId,
        excludeSessionId: session.id,
      )).map(_toSessionSet).toList(growable: false);

      final lib = libraryFor(exerciseId);
      final image = lib?.imageUrls?.split(',').first.trim();
      final exerciseSets =
          setsByExercise[exerciseId]!.map(_toSessionSet).toList()
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

      exercises.add(
        SessionExercise(
          exerciseId: exerciseId,
          exerciseName: lib?.name ?? exerciseId,
          imageUrl: (image == null || image.isEmpty) ? null : image,
          targetReps: targetRepsByExercise[exerciseId],
          sets: exerciseSets,
          previousSets: previous,
        ),
      );
    }

    return WorkoutSessionEntity(
      id: session.id,
      userId: session.userId,
      templateId: templateId,
      templateName: templateName,
      startedAt: session.startedAt,
      completedAt: session.completedAt,
      totalVolumeKg: session.totalVolumeKg,
      exercises: exercises,
    );
  }

  static SessionSet _toSessionSet(ExerciseSet s) => SessionSet(
    id: s.id,
    sessionId: s.sessionId,
    exerciseId: s.exerciseId,
    setNumber: s.setNumber,
    weightKg: s.weightKg,
    reps: s.reps,
    completed: s.completed,
  );
}
