import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/initial_sync_service.dart';

class _MockDataSource extends Mock implements CloudPullDataSource {}

class _InMemoryStore implements InitialPullStateStore {
  bool pulled = false;

  @override
  Future<bool> hasPulled() async => pulled;

  @override
  Future<void> markPulled() async => pulled = true;
}

PullSnapshot _snapshot() => PullSnapshot(
  workoutTemplates: [
    {
      'id': 'tpl-1',
      'user_id': 'u1',
      'name': 'Push A',
      'description': null,
      'updated_at': '2026-09-01T10:00:00.000Z',
    },
  ],
  workoutSessions: [
    {
      'id': 'ses-1',
      'user_id': 'u1',
      'template_id': 'tpl-1',
      'started_at': '2026-09-02T08:00:00.000Z',
      'completed_at': '2026-09-02T09:00:00.000Z',
      'total_volume_kg': 1200.0,
      'notes': 'leg day fell',
      'updated_at': '2026-09-02T09:00:05.000Z',
    },
  ],
  exerciseSets: [
    {
      'id': 'set-r1',
      'session_id': 'ses-1',
      'exercise_id': 'ex-1',
      'set_number': 1,
      'weight_kg': 80.0,
      'reps': 10,
      'completed': true,
      'created_at': '2026-09-02T08:05:00.000Z',
      'updated_at': '2026-09-02T08:05:00.000Z',
    },
  ],
  waterIntake: [
    {
      'id': 'wat-1',
      'user_id': 'u1',
      'amount_ml': 300,
      'recorded_at': '2026-09-02T07:30:00.000Z',
      'date': '2026-09-02',
      'updated_at': '2026-09-02T07:30:00.000Z',
    },
  ],
);

void main() {
  late AppDatabase db;
  late _MockDataSource dataSource;
  late _InMemoryStore store;
  late InitialSyncService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dataSource = _MockDataSource();
    store = _InMemoryStore();
    service = InitialSyncService(db, dataSource: dataSource, stateStore: store);
  });

  tearDown(() async {
    await db.close();
  });

  test('primeiro pull insere tudo com id=remoteId e synced=true', () async {
    when(() => dataSource.fetchAll()).thenAnswer((_) async => _snapshot());

    await service.pullInitial();

    expect(await db.select(db.workoutTemplates).get(), hasLength(1));
    expect(await db.select(db.workoutSessions).get(), hasLength(1));
    final sets = await db.select(db.exerciseSets).get();
    expect(sets.single.id, 'set-r1');
    expect(sets.single.remoteId, 'set-r1');
    expect(sets.single.synced, isTrue);
    expect((await db.select(db.waterIntake).get()).single.amountMl, 300);
    verify(() => dataSource.fetchAll()).called(1);
  });

  test(
    'idempotência: pull 2× segue com 1 linha por tabela e não refetcha',
    () async {
      when(() => dataSource.fetchAll()).thenAnswer((_) async => _snapshot());

      await service.pullInitial();
      await service.pullInitial();

      expect(await db.select(db.workoutTemplates).get(), hasLength(1));
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      expect(await db.select(db.exerciseSets).get(), hasLength(1));
      expect(await db.select(db.waterIntake).get(), hasLength(1));
      verify(() => dataSource.fetchAll()).called(1); // bandeira evita refetch
    },
  );

  test(
    're-aplicar o MESMO snapshot sem bandeira não duplica (dedup remoteId)',
    () async {
      when(() => dataSource.fetchAll()).thenAnswer((_) async => _snapshot());
      await service.pullInitial();

      // Força um segundo pull (como se a bandeira tivesse sido perdida)
      store.pulled = false;
      await service.pullInitial();

      expect(await db.select(db.exerciseSets).get(), hasLength(1));
      expect(await db.select(db.waterIntake).get(), hasLength(1));
    },
  );

  test(
    'LWW: remoto mais novo sobrescreve; mais antigo NÃO sobrescreve',
    () async {
      when(() => dataSource.fetchAll()).thenAnswer((_) async => _snapshot());
      await service.pullInitial();

      // Remoto mais novo (segunda sessão do usuário em outro device)
      final newer = _snapshot()
        ..exerciseSets.first['weight_kg'] = 85.0
        ..exerciseSets.first['updated_at'] = '2026-09-03T12:00:00.000Z';
      when(() => dataSource.fetchAll()).thenAnswer((_) async => newer);
      store.pulled = false;
      await service.pullInitial();
      expect((await db.select(db.exerciseSets).get()).single.weightKg, 85.0);

      // Remoto mais antigo deve PERDER para o local (LWW)
      final older = _snapshot()
        ..exerciseSets.first['weight_kg'] = 50.0
        ..exerciseSets.first['updated_at'] = '2026-09-01T00:00:00.000Z';
      when(() => dataSource.fetchAll()).thenAnswer((_) async => older);
      store.pulled = false;
      await service.pullInitial();
      expect((await db.select(db.exerciseSets).get()).single.weightKg, 85.0);
    },
  );

  test(
    'registro local offline (remoteId null) nunca é tocado pelo pull',
    () async {
      final now = DateTime.now();
      await db
          .into(db.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 'local-offline-1',
              sessionId: 'ses-local',
              exerciseId: 'ex-1',
              setNumber: 1,
              weightKg: const Value(99.0),
              reps: const Value(5),
              updatedAt: now,
              createdAt: now,
            ),
          );

      when(() => dataSource.fetchAll()).thenAnswer((_) async => _snapshot());
      await service.pullInitial();

      final sets = await db.select(db.exerciseSets).get();
      expect(sets, hasLength(2)); // 1 offline + 1 do pull
      final offline = sets.singleWhere((s) => s.id == 'local-offline-1');
      expect(offline.weightKg, 99.0);
      expect(offline.synced, isFalse);
    },
  );

  test('bandeira marca pulled após pull bem-sucedido', () async {
    when(() => dataSource.fetchAll()).thenAnswer((_) async => _snapshot());
    expect(await store.hasPulled(), isFalse);
    await service.pullInitial();
    expect(await store.hasPulled(), isTrue);
  });
}
