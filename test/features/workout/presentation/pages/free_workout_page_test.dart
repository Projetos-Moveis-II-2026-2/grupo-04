import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/providers/action_feedback_provider.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_local_datasource.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_remote_datasource_fake.dart';
import 'package:olimpus/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';
import 'package:olimpus/features/exercise/domain/repositories/i_exercise_repository.dart';
import 'package:olimpus/features/exercise/presentation/providers/exercise_providers.dart';
import 'package:olimpus/features/workout/presentation/pages/free_workout_page.dart';
import 'package:olimpus/features/workout/presentation/providers/free_workout_exercises_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

class _FakeActionFeedback extends ActionFeedback {
  _FakeActionFeedback([this._onPlay]);

  final void Function(bool lightImpact)? _onPlay;

  @override
  ActionFeedbackSettings build() => (vibration: true, sound: false);

  @override
  Future<void> play({bool lightImpact = false}) async {
    _onPlay?.call(lightImpact);
  }
}

class _SpyExerciseRepository implements IExerciseRepository {
  _SpyExerciseRepository({this.onSearch, this.onSync});

  final Future<List<ExerciseOption>> Function(
    String query,
    int limit,
    int offset,
  )?
  onSearch;
  final Future<void> Function()? onSync;
  int syncCalls = 0;

  @override
  Future<List<ExerciseOption>> searchByName(
    String query, {
    int limit = 30,
    int offset = 0,
  }) {
    final handler = onSearch;
    if (handler != null) {
      return handler(query, limit, offset);
    }
    return Future.value(const []);
  }

  @override
  Future<void> syncExercises() async {
    syncCalls++;
    await onSync?.call();
  }

