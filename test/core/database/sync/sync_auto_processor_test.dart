import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';

class _MockGateway extends Mock implements SyncRemoteGateway {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('auto-processor drena a fila quando o estado vira online', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final gateway = _MockGateway();
    when(() => gateway.upsert(any(), any())).thenAnswer((_) async {});

    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncRemoteGatewayProvider.overrideWithValue(gateway),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(syncQueueServiceProvider);
    final now = DateTime.now();
    await db
        .into(db.exerciseSets)
        .insert(
          ExerciseSetsCompanion.insert(
            id: 'set-1',
            sessionId: 'session-1',
            exerciseId: 'exercise-1',
            setNumber: 1,
            updatedAt: now,
            createdAt: now,
          ),
        );
    await service.enqueue('exercise_sets', 'set-1', 'upsert', {'id': 'set-1'});

    container.listen(syncQueueAutoProcessorProvider, (_, _) {});
    await pumpEventQueue();

    verify(() => gateway.upsert('exercise_sets', any())).called(1);
    expect(await db.select(db.syncQueue).get(), isEmpty);
    final sets = await db.select(db.exerciseSets).get();
    expect(sets.single.synced, isTrue);
  });

  test('auto-processor não drena quando offline', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final gateway = _MockGateway();

    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncRemoteGatewayProvider.overrideWithValue(gateway),
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      ],
    );
    addTearDown(container.dispose);

    container.listen(syncQueueAutoProcessorProvider, (_, _) {});
    await pumpEventQueue();

    verifyNever(() => gateway.upsert(any(), any()));
  });
}
