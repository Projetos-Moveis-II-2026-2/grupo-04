import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/domain/entities/daily_water_summary.dart';
import 'package:olimpus/features/water/domain/entities/water_intake_record.dart';
import 'package:olimpus/features/water/domain/repositories/i_water_repository.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';

class MockWaterRepository extends Mock implements IWaterRepository {}

void main() {
  late MockWaterRepository mockRepo;

  final tUser = AppUser(
    id: 'user-1',
    email: 'test@example.com',
    emailConfirmedAt: DateTime(2026, 9, 16),
  );

  final tRecord = WaterIntakeRecord(
    id: 'record-1',
    userId: 'user-1',
    amountMl: 300,
    recordedAt: DateTime(2026, 9, 16, 10),
    date: '2026-09-16',
  );

  final tSummary = DailyWaterSummary(
    date: DateTime(2026, 9, 16),
    totalMl: 300,
    dayOfWeekAbbr: 'Qua',
    isToday: true,
  );

  setUp(() {
    mockRepo = MockWaterRepository();
  });

  ProviderContainer createContainer({required AppUser? user}) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        waterRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('streams sem usuário autenticado', () {
    test('todayWaterEntriesProvider should emit an empty list', () async {
      final container = createContainer(user: null);
      final subscription = container.listen(
        todayWaterEntriesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(todayWaterEntriesProvider);

      expect(state.value, isEmpty);
      verifyNever(() => mockRepo.watchTodayEntries(any()));
    });

    test('todayWaterTotalProvider should emit zero', () async {
      final container = createContainer(user: null);
      final subscription = container.listen(todayWaterTotalProvider, (_, _) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(todayWaterTotalProvider);

      expect(state.value, 0);
      verifyNever(() => mockRepo.watchTodayTotal(any()));
    });

    test('weeklyWaterSummaryProvider should emit an empty list', () async {
      final container = createContainer(user: null);
      final subscription = container.listen(
        weeklyWaterSummaryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(weeklyWaterSummaryProvider);

      expect(state.value, isEmpty);
      verifyNever(() => mockRepo.watchLast7DaysSummary(any()));
    });
  });

  group('streams com usuário autenticado', () {
    test(
      'todayWaterEntriesProvider should expose repository entries',
      () async {
        when(() => mockRepo.watchTodayEntries(tUser.id))
            .thenAnswer((_) => Stream.value([tRecord]));
        final container = createContainer(user: tUser);
        final subscription = container.listen(
          todayWaterEntriesProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(todayWaterEntriesProvider);

        expect(state.value, [tRecord]);
        verify(() => mockRepo.watchTodayEntries(tUser.id)).called(1);
      },
    );

    test(
      'todayWaterTotalProvider should expose the repository total',
      () async {
        when(() => mockRepo.watchTodayTotal(tUser.id))
            .thenAnswer((_) => Stream.value(750));
        final container = createContainer(user: tUser);
        final subscription = container.listen(
          todayWaterTotalProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(todayWaterTotalProvider);

        expect(state.value, 750);
        verify(() => mockRepo.watchTodayTotal(tUser.id)).called(1);
      },
    );

    test(
      'weeklyWaterSummaryProvider should expose the weekly summary',
      () async {
        when(() => mockRepo.watchLast7DaysSummary(tUser.id))
            .thenAnswer((_) => Stream.value([tSummary]));
        final container = createContainer(user: tUser);
        final subscription = container.listen(
          weeklyWaterSummaryProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(weeklyWaterSummaryProvider);

        expect(state.value, [tSummary]);
        verify(() => mockRepo.watchLast7DaysSummary(tUser.id)).called(1);
      },
    );
  });
}
