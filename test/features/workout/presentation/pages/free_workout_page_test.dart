import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_local_datasource.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_remote_datasource_fake.dart';
import 'package:olimpus/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/workout/presentation/pages/free_workout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Baseline Fase 0 (876 exercícios, Dart VM em Linux):
  // - mountAndLoadMs=921ms | tapOpenPumpMs=3175ms | openSettleMs=54ms
  // - filterPumpMs=589ms | builtMenuItems=876
  // - syncExercisesMs=609ms (fetchMs=606ms, inclui 500ms simulados)

  const user = AppUser(
    id: 'usuario-benchmark',
    email: 'benchmark@example.com',
    emailConfirmedAt: null,
  );

  List<ExerciseLibraryTableCompanion> generateCatalogCompanions(int count) {
    final now = DateTime(2026, 9, 16);
    return List.generate(count, (index) {
      final padded = index.toString().padLeft(4, '0');
      final name = index == 420
          ? 'Supino Reto Barra'
          : 'Exercicio Benchmark $padded';
      return ExerciseLibraryTableCompanion.insert(
        id: 'ex-$padded',
        externalId: 'ext-$padded',
        name: name,
        updatedAt: now,
      );
    });
  }

  testWidgets(
    'Fase 0 baseline: mede abertura e toque no campo Exercício com 876 itens',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);

      final localDs = ExerciseLocalDataSource(db);
      await tester.runAsync(
        () => localDs.insertExercises(generateCatalogCompanions(876)),
      );

      final mountWatch = Stopwatch()..start();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(user),
          ],
          child: const MaterialApp(home: FreeWorkoutPage()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      mountWatch.stop();

      final dropdownFinder = find.byType(DropdownMenu<Exercise>);
      expect(dropdownFinder, findsOneWidget);

      final openWatch = Stopwatch()..start();
      await tester.tap(dropdownFinder);
      await tester.pump();
      openWatch.stop();

      final settleWatch = Stopwatch()..start();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      settleWatch.stop();

      final builtMenuItems = find
          .byType(MenuItemButton, skipOffstage: false)
          .evaluate()
          .length;

      final filterWatch = Stopwatch()..start();
      await tester.enterText(dropdownFinder, 'Supino');
      await tester.pump();
      filterWatch.stop();

      debugPrint(
        '[BASELINE Fase 0 UI] '
        'mountAndLoadMs=${mountWatch.elapsedMilliseconds}ms | '
        'tapOpenPumpMs=${openWatch.elapsedMilliseconds}ms | '
        'openSettleMs=${settleWatch.elapsedMilliseconds}ms | '
        'filterPumpMs=${filterWatch.elapsedMilliseconds}ms | '
        'builtMenuItems=$builtMenuItems',
      );

      // Prova do problema no baseline: DropdownMenu constrói todos os 876 itens.
      expect(builtMenuItems, 876);
    },
  );

  test(
    'Fase 0 baseline: mede syncExercises (fetch + insert de 876 itens)',
    () async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);

      final remote = ExerciseRemoteDataSourceFake();
      final fetchWatch = Stopwatch()..start();
      final exercises = await remote.fetchExercises();
      fetchWatch.stop();

      final repo = ExerciseRepositoryImpl(ExerciseLocalDataSource(db), remote);
      final syncWatch = Stopwatch()..start();
      await repo.syncExercises();
      syncWatch.stop();

      debugPrint(
        '[BASELINE Fase 0 Sync] '
        'count=${exercises.length} | '
        'fetchMs=${fetchWatch.elapsedMilliseconds}ms (inclui 500ms fake) | '
        'syncMs=${syncWatch.elapsedMilliseconds}ms (inclui 500ms fake)',
      );

      expect(exercises, hasLength(876));
    },
  );
}
