import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:olimpus/core/database/tables/exercise_library_table.dart';
import 'package:olimpus/core/database/tables/exercise_sets_table.dart';
import 'package:olimpus/core/database/tables/sync_queue_table.dart';
import 'package:olimpus/core/database/tables/water_intake_table.dart';
import 'package:olimpus/core/database/tables/workout_sessions_table.dart';
import 'package:olimpus/core/database/tables/workout_templates_table.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ExerciseSets,
    WorkoutSessions,
    WorkoutTemplates,
    ExerciseLibraryTable,
    WaterIntake,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Migrações futuras (v2, v3, ...) entram aqui.
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'db', 'olimpus.sqlite'));
      await file.parent.create(recursive: true);
      return NativeDatabase.createInBackground(file);
    });
  }
}
