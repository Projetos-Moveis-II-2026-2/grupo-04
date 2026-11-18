import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/features/progress/data/repositories/progress_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ProgressRepositoryImpl repository;

  const userId = 'user-1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ProgressRepositoryImpl(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSession({
    required String id,
    String user = userId,
    DateTime? completedAt,
  }) async {
    await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: id,
            userId: user,
            startedAt: DateTime(2026, 11, 5, 9),
            completedAt: Value(completedAt),
            updatedAt: DateTime(2026, 11, 5, 10),
          ),
        );
  }

  Future<void> insertWater({
    required String id,
    String user = userId,
    required int amountMl,
    required String date,
    DateTime? recordedAt,
  }) async {
    final localRecordedAt = recordedAt ?? DateTime(2026, 11, 17, 8);
    await db
        .into(db.waterIntake)
        .insert(
          WaterIntakeCompanion.insert(
            id: id,
            userId: user,
            amountMl: amountMl,
            recordedAt: localRecordedAt,
            date: date,
            updatedAt: localRecordedAt,
          ),
        );
  }

  group('ProgressRepositoryImpl.watchTrainedDays', () {
    test('retorna dias distintos normalizados com treino concluído', () async {
      await insertSession(id: 's1', completedAt: DateTime(2026, 11, 17, 6, 30));
      await insertSession(
        id: 's2',
        completedAt: DateTime(2026, 11, 17, 19, 45),
      );
      await insertSession(id: 's3', completedAt: DateTime(2026, 11, 15, 12));

      final days = await repository.watchTrainedDays(userId).first;

      expect(days, {DateTime(2026, 11, 17), DateTime(2026, 11, 15)});
    });

    test('ignora sessões em andamento e de outro usuário', () async {
      await insertSession(id: 'pending', completedAt: null);
      await insertSession(
        id: 'other-user',
        user: 'user-2',
        completedAt: DateTime(2026, 11, 16, 10),
      );

      final days = await repository.watchTrainedDays(userId).first;

      expect(days, isEmpty);
    });

    test('stream reage a uma nova sessão concluída', () async {
      final emissions = <Set<DateTime>>[];
      final firstEmission = Completer<void>();
      final subscription = repository.watchTrainedDays(userId).listen((days) {
        emissions.add(days);
        if (!firstEmission.isCompleted) firstEmission.complete();
      });

      await firstEmission.future;
      expect(emissions.last, isEmpty);

      await insertSession(
        id: 'reactive',
        completedAt: DateTime(2026, 11, 17, 8),
      );
      await pumpEventQueue();

      expect(emissions.last, {DateTime(2026, 11, 17)});

      await subscription.cancel();
    });
  });

  group('ProgressRepositoryImpl.watchWaterGoalDays', () {
    test(
      'soma os registros por date e inclui apenas dias que bateram a meta',
      () async {
        await insertWater(id: 'w1', amountMl: 1200, date: '2026-11-17');
        await insertWater(id: 'w2', amountMl: 900, date: '2026-11-17');
        await insertWater(id: 'w3', amountMl: 1999, date: '2026-11-16');

        final goalDays = await repository
            .watchWaterGoalDays(userId, 2000)
            .first;

        expect(goalDays, {DateTime(2026, 11, 17)});
      },
    );

    test('agrupa pela coluna date, não pelo recordedAt', () async {
      await insertWater(
        id: 'cross-midnight-1',
        amountMl: 1000,
        date: '2026-11-16',
        recordedAt: DateTime(2026, 11, 17, 0, 5),
      );
      await insertWater(
        id: 'cross-midnight-2',
        amountMl: 1000,
        date: '2026-11-16',
        recordedAt: DateTime(2026, 11, 16, 23, 55),
      );

      final goalDays = await repository.watchWaterGoalDays(userId, 2000).first;

      expect(goalDays, {DateTime(2026, 11, 16)});
    });

    test('ignora registros de outro usuário', () async {
      await insertWater(
        id: 'other-user',
        user: 'user-2',
        amountMl: 3000,
        date: '2026-11-17',
      );

      final goalDays = await repository.watchWaterGoalDays(userId, 2000).first;

      expect(goalDays, isEmpty);
    });

    test('usa recordedAt como fallback quando date está vazio', () async {
      await insertWater(
        id: 'fallback',
        amountMl: 2000,
        date: '',
        recordedAt: DateTime(2026, 11, 15, 9),
      );

      final goalDays = await repository.watchWaterGoalDays(userId, 2000).first;

      expect(goalDays, {DateTime(2026, 11, 15)});
    });

    test('stream reage a novos registros de água', () async {
      final emissions = <Set<DateTime>>[];
      final firstEmission = Completer<void>();
      final subscription = repository.watchWaterGoalDays(userId, 2000).listen((
        days,
      ) {
        emissions.add(days);
        if (!firstEmission.isCompleted) firstEmission.complete();
      });

      await firstEmission.future;
      expect(emissions.last, isEmpty);

      await insertWater(
        id: 'reactive-water',
        amountMl: 2000,
        date: '2026-11-17',
      );
      await pumpEventQueue();

      expect(emissions.last, {DateTime(2026, 11, 17)});

      await subscription.cancel();
    });
  });
}
