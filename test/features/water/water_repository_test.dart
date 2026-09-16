import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';
import 'package:olimpus/features/water/data/repositories/water_repository_impl.dart';

class _FakeGateway implements SyncRemoteGateway {
  final List<Map<String, dynamic>> upserts = [];
  final List<Map<String, dynamic>> deletes = [];

  @override
  Future<void> upsert(String table, Map<String, dynamic> payload) async {
    upserts.add({'table': table, ...payload});
  }

  @override
  Future<void> delete(String table, String id) async {
    deletes.add({'table': table, 'id': id});
  }

  @override
  Future<void> markSynced(String table, String localId) async {}
}

void main() {
  late AppDatabase db;
  late _FakeGateway gateway;
  late SyncQueueService syncQueue;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gateway = _FakeGateway();
    syncQueue = SyncQueueService(db, gateway: gateway);
  });

  tearDown(() async {
    await db.close();
  });

  group('WaterRepositoryImpl', () {
    test('corte entre dias: registros às 23:59 e 00:01 caem em dias diferentes',
        () async {
      // Definimos o "hoje" fixo como 2026-09-16 12:00:00 (local)
      final fixedToday = DateTime(2026, 9, 16, 12, 0, 0);
      final repo = WaterRepositoryImpl(
        db: db,
        syncQueue: syncQueue,
        nowProvider: () => fixedToday,
      );

      const userId = 'user-1';

      // Registro 1: ontem às 23:59:50
      await repo.addWaterIntake(
        userId: userId,
        amountMl: 300,
        recordedAt: DateTime(2026, 9, 15, 23, 59, 50),
      );

      // Registro 2: hoje à 00:00:10
      await repo.addWaterIntake(
        userId: userId,
        amountMl: 250,
        recordedAt: DateTime(2026, 9, 16, 0, 0, 10),
      );

      // Registro 3: hoje às 11:30:00
      await repo.addWaterIntake(
        userId: userId,
        amountMl: 500,
        recordedAt: DateTime(2026, 9, 16, 11, 30, 0),
      );

      // watchTodayEntries deve conter apenas os registros do dia 16
      final todayEntries = await repo.watchTodayEntries(userId).first;
      expect(todayEntries, hasLength(2));
      expect(todayEntries[0].amountMl, 250);
      expect(todayEntries[1].amountMl, 500);

      // watchTodayTotal deve somar apenas os registros de hoje (250 + 500 = 750)
      final todayTotal = await repo.watchTodayTotal(userId).first;
      expect(todayTotal, 750);
    });

    test(
        'fuso horário: registros sincronizados em UTC são agrupados pelo fuso local',
        () async {
      final fixedNow = DateTime(2026, 9, 16, 15, 0, 0);
      final repo = WaterRepositoryImpl(
        db: db,
        syncQueue: syncQueue,
        nowProvider: () => fixedNow,
      );

      const userId = 'user-tz';

      // Suponha que o registro foi criado em UTC e salvo no banco
      // Cria um DateTime local e o converte para UTC
      final localMorning = DateTime(2026, 9, 16, 8, 30, 0);
      final utcMorning = localMorning.toUtc();

      await repo.addWaterIntake(
        userId: userId,
        amountMl: 400,
        recordedAt: utcMorning,
      );

      final entries = await repo.watchTodayEntries(userId).first;
      expect(entries, hasLength(1));
      expect(entries.first.amountMl, 400);
      // No fuso local, deve coincidir com o dia 16 às 08:30
      expect(entries.first.localRecordedAt.hour, localMorning.hour);
      expect(entries.first.localRecordedAt.minute, localMorning.minute);
    });

    test('watchLast7DaysSummary retorna exatamente 7 dias com hoje destacado',
        () async {
      // 2026-09-16 é quarta-feira ('Qua')
      final fixedToday = DateTime(2026, 9, 16, 14, 0, 0);
      final repo = WaterRepositoryImpl(
        db: db,
        syncQueue: syncQueue,
        nowProvider: () => fixedToday,
      );

      const userId = 'user-week';

      // Insere consumos em dias variados
      // Hoje (dia 16)
      await repo.addWaterIntake(
        userId: userId,
        amountMl: 600,
        recordedAt: DateTime(2026, 9, 16, 10, 0, 0),
      );
      // Ontem (dia 15)
      await repo.addWaterIntake(
        userId: userId,
        amountMl: 1200,
        recordedAt: DateTime(2026, 9, 15, 14, 0, 0),
      );
      // 4 dias atrás (dia 12)
      await repo.addWaterIntake(
        userId: userId,
        amountMl: 800,
        recordedAt: DateTime(2026, 9, 12, 9, 0, 0),
      );

      final summaries = await repo.watchLast7DaysSummary(userId).first;
      expect(summaries, hasLength(7));

      // Último elemento é hoje
      final todaySummary = summaries.last;
      expect(todaySummary.isToday, isTrue);
      expect(todaySummary.totalMl, 600);
      expect(todaySummary.date.day, 16);

      // Penúltimo elemento é ontem (dia 15)
      final yesterdaySummary = summaries[5];
      expect(yesterdaySummary.isToday, isFalse);
      expect(yesterdaySummary.totalMl, 1200);
      expect(yesterdaySummary.date.day, 15);

      // Elemento do dia 12 (índice 2)
      final day12Summary = summaries[2];
      expect(day12Summary.totalMl, 800);
      expect(day12Summary.date.day, 12);

      // Dias sem registro devem ser 0 ml
      final day14Summary = summaries[4];
      expect(day14Summary.date.day, 14);
      expect(day14Summary.totalMl, 0);
    });

    test('addWaterIntake salva no Drift e enfileira na SyncQueue', () async {
      final repo = WaterRepositoryImpl(
        db: db,
        syncQueue: syncQueue,
      );

      const userId = 'user-sync';
      final record = await repo.addWaterIntake(
        userId: userId,
        amountMl: 500,
      );

      expect(record.amountMl, 500);
      expect(record.userId, userId);
      expect(record.id, isNotEmpty);

      // Confere tabela Drift
      final rows = await db.select(db.waterIntake).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, record.id);
      expect(rows.first.amountMl, 500);
      expect(rows.first.synced, isFalse);

      // Confere fila SyncQueue
      final queued = await db.select(db.syncQueue).get();
      expect(queued, hasLength(1));
      expect(queued.first.targetTable, 'water_intake');
      expect(queued.first.recordId, record.id);
      expect(queued.first.operation, 'upsert');
    });

    test('deleteWaterIntake remove do Drift e reatividade atualiza streams',
        () async {
      final repo = WaterRepositoryImpl(
        db: db,
        syncQueue: syncQueue,
      );

      const userId = 'user-del';
      final r1 = await repo.addWaterIntake(userId: userId, amountMl: 250);
      final r2 = await repo.addWaterIntake(userId: userId, amountMl: 500);

      var entries = await repo.watchTodayEntries(userId).first;
      expect(entries, hasLength(2));

      await repo.deleteWaterIntake(r1.id);

      entries = await repo.watchTodayEntries(userId).first;
      expect(entries, hasLength(1));
      expect(entries.first.id, r2.id);

      final total = await repo.watchTodayTotal(userId).first;
      expect(total, 500);
    });
  });
}
