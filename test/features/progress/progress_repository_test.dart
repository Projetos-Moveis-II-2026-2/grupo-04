import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:olimpus/features/progress/domain/entities/monthly_workout_summary.dart';

void main() {
  late AppDatabase db;
  late ProgressRepositoryImpl repository;

  const userId = 'user-1';
  final month = DateTime(2026, 11);

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
    double? totalVolumeKg,
  }) async {
    final startedAt = DateTime(2026, 11, 5, 9);
    await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: id,
            userId: user,
            startedAt: startedAt,
            completedAt: Value(completedAt),
            totalVolumeKg: Value(totalVolumeKg),
            updatedAt: DateTime(2026, 11, 5, 10),
          ),
        );
  }

  group('ProgressRepositoryImpl.watchMonthlySummary', () {
    test(
      'mapeia sessões concluídas em dias distintos e soma o volume',
      () async {
        await insertSession(
          id: 's1',
          completedAt: DateTime(2026, 11, 3, 18, 30),
          totalVolumeKg: 1250.5,
        );
        await insertSession(
          id: 's2',
          completedAt: DateTime(2026, 11, 10, 7, 15),
          totalVolumeKg: 800,
        );

        final summary = await repository
            .watchMonthlySummary(userId, month)
            .first;

        expect(summary.month, DateTime(2026, 11, 1));
        expect(summary.trainedDays, {
          DateTime(2026, 11, 3),
          DateTime(2026, 11, 10),
        });
        expect(summary.workoutCount, 2);
        expect(summary.totalVolumeKg, 2050.5);
        expect(summary.isEmpty, isFalse);
      },
    );

    test('ignora sessões não concluídas', () async {
      await insertSession(
        id: 'in-progress',
        completedAt: null,
        totalVolumeKg: 500,
      );

      final summary = await repository.watchMonthlySummary(userId, month).first;

      expect(summary.isEmpty, isTrue);
      expect(summary.trainedDays, isEmpty);
      expect(summary.totalVolumeKg, 0);
    });

    test('ignora sessões de outro usuário', () async {
      await insertSession(
        id: 'other-user',
        user: 'user-2',
        completedAt: DateTime(2026, 11, 7, 10),
        totalVolumeKg: 900,
      );

      final summary = await repository.watchMonthlySummary(userId, month).first;

      expect(summary.isEmpty, isTrue);
      expect(summary.trainedDays, isEmpty);
    });

    test('ignora sessões de outros meses', () async {
      await insertSession(
        id: 'previous-month',
        completedAt: DateTime(2026, 10, 31, 23, 59),
        totalVolumeKg: 700,
      );
      await insertSession(
        id: 'next-month',
        completedAt: DateTime(2026, 12, 1, 0, 1),
        totalVolumeKg: 300,
      );

      final summary = await repository.watchMonthlySummary(userId, month).first;

      expect(summary.isEmpty, isTrue);
      expect(summary.trainedDays, isEmpty);
      expect(summary.totalVolumeKg, 0);
    });

    test(
      'soma volume nulo como zero e conta múltiplas sessões no mesmo dia',
      () async {
        await insertSession(
          id: 'same-day-1',
          completedAt: DateTime(2026, 11, 12, 8),
          totalVolumeKg: null,
        );
        await insertSession(
          id: 'same-day-2',
          completedAt: DateTime(2026, 11, 12, 19),
          totalVolumeKg: 400,
        );

        final summary = await repository
            .watchMonthlySummary(userId, month)
            .first;

        expect(summary.trainedDays, {DateTime(2026, 11, 12)});
        expect(summary.workoutCount, 2);
        expect(summary.totalVolumeKg, 400);
      },
    );

    test('stream reage a novas sessões concluídas', () async {
      final emissions = <MonthlyWorkoutSummary>[];
      final initialEmission = Completer<void>();
      final subscription = repository.watchMonthlySummary(userId, month).listen(
        (summary) {
          emissions.add(summary);
          if (!initialEmission.isCompleted) {
            initialEmission.complete();
          }
        },
      );

      await initialEmission.future;
      expect(emissions.last.isEmpty, isTrue);

      await insertSession(
        id: 'reactive',
        completedAt: DateTime(2026, 11, 20, 18),
        totalVolumeKg: 1500,
      );
      await pumpEventQueue();

      expect(emissions.last.workoutCount, 1);
      expect(emissions.last.trainedDays, {DateTime(2026, 11, 20)});

      await subscription.cancel();
    });
  });
}
