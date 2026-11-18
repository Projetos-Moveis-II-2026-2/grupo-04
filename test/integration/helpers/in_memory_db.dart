import 'package:drift/native.dart';
import 'package:olimpus/core/database/app_database.dart';

/// Abre o [AppDatabase] em memória, sem tocar no arquivo local do app.
AppDatabase createInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
