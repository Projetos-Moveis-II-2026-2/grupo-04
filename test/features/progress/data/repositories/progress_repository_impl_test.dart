import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/features/progress/data/repositories/progress_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ProgressRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ProgressRepositoryImpl(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProgressRepositoryImpl', () {
    const userA = 'user-a';
    const userB = 'user-b';
    const exBench = 'ex-bench';
    const exSquat = 'ex-squat';

    setUp(() async {
      // Popula a biblioteca de exercícios para teste
      await db
          .into(db.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: exBench,
              remoteId: const Value('remote-bench-uuid'),
              externalId: 'Barbell_Bench_Press',
              name: 'Supino Reto com Barra',
              synced: const Value(true),
              updatedAt: DateTime.now(),
            ),
          );

      await db
          .into(db.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: exSquat,
              remoteId: const Value('remote-squat-uuid'),
              externalId: 'Barbell_Squat',
              name: 'Agachamento Livre',
              synced: const Value(true),
              updatedAt: DateTime.now(),
            ),
          );
    });

    test('watchUserExercisesWithLogs lista exercícios com logs e mapeia nomes da biblioteca', () async {
      final now = DateTime(2026, 9, 10, 10, 0);

      // Sessão do User A com Supino
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: 'session-1',
              userId: userA,
              startedAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 'set-1',
              sessionId: 'session-1',
              exerciseId: exBench,
              setNumber: 1,
              weightKg: const Value(60.0),
              completed: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Sessão do User B com Agachamento (não deve aparecer para User A)
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: 'session-2',
              userId: userB,
              startedAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 'set-2',
              sessionId: 'session-2',
              exerciseId: exSquat,
              setNumber: 1,
              weightKg: const Value(100.0),
              completed: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final listUserA = await repository
          .watchUserExercisesWithLogs(userA)
          .first;
      expect(listUserA.length, 1);
      expect(listUserA.first.exerciseId, exBench);
      expect(listUserA.first.name, 'Supino Reto com Barra');

      final listUserB = await repository
          .watchUserExercisesWithLogs(userB)
          .first;
      expect(listUserB.length, 1);
      expect(listUserB.first.exerciseId, exSquat);
      expect(listUserB.first.name, 'Agachamento Livre');
    });

    test('watchExerciseLoadProgression calcula carga máxima correta com 2+ sessões e ignora completed=false', () async {
      final date1 = DateTime(2026, 9, 1, 10, 0);
      final date2 = DateTime(2026, 9, 5, 10, 0);
      final date3 = DateTime(2026, 9, 10, 10, 0);

      // Sessão 1 (Data 1):
      // Série 1: 50 kg (completed: true)
      // Série 2: 60 kg (completed: true) -> Max 60 kg
      // Série 3: 70 kg (completed: false) -> deve ser ignorada!
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: 'sess-1',
              userId: userA,
              startedAt: date1,
              updatedAt: date1,
            ),
          );
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 's1-set1',
              sessionId: 'sess-1',
              exerciseId: exBench,
              setNumber: 1,
              weightKg: const Value(50.0),
              completed: const Value(true),
              createdAt: date1,
              updatedAt: date1,
            ),
          );
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 's1-set2',
              sessionId: 'sess-1',
              exerciseId: exBench,
              setNumber: 2,
              weightKg: const Value(60.0),
              completed: const Value(true),
              createdAt: date1,
              updatedAt: date1,
            ),
          );
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 's1-set3',
              sessionId: 'sess-1',
              exerciseId: exBench,
              setNumber: 3,
              weightKg: const Value(70.0),
              completed: const Value(false),
              createdAt: date1,
              updatedAt: date1,
            ),
          );

      // Sessão 2 (Data 2):
      // Série 1: 62.5 kg (completed: true)
      // Série 2: 65.0 kg (completed: true) -> Max 65 kg
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: 'sess-2',
              userId: userA,
              startedAt: date2,
              updatedAt: date2,
            ),
          );
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 's2-set1',
              sessionId: 'sess-2',
              exerciseId: exBench,
              setNumber: 1,
              weightKg: const Value(62.5),
              completed: const Value(true),
              createdAt: date2,
              updatedAt: date2,
            ),
          );
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 's2-set2',
              sessionId: 'sess-2',
              exerciseId: exBench,
              setNumber: 2,
              weightKg: const Value(65.0),
              completed: const Value(true),
              createdAt: date2,
              updatedAt: date2,
            ),
          );

      // Sessão 3 (Data 3 - de outro usuário, com carga maior; deve ser ignorada para userA)
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: 'sess-3',
              userId: userB,
              startedAt: date3,
              updatedAt: date3,
            ),
          );
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 's3-set1',
              sessionId: 'sess-3',
              exerciseId: exBench,
              setNumber: 1,
              weightKg: const Value(999.0),
              completed: const Value(true),
              createdAt: date3,
              updatedAt: date3,
            ),
          );

      final points = await repository
          .watchExerciseLoadProgression(userId: userA, exerciseId: exBench)
          .first;

      expect(points.length, 2);
      expect(points[0].sessionId, 'sess-1');
      expect(points[0].date, date1);
      expect(points[0].maxWeightKg, 60.0);

      expect(points[1].sessionId, 'sess-2');
      expect(points[1].date, date2);
      expect(points[1].maxWeightKg, 65.0);
    });

    test(
      'ordena cronologicamente mesmo se sessões forem inseridas fora de ordem',
      () async {
        final earlierDate = DateTime(2026, 8, 1, 10, 0);
        final laterDate = DateTime(2026, 8, 15, 10, 0);

        // Insere primeiro a sessão mais recente
        await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                id: 'sess-later',
                userId: userA,
                startedAt: laterDate,
                updatedAt: laterDate,
              ),
            );
        await db
            .into(db.exerciseSets)
            .insert(
              ExerciseSetsCompanion.insert(
                id: 'set-later',
                sessionId: 'sess-later',
                exerciseId: exBench,
                setNumber: 1,
                weightKg: const Value(80.0),
                completed: const Value(true),
                createdAt: laterDate,
                updatedAt: laterDate,
              ),
            );

        // Insere depois a sessão mais antiga
        await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                id: 'sess-earlier',
                userId: userA,
                startedAt: earlierDate,
                updatedAt: earlierDate,
              ),
            );
        await db
            .into(db.exerciseSets)
            .insert(
              ExerciseSetsCompanion.insert(
                id: 'set-earlier',
                sessionId: 'sess-earlier',
                exerciseId: exBench,
                setNumber: 1,
                weightKg: const Value(75.0),
                completed: const Value(true),
                createdAt: earlierDate,
                updatedAt: earlierDate,
              ),
            );

        final points = await repository
            .watchExerciseLoadProgression(userId: userA, exerciseId: exBench)
            .first;

        expect(points.length, 2);
        expect(points[0].sessionId, 'sess-earlier');
        expect(points[0].date, earlierDate);
        expect(points[0].maxWeightKg, 75.0);

        expect(points[1].sessionId, 'sess-later');
        expect(points[1].date, laterDate);
        expect(points[1].maxWeightKg, 80.0);
      },
    );

    test('identifica exercício através de remoteId e externalId', () async {
      final date = DateTime(2026, 9, 1);

      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              id: 'sess-remote',
              userId: userA,
              startedAt: date,
              updatedAt: date,
            ),
          );

      // Série gravada com o remoteId do Supabase ('remote-bench-uuid') em vez do id local
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 'set-remote',
              sessionId: 'sess-remote',
              exerciseId: 'remote-bench-uuid',
              setNumber: 1,
              weightKg: const Value(72.0),
              completed: const Value(true),
              createdAt: date,
              updatedAt: date,
            ),
          );

      // Consultando pelo id canônico exBench ('ex-bench')
      final points = await repository
          .watchExerciseLoadProgression(userId: userA, exerciseId: exBench)
          .first;

      expect(points.length, 1);
      expect(points.first.maxWeightKg, 72.0);
    });

    test('seedDemoData insere 4 sessões progressivas e clearDemoData remove os dados de teste', () async {
      await repository.seedDemoData(userA);

      final hasDemo = await repository.watchHasDemoData(userA).first;
      expect(hasDemo, isTrue);

      final exercises = await repository
          .watchUserExercisesWithLogs(userA)
          .first;
      expect(exercises.isNotEmpty, isTrue);

      final progression = await repository
          .watchExerciseLoadProgression(
            userId: userA,
            exerciseId: exercises.first.exerciseId,
          )
          .first;

      // 4 sessões criadas
      expect(progression.length, 4);

      // Verifica curva estritamente ascendente
      for (var i = 0; i < progression.length - 1; i++) {
        expect(
          progression[i + 1].maxWeightKg,
          greaterThan(progression[i].maxWeightKg),
          reason: 'Carga da sessão ${i + 1} deve ser maior que da sessão $i',
        );
      }

      // Agora limpa os dados de demonstração
      await repository.clearDemoData(userA);

      final hasDemoAfter = await repository.watchHasDemoData(userA).first;
      expect(hasDemoAfter, isFalse);

      final exercisesAfter = await repository
          .watchUserExercisesWithLogs(userA)
          .first;
      expect(exercisesAfter, isEmpty);
    });
  });
}
