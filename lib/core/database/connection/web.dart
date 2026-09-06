import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Conexão para web via SQLite WASM + drift worker
/// (requer web/sqlite3.wasm e web/drift_worker.js servidos junto do app).
QueryExecutor connect() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'olimpus',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return DatabaseConnection(result.resolvedExecutor);
    }),
  ).executor;
}
