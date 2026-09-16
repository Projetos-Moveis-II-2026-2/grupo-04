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
    required AppDatabase db,
    SyncQueueService? syncQueue,
    DateTime Function()? nowProvider,
  })  : _db = db,
        _syncQueue = syncQueue,
        _now = nowProvider ?? DateTime.now;

  final AppDatabase _db;
  final SyncQueueService? _syncQueue;
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
      final today = _toLocalDay(_now());
      return entries
          .where((e) => _toLocalDay(e.recordedAt) == today)
          .map(_toRecord)
          .toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
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

      // Mapeia registros pelo dia local (ano, mês, dia)
      final dailyMap = <DateTime, int>{};
      for (final entry in entries) {
        final day = _toLocalDay(entry.recordedAt);
        dailyMap[day] = (dailyMap[day] ?? 0) + entry.amountMl;
      }

      // Constrói exatamente os últimos 7 dias: [hoje - 6, ..., hoje]
      final result = <DailyWaterSummary>[];
      for (var i = 6; i >= 0; i--) {
        final day = DateTime(today.year, today.month, today.day - i);
        final total = dailyMap[day] ?? 0;
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
    final localDateStr =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final id = _generateUuid();

    final companion = WaterIntakeCompanion.insert(
      id: id,
      userId: userId,
      amountMl: amountMl,
      recordedAt: at,
      date: localDateStr,
      synced: const Value(false),
      updatedAt: now,
    );

    await _db.into(_db.waterIntake).insert(companion);

    // Enfileira na SyncQueue se disponível
    if (_syncQueue != null) {
      await _syncQueue.enqueue(
        'water_intake',
        id,
        'upsert',
        {
          'id': id,
          'user_id': userId,
          'amount_ml': amountMl,
          'recorded_at': at.toIso8601String(),
          'date': localDateStr,
          'updated_at': now.toIso8601String(),
        },
      );
    }

    return WaterIntakeRecord(
      id: id,
      userId: userId,
      amountMl: amountMl,
      recordedAt: at,
      date: localDateStr,
      synced: false,
    );
  }

  @override
  Future<void> deleteWaterIntake(String id) async {
    await (_db.delete(_db.waterIntake)..where((tbl) => tbl.id.equals(id))).go();
  }

  Stream<List<WaterIntakeEntry>> _watchUserEntries(String userId) {
    return (_db.select(_db.waterIntake)
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

