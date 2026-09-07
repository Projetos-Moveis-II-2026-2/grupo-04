import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';

/// Drena a SyncQueue em FIFO contra o Supabase.
///
/// Em falha, incrementa `retryCount` e agenda retry com backoff exponencial
/// (2^retries segundos); após [_maxRetries] o item sai da fila para revisão
/// manual. Nada é removido da fila antes do sucesso no remoto: se o app
/// morrer no meio do flush, o próximo ciclo reprocessa (upsert é idempotente
/// por `onConflict: 'id'`).
class SyncQueueService {
  SyncQueueService(
    this._db, {
    required this.gateway,
    void Function(Duration delay, Future<void> Function() retry)?
    retryScheduler,
  }) : _retryScheduler = retryScheduler ?? _defaultScheduler;

  static const _maxRetries = 5;

  static void _defaultScheduler(Duration delay, Future<void> Function() retry) {
    Timer(delay, () => unawaited(retry()));
  }

  final AppDatabase _db;
  final SyncRemoteGateway gateway;
  final void Function(Duration delay, Future<void> Function() retry)
  _retryScheduler;
  Future<void>? _inFlight;

  /// Callback para itens abandonados após [_maxRetries] (log/revisão manual).
  void Function(SyncQueueEntry entry, Exception error)? onGiveUp;

  /// Enfileira uma operação para sincronização posterior.
  Future<void> enqueue(
    String table,
    String recordId,
    String operation,
    Map<String, dynamic> payload,
  ) {
    return _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            targetTable: table,
            recordId: recordId,
            operation: operation,
            payload: jsonEncode(payload),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Processa a fila inteira em ordem FIFO. Chamadas concorrentes são
  /// coalescidas no mesmo Future.
  Future<void> processQueue() {
    return _inFlight ??= _drain().whenComplete(() => _inFlight = null);
  }

  Future<void> _drain() async {
    final entries = await (_db.select(
      _db.syncQueue,
    )..orderBy([(q) => OrderingTerm.asc(q.id)])).get();

    for (final entry in entries) {
      final ok = await _processEntry(entry);
      if (!ok) break; // falha persistente: aguarda o próximo ciclo
    }
  }

  /// Retorna true se o item foi sincronizado ou descartado; false se falhou.
  Future<bool> _processEntry(SyncQueueEntry entry) async {
    try {
      final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
      if (entry.operation == 'delete') {
        await gateway.delete(entry.targetTable, entry.recordId);
      } else {
        await gateway.upsert(entry.targetTable, payload);
      }

      await _markLocalSynced(entry);
      await (_db.delete(
        _db.syncQueue,
      )..where((q) => q.id.equals(entry.id))).go();
      return true;
    } on Exception catch (error) {
      // retryCount conta retries (a 1ª falha = retry 1). Com _maxRetries = 5,
      // o item é abandonado na 6ª falha consecutiva, quando retryCount passa
      // de 5 (pseudocódigo do plano: "se retryCount > 5, revisão manual").
      final retries = entry.retryCount + 1;
      if (retries > _maxRetries) {
        onGiveUp?.call(entry, error);
        await (_db.delete(
          _db.syncQueue,
        )..where((q) => q.id.equals(entry.id))).go();
        return true; // abandona (revisão manual) e segue a fila
      }
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(entry.id)))
          .write(SyncQueueCompanion(retryCount: Value(retries)));
      _retryScheduler(Duration(seconds: 1 << retries), processQueue);
      return false;
    }
  }

  Future<void> _markLocalSynced(SyncQueueEntry entry) async {
    final sqlTable = switch (entry.targetTable) {
      'exercise_sets' => _db.exerciseSets.actualTableName,
      'workout_sessions' => _db.workoutSessions.actualTableName,
      'workout_templates' => _db.workoutTemplates.actualTableName,
      'exercise_library' => _db.exerciseLibraryTable.actualTableName,
      'water_intake' => _db.waterIntake.actualTableName,
      _ => throw ArgumentError.value(
        entry.targetTable,
        'targetTable',
        'Tabela local desconhecida',
      ),
    };

    await _db.customUpdate(
      'UPDATE $sqlTable SET synced = 1 WHERE id = ?',
      variables: [Variable.withString(entry.recordId)],
    );
  }
}
