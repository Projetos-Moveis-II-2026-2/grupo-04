import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';

import '../../domain/entities/monthly_workout_summary.dart';
import '../../domain/repositories/i_progress_repository.dart';
import '../../domain/utils/calendar_utils.dart';

/// Implementação do repositório de progresso sobre o Drift (SQLite).
class ProgressRepositoryImpl implements IProgressRepository {
  ProgressRepositoryImpl({required this.db});

  final AppDatabase db;

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
}
