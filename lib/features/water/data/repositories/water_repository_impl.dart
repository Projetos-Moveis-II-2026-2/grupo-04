import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';

import '../../domain/entities/daily_water_summary.dart';
import '../../domain/entities/water_intake_record.dart';
import '../../domain/repositories/i_water_repository.dart';

/// Implementação do repositório de consumo de água sobre o Drift (SQLite).
class WaterRepositoryImpl implements IWaterRepository {
  WaterRepositoryImpl({
    required this.db,
    this.syncQueue,
    DateTime Function()? nowProvider,
  }) : _now = nowProvider ?? DateTime.now;

  final AppDatabase db;
  final SyncQueueService? syncQueue;
  final DateTime Function() _now;

  static const List<String> _weekDayAbbr = [
    '',
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  @override
  Stream<List<WaterIntakeRecord>> watchTodayEntries(String userId) {
    return _watchUserEntries(userId).map((entries) {
      final now = _now();
      final todayStr = _toLocalDateString(now);
      final todayDate = _toLocalDay(now);

      return entries
          .where((e) =>
              e.date == todayStr || _toLocalDay(e.recordedAt) == todayDate)
          .map(_toRecord)
          .toList()
        ..sort((a, b) => a.localRecordedAt.compareTo(b.localRecordedAt));
    });
  }

  @override
  Stream<int> watchTodayTotal(String userId) {
    return watchTodayEntries(userId).map(
      (entries) => entries.fold<int>(0, (sum, item) => sum + item.amountMl),
    );
  }

  @override
  Stream<List<DailyWaterSummary>> watchLast7DaysSummary(String userId) {
    return _watchUserEntries(userId).map((entries) {
      final now = _now();
      final today = _toLocalDay(now);

      // Mapeia registros pela data local (YYYY-MM-DD)
      final dailyMap = <String, int>{};
      for (final entry in entries) {
        final dayStr = entry.date.isNotEmpty
            ? entry.date
            : _toLocalDateString(entry.recordedAt);
        dailyMap[dayStr] = (dailyMap[dayStr] ?? 0) + entry.amountMl;
      }

      // Constrói exatamente os últimos 7 dias: [hoje - 6, ..., hoje]
      final result = <DailyWaterSummary>[];
      for (var i = 6; i >= 0; i--) {
        final day = DateTime(today.year, today.month, today.day - i);
        final dayStr = _toLocalDateString(day);
        final total = dailyMap[dayStr] ?? 0;
        final abbr = _weekDayAbbr[day.weekday];
        result.add(
          DailyWaterSummary(
            date: day,
            totalMl: total,
            dayOfWeekAbbr: abbr,
            isToday: i == 0,
          ),
        );
      }

      return result;
    });
  }

  @override
  Future<WaterIntakeRecord> addWaterIntake({
    required String userId,
    required int amountMl,
    DateTime? recordedAt,
  }) async {
    final now = _now();
    final at = recordedAt ?? now;
    final local = at.toLocal();
    final localDateStr = _toLocalDateString(local);
    final id = _generateUuid();

    final companion = WaterIntakeCompanion.insert(
      id: id,
      remoteId: Value(id),
      userId: userId,
      amountMl: amountMl,
      recordedAt: local,
      date: localDateStr,
      synced: const Value(false),
      updatedAt: now.toLocal(),
    );

    await db.into(db.waterIntake).insert(companion);

    // Enfileira na SyncQueue se disponível com timestamp UTC explícito (com 'Z')
    if (syncQueue != null) {
      await syncQueue!.enqueue(
        'water_intake',
        id,
        'upsert',
        {
          'id': id,
          'user_id': userId,
          'amount_ml': amountMl,
          'recorded_at': at.toUtc().toIso8601String(),
          'date': localDateStr,
          'updated_at': now.toUtc().toIso8601String(),
        },
      );
      unawaited(syncQueue!.processQueue());
    }

    return WaterIntakeRecord(
      id: id,
      remoteId: id,
      userId: userId,
      amountMl: amountMl,
      recordedAt: local,
      date: localDateStr,
      synced: false,
    );
  }

  @override
  Future<void> deleteWaterIntake(String id) async {
    await (db.delete(db.waterIntake)..where((tbl) => tbl.id.equals(id))).go();
    if (syncQueue != null) {
      await syncQueue!.enqueue('water_intake', id, 'delete', {'id': id});
      unawaited(syncQueue!.processQueue());
    }
  }

  Stream<List<WaterIntakeEntry>> _watchUserEntries(String userId) {
    return (db.select(db.waterIntake)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.recordedAt,
                  mode: OrderingMode.asc,
                ),
          ]))
        .watch();
  }

  /// Converte qualquer DateTime para 00:00:00 no fuso local do dispositivo.
  static DateTime _toLocalDay(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Converte qualquer DateTime para a string YYYY-MM-DD no fuso local do dispositivo.
  static String _toLocalDateString(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  WaterIntakeRecord _toRecord(WaterIntakeEntry entry) {
    return WaterIntakeRecord(
      id: entry.id,
      remoteId: entry.remoteId,
      userId: entry.userId,
      amountMl: entry.amountMl,
      recordedAt: entry.recordedAt,
      date: entry.date,
      synced: entry.synced,
    );
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}

