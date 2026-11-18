import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/connection/connection.dart' as connection;

/// Singleton do banco local; fecha a conexão quando o container é descartado.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    DatabaseConnection(
      connection.connect(),
      // Evita timers pendentes quando o último listener de um stream é
      // cancelado (necessário para testes de widget que navegam pelo app).
      closeStreamsSynchronously: true,
    ),
  );
  ref.onDispose(db.close);
  return db;
});
