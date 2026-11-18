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

  @override
  Stream<Set<DateTime>> watchTrainedDays(String userId) {
    final query = db.select(db.workoutSessions)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.completedAt.isNotNull());

    return query.watch().map(
      (sessions) =>
          sessions.map((session) => normalizeDay(session.completedAt!)).toSet(),
    );
  }

  @override
  Stream<Set<DateTime>> watchWaterGoalDays(String userId, int dailyGoalMl) {
    final query = db.select(db.waterIntake)
      ..where((tbl) => tbl.userId.equals(userId));

    return query.watch().map((entries) {
      final totalsByDay = <String, int>{};

      for (final entry in entries) {
        final dayKey = entry.date.isNotEmpty
            ? entry.date
            : _localDateKey(entry.recordedAt);
        totalsByDay[dayKey] = (totalsByDay[dayKey] ?? 0) + entry.amountMl;
      }

      final goalDays = <DateTime>{};
      totalsByDay.forEach((dayKey, totalMl) {
        if (totalMl < dailyGoalMl) return;
        final day = _parseLocalDate(dayKey);
        if (day != null) goalDays.add(day);
      });

      return goalDays;
    });
  }

  static String _localDateKey(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? _parseLocalDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    return DateTime(year, month, day);
  }
}
