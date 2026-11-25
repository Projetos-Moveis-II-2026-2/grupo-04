import 'package:drift/drift.dart';
import 'package:olimpus/core/database/connection/connection.dart' as connection;
import 'package:olimpus/core/database/tables/exercise_library_table.dart';
import 'package:olimpus/core/database/tables/exercise_sets_table.dart';
import 'package:olimpus/core/database/tables/sync_queue_table.dart';
import 'package:olimpus/core/database/tables/template_exercises_table.dart';
import 'package:olimpus/core/database/tables/water_intake_table.dart';
import 'package:olimpus/core/database/tables/workout_sessions_table.dart';
import 'package:olimpus/core/database/tables/workout_templates_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ExerciseSets,
    WorkoutSessions,
    WorkoutTemplates,
    TemplateExercises,
    ExerciseLibraryTable,
    WaterIntake,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? connection.connect());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Limpa apenas o catálogo público para forçar o re-seed em pt-BR sem
      // afetar dados do usuário (exercise_sets, workout_sessions, etc.).
      if (from < 2) {
        await delete(exerciseLibraryTable).go();
      }
      if (from < 3) {
        await m.createTable(templateExercises);
      }
    },
  );

  /// Apaga todos os dados do usuário das tabelas locais.
  /// Preserva a exercise_library (catálogo público).
  Future<void> deleteAllUserData() => transaction(() async {
    await delete(syncQueue).go();
    await delete(templateExercises).go();
    await delete(exerciseSets).go();
    await delete(waterIntake).go();
    await delete(workoutSessions).go();
    await delete(workoutTemplates).go();
  });
}