  @override
  Stream<List<Exercise>> watchExercises() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Comparativo Fase 0 (Baseline) vs Depois (876 exercícios, Dart VM Linux):
  // - Baseline Fase 0: mountAndLoadMs=921ms | tapOpenPumpMs=3175ms |
  //   openSettleMs=54ms | filterPumpMs=589ms | builtMenuItems=876 |
  //   syncExercisesMs=609ms (inclui 500ms simulados)
  // - Depois Fase 4:   mountAndLoadMs=761ms | tapOpenPumpMs=225ms |
  //   openSettleMs=101ms | filterPumpMs=75ms | builtListItems=5 |
  //   syncExercisesMs=137ms (parse em isolate + insert em lotes)
  const user = AppUser(
    id: 'usuario-teste',
    email: 'teste@example.com',
    emailConfirmedAt: null,
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  AppDatabase createInMemoryDb() {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    return db;
  }

  List<ExerciseLibraryTableCompanion> generateCatalogCompanions(int count) {
    final now = DateTime(2026, 9, 16);
    return List.generate(count, (index) {
      final padded = index.toString().padLeft(4, '0');
      final name = switch (index) {
        420 => 'Supino Reto Barra',
        >= 100 && < 140 => 'Supino Variante $padded',
        _ => 'Exercicio Catalogo $padded',
      };
      return ExerciseLibraryTableCompanion.insert(
        id: 'ex-$padded',
        externalId: 'ext-$padded',
        name: name,
        updatedAt: now,
      );
    });
  }

  Future<void> pumpFreeWorkout(
    WidgetTester tester, {
    required AppDatabase db,
    List<dynamic> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(user),
          ...extraOverrides.cast(),
        ],
        child: const MaterialApp(home: FreeWorkoutPage()),
      ),
    );
  }

  testWidgets(
    'benchmark e catálogo com 876 itens: seletor abre rápido e constrói <= 30 itens',
    (tester) async {
      final db = createInMemoryDb();
      final localDs = ExerciseLocalDataSource(db);
      await tester.runAsync(
        () => localDs.insertExercises(generateCatalogCompanions(876)),
      );

      final mountWatch = Stopwatch()..start();
      await pumpFreeWorkout(tester, db: db);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      mountWatch.stop();

      expect(
        find.byType(DropdownMenu<dynamic>, skipOffstage: false),
        findsNothing,
      );
      final fieldFinder = find.byKey(const Key('free_workout_exercise_field'));
      expect(fieldFinder, findsOneWidget);

      final openWatch = Stopwatch()..start();
      await tester.tap(fieldFinder);
      await tester.pump();
      openWatch.stop();

      final settleWatch = Stopwatch()..start();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      settleWatch.stop();

      final resultsListFinder = find.byKey(
        const Key('free_workout_exercise_results_list'),
      );
      expect(resultsListFinder, findsOneWidget);

      final builtListItems = find
          .descendant(
            of: resultsListFinder,
            matching: find.byType(ListTile, skipOffstage: false),
          )
          .evaluate()
          .length;

      expect(builtListItems, lessThan(100));
      expect(builtListItems, lessThanOrEqualTo(kExercisePickerPageSize));

      // Filtra por termo com 41 correspondências -> limitado a 30 no banco.
      final searchFieldFinder = find.byKey(
        const Key('free_workout_exercise_search_field'),
      );
      final filterWatch = Stopwatch()..start();
      await tester.enterText(searchFieldFinder, 'Supino');
      await tester.pump(const Duration(milliseconds: 260));
      filterWatch.stop();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final limitedListView = tester.widget<ListView>(resultsListFinder);
      expect(limitedListView.semanticChildCount, kExercisePickerPageSize + 1);
      final filteredBuiltItems = find
          .descendant(
            of: resultsListFinder,
            matching: find.byType(ListTile, skipOffstage: false),
          )
          .evaluate()
          .length;
      expect(filteredBuiltItems, lessThanOrEqualTo(kExercisePickerPageSize));

      // Busca específica retorna exatamente 1 item na lista de resultados.
      await tester.enterText(searchFieldFinder, 'Supino Reto Barra');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.descendant(
          of: resultsListFinder,
          matching: find.text('Supino Reto Barra'),
        ),
        findsOneWidget,
      );

      // Busca sem resultado exibe estado vazio.
      await tester.enterText(searchFieldFinder, 'exercicio-inexistente-xyz');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Nenhum exercício encontrado'), findsOneWidget);

      // Limpar busca restaura a listagem limitada.
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Nenhum exercício encontrado'), findsNothing);
      expect(resultsListFinder, findsOneWidget);

      debugPrint(
        '[DEPOIS Fase 4 UI] '
        'mountAndLoadMs=${mountWatch.elapsedMilliseconds}ms | '
        'tapOpenPumpMs=${openWatch.elapsedMilliseconds}ms | '
        'openSettleMs=${settleWatch.elapsedMilliseconds}ms | '
        'filterPumpMs=${filterWatch.elapsedMilliseconds}ms | '
        'builtListItems=$builtListItems',
      );
    },
  );

  test('benchmark Fase 4 syncExercises: mede fetch em isolate + insert em lotes (876 itens)', () async {
    final db = createInMemoryDb();
    final repo = ExerciseRepositoryImpl(
      ExerciseLocalDataSource(db),
      ExerciseRemoteDataSourceFake(),
    );

    final syncWatch = Stopwatch()..start();
    await repo.syncExercises();
    syncWatch.stop();

    final options = await repo.searchByName('', limit: 1000);
    expect(options, hasLength(876));

    debugPrint(
      '[DEPOIS Fase 4 Sync] count=${options.length} | '
      'syncMs=${syncWatch.elapsedMilliseconds}ms',
    );
  });

  testWidgets(
    'valida erro quando nenhum exercício foi selecionado e permite concluir série ao selecionar',
    (tester) async {
      final db = createInMemoryDb();
      await tester.runAsync(
        () => ExerciseLocalDataSource(db).insertExercises([
          ExerciseLibraryTableCompanion.insert(
            id: 'supino-reto',
            externalId: 'supino-reto',
            name: 'Supino Reto',
            updatedAt: DateTime(2026, 9, 16),
          ),
        ]),
      );

      await pumpFreeWorkout(tester, db: db);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tenta concluir série sem selecionar exercício.
      await tester.enterText(find.byType(TextFormField).first, '60');
      await tester.enterText(find.byType(TextFormField).last, '10');
      await tester.tap(find.text('Concluir série'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Selecione um exercício.'), findsOneWidget);
      expect(await db.select(db.exerciseSets).get(), isEmpty);

      // Seleciona o exercício no bottom sheet e conclui a série.
      await tester.tap(find.byKey(const Key('free_workout_exercise_field')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.text('Supino Reto'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Selecione um exercício.'), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('free_workout_exercise_field')),
      );
      expect(field.controller?.text, 'Supino Reto');

      await tester.tap(find.text('Concluir série'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Séries concluídas neste treino: 1'), findsOneWidget);
      final savedSet = await db.select(db.exerciseSets).getSingle();
      expect(savedSet.exerciseId, 'supino-reto');
      expect(savedSet.weightKg, 60.0);
      expect(savedSet.reps, 10);
    },
  );

  testWidgets('exibe estado loading do catálogo no campo e no seletor', (
    tester,
  ) async {
    final db = createInMemoryDb();

    await pumpFreeWorkout(
      tester,
      db: db,
      extraOverrides: [
        workoutCatalogReadyProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    await tester.pump();
    expect(find.text('Carregando catálogo…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('free_workout_exercise_field')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Carregando catálogo…'), findsNWidgets(2));
  });

  testWidgets('exibe estado erro do catálogo e recupera com Tentar de novo', (
    tester,
  ) async {
    final db = createInMemoryDb();
    var shouldFail = true;

    await pumpFreeWorkout(
      tester,
      db: db,
      extraOverrides: [
        workoutCatalogReadyProvider.overrideWith((ref) async {
          if (shouldFail) {
            throw Exception('falha ao carregar');
          }
        }),
        workoutExerciseSearchProvider.overrideWithBuild(
          (ref, notifier) async => const ExerciseSearchPageState(
            items: [ExerciseOption(id: 'agachamento', name: 'Agachamento')],
            hasMore: false,
          ),
        ),
      ],
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Erro ao carregar exercícios.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('free_workout_exercise_field')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Tentar de novo'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Agachamento'), findsOneWidget);
  });

  testWidgets('descarta resposta antiga quando nova busca resolve antes', (
    tester,
  ) async {
    final db = createInMemoryDb();
    final slowQuery = Completer<List<ExerciseOption>>();
    final fastQuery = Completer<List<ExerciseOption>>();

    final spyRepo = _SpyExerciseRepository(
      onSearch: (query, limit, offset) {
        if (query.isEmpty) {
          return Future.value(const [
            ExerciseOption(id: 'init', name: 'Inicial'),
          ]);
        }
        if (query == 'a') return slowQuery.future;
        if (query == 'ab') return fastQuery.future;
        return Future.value(const []);
      },
    );

    await pumpFreeWorkout(
      tester,
      db: db,
      extraOverrides: [exerciseRepositoryProvider.overrideWithValue(spyRepo)],
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.byKey(const Key('free_workout_exercise_field')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final searchFinder = find.byKey(
      const Key('free_workout_exercise_search_field'),
    );
    await tester.enterText(searchFinder, 'a');
    await tester.pump(const Duration(milliseconds: 260));

    // Digita 'ab' antes da resposta lenta de 'a'.
    await tester.enterText(searchFinder, 'ab');
    await tester.pump(const Duration(milliseconds: 260));

    fastQuery.complete(const [
      ExerciseOption(id: 'ab-1', name: 'Abdominal Supra'),
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Resposta obsoleta chega atrasada e não deve sobrescrever os resultados.
    slowQuery.complete(const [
      ExerciseOption(id: 'a-1', name: 'Agachamento Antigo'),
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Abdominal Supra'), findsOneWidget);
    expect(find.text('Agachamento Antigo'), findsNothing);
  });

  testWidgets('dispara sync único quando a tabela local inicia vazia', (
    tester,
  ) async {
    final db = createInMemoryDb();
    final syncCompleter = Completer<void>();
    var seeded = false;

    final spyRepo = _SpyExerciseRepository(
      onSearch: (query, limit, offset) async {
        if (!seeded) return const [];
        return const [ExerciseOption(id: 'ex-1', name: 'Remada Curvada')];
      },
      onSync: () async {
        await syncCompleter.future;
        seeded = true;
      },
    );

    await pumpFreeWorkout(
      tester,
      db: db,
      extraOverrides: [exerciseRepositoryProvider.overrideWithValue(spyRepo)],
    );
    await tester.pump();

    expect(find.text('Carregando catálogo…'), findsOneWidget);
    expect(spyRepo.syncCalls, 1);

    // Rebuilds enquanto carrega não disparam novo sync.
    await tester.pump(const Duration(milliseconds: 50));
    expect(spyRepo.syncCalls, 1);

    syncCompleter.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Carregando catálogo…'), findsNothing);
    expect(spyRepo.syncCalls, 1);
  });

  group('FreeWorkoutPage Cobertura Issue #55', () {
    testWidgets('sem usuário exibe apenas AppBar sem corpo do treino', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const FreeWorkoutPage(),
        overrides: [currentUserProvider.overrideWithValue(null)],
      );
      await tester.pump();

      expect(find.text('Treino livre'), findsOneWidget);
      expect(find.textContaining('Séries concluídas'), findsNothing);
      expect(
        find.byKey(const Key('free_workout_exercise_field')),
        findsNothing,
      );
      expect(find.text('Iniciar timer'), findsNothing);
    });

    testWidgets(
      'exibe estado vazio no ExercisePickerSheet quando catálogo está vazio',
      (tester) async {
        final db = createInMemoryDb();
        final spyRepo = _SpyExerciseRepository(
          onSearch: (_, _) async => const [],
        );

        await pumpApp(
          tester,
          child: const FreeWorkoutPage(),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(user),
            exerciseRepositoryProvider.overrideWithValue(spyRepo),
            actionFeedbackProvider.overrideWith(_FakeActionFeedback.new),
          ],
        );
        await tester.pumpAndSettleBounded();

        await tester.tap(find.byKey(const Key('free_workout_exercise_field')));
        await tester.pumpAndSettleBounded();

        expect(find.text('Selecionar exercício'), findsOneWidget);
        expect(find.text('Nenhum exercício encontrado'), findsOneWidget);
      },
    );

    testWidgets(
      'valida carga/repetições, registra série pelo sheet com feedback tátil, controla timer e conclui treino',
      (tester) async {
        final db = createInMemoryDb();
        await tester.runAsync(
          () => ExerciseLocalDataSource(db).insertExercises([
            ExerciseLibraryTableCompanion.insert(
              id: 'ex-supino',
              externalId: 'supino',
              name: 'Supino Reto',
              updatedAt: DateTime(2026, 9, 16),
            ),
            ExerciseLibraryTableCompanion.insert(
              id: 'ex-agachamento',
              externalId: 'agachamento',
              name: 'Agachamento',
              updatedAt: DateTime(2026, 9, 16),
            ),
          ]),
        );

        final playCalls = <bool>[];

        await pumpApp(
          tester,
          child: const FreeWorkoutPage(),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(user),
            actionFeedbackProvider.overrideWith(
              () => _FakeActionFeedback(playCalls.add),
            ),
          ],
        );
        await tester.pumpAndSettleBounded();

        expect(find.text('Séries concluídas neste treino: 0'), findsOneWidget);
        expect(
          find.byKey(const Key('free_workout_exercise_field')),
          findsOneWidget,
        );

        // Valida campos sem selecionar exercício e sem valores válidos.
        await tester.tap(find.text('Concluir série'));
        await tester.pump();
        expect(find.text('Selecione um exercício.'), findsOneWidget);
        expect(find.text('Informe uma carga válida.'), findsOneWidget);
        expect(
          find.text('Informe um número de repetições maior que zero.'),
          findsOneWidget,
        );
        expect(playCalls, isEmpty);

        // Abre o ExercisePickerSheet e seleciona Supino Reto.
        await tester.tap(find.byKey(const Key('free_workout_exercise_field')));
        await tester.pumpAndSettleBounded();
        expect(find.text('Supino Reto'), findsOneWidget);
        expect(find.text('Agachamento'), findsOneWidget);
        await tester.tap(find.text('Supino Reto'));
        await tester.pumpAndSettleBounded();

        // Preenche carga e repetições válidas e conclui a série.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Carga (kg)'),
          '60,5',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Repetições'),
          '12',
        );
        await tester.tap(find.text('Concluir série'));
        await tester.pumpAndSettleBounded();

        expect(find.text('Séries concluídas neste treino: 1'), findsOneWidget);
        expect(find.text('Série concluída'), findsOneWidget);
        expect(playCalls, [false]);
        expect(find.text('Concluir treino'), findsOneWidget);

        // Timer de descanso aciona feedback leve e pode ser interrompido.
        await tester.ensureVisible(find.text('Iniciar timer'));
        await tester.tap(find.text('Iniciar timer'));
        await tester.pump();
        expect(find.text('Parar timer'), findsOneWidget);
        expect(playCalls, [false, true]);

        await tester.tap(find.text('Parar timer'));
        await tester.pump();
        expect(find.text('Iniciar timer'), findsOneWidget);

        // Conclui o treino.
        await tester.ensureVisible(find.text('Concluir treino'));
        await tester.tap(find.text('Concluir treino'));
        await tester.pumpAndSettleBounded();
        expect(find.text('Treino concluído'), findsOneWidget);
        expect(find.text('Séries concluídas neste treino: 0'), findsOneWidget);
      },
    );
  });
}
