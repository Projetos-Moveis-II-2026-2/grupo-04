import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/app_database.dart';

/// Singleton do banco local; fecha a conexão quando o container é descartado.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
