import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/progress/domain/entities/monthly_workout_summary.dart';
import 'package:olimpus/features/progress/domain/entities/streak.dart';
import 'package:olimpus/features/progress/domain/repositories/i_progress_repository.dart';
import 'package:olimpus/features/progress/presentation/providers/progress_providers.dart';
import 'package:olimpus/features/progress/presentation/widgets/streak_card.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';

class _FakeProgressRepository implements IProgressRepository {
  _FakeProgressRepository({
    this.trainedDays = const <DateTime>{},
    this.waterGoalDays = const <DateTime>{},
  });

  final Set<DateTime> trainedDays;
  final Set<DateTime> waterGoalDays;
  int? lastWaterGoalMl;

  @override
  Stream<MonthlyWorkoutSummary> watchMonthlySummary(
    String userId,
    DateTime month,
  ) {
    return Stream.value(
      MonthlyWorkoutSummary(
        month: DateTime(month.year, month.month),
        trainedDays: trainedDays,
        workoutCount: trainedDays.length,
        totalVolumeKg: 0,
      ),
    );
  }

  @override
  Stream<Set<DateTime>> watchTrainedDays(String userId) {
    return Stream.value(trainedDays);
  }

  @override
  Stream<Set<DateTime>> watchWaterGoalDays(String userId, int dailyGoalMl) {
    lastWaterGoalMl = dailyGoalMl;
    return Stream.value(waterGoalDays);
  }
}

class _FakeDailyWaterGoalNotifier extends DailyWaterGoalNotifier {
  _FakeDailyWaterGoalNotifier(this.goal);

  final int goal;

  @override
  int build() => goal;
}

void main() {
  const user = AppUser(
    id: 'user-1',
    email: 'atleta@olimpus.com',
    emailConfirmedAt: null,
  );

  ProviderContainer createContainer({
    required _FakeProgressRepository repository,
    required DateTime now,
    int waterGoalMl = 2000,
    bool authenticated = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(authenticated ? user : null),
        progressRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => now),
        dailyWaterGoalProvider.overrideWith(
          () => _FakeDailyWaterGoalNotifier(waterGoalMl),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Streak> readStreak(
    ProviderContainer container,
    StreamProvider<Streak> provider,
  ) async {
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    return container.read(provider.future);
  }

  group('StreakCard', () {
    testWidgets('exibe fogo, dias seguidos e recorde para treino', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCard(
              streak: Streak(current: 3, best: 5),
              type: StreakType.workout,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.text('Treino'), findsOneWidget);
      expect(find.text('3 dias seguidos'), findsOneWidget);
      expect(find.text('Recorde: 5'), findsOneWidget);
    });

    testWidgets('exibe gota, dias seguidos e recorde para hidratação', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCard(
              streak: Streak(current: 1, best: 4),
              type: StreakType.water,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
      expect(find.text('Hidratação'), findsOneWidget);
      expect(find.text('1 dia seguido'), findsOneWidget);
      expect(find.text('Recorde: 4'), findsOneWidget);
    });

    testWidgets('versão compacta mantém as informações principais', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCard(
              streak: Streak(current: 7, best: 10),
              type: StreakType.workout,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('7 dias seguidos'), findsOneWidget);
      expect(find.text('Recorde: 10'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });
  });

  group('providers de streak', () {
    test('workoutStreakProvider calcula com o clock fixo', () async {
      final repository = _FakeProgressRepository(
        trainedDays: {
          DateTime(2026, 11, 17, 7),
          DateTime(2026, 11, 16, 20),
          DateTime(2026, 11, 15, 12),
        },
      );
      final container = createContainer(
        repository: repository,
        now: DateTime(2026, 11, 17, 15),
      );

      final streak = await readStreak(container, workoutStreakProvider);

      expect(streak.current, 3);
      expect(streak.best, 3);
      expect(streak.lastActiveDay, DateTime(2026, 11, 17));
    });

    test(
      'workoutStreakProvider mantém sequência quando abre no dia seguinte',
      () async {
        final repository = _FakeProgressRepository(
          trainedDays: {DateTime(2026, 11, 16), DateTime(2026, 11, 17)},
        );

        final sameDay = createContainer(
          repository: repository,
          now: DateTime(2026, 11, 17, 15),
        );
        final nextDay = createContainer(
          repository: repository,
          now: DateTime(2026, 11, 18, 8),
        );
        final twoDaysLater = createContainer(
          repository: repository,
          now: DateTime(2026, 11, 19, 8),
        );

        expect((await readStreak(sameDay, workoutStreakProvider)).current, 2);
        expect((await readStreak(nextDay, workoutStreakProvider)).current, 2);
        expect(
          (await readStreak(twoDaysLater, workoutStreakProvider)).current,
          0,
        );
      },
    );

    test(
      'waterStreakProvider usa a meta diária existente da feature water',
      () async {
        final repository = _FakeProgressRepository(
          waterGoalDays: {DateTime(2026, 11, 17), DateTime(2026, 11, 16)},
        );
        final container = createContainer(
          repository: repository,
          now: DateTime(2026, 11, 17, 20),
          waterGoalMl: 2500,
        );

        final streak = await readStreak(container, waterStreakProvider);

        expect(streak.current, 2);
        expect(streak.best, 2);
        expect(repository.lastWaterGoalMl, 2500);
      },
    );

    test('providers retornam streak zerado sem usuário autenticado', () async {
      final repository = _FakeProgressRepository(
        trainedDays: {DateTime(2026, 11, 17)},
        waterGoalDays: {DateTime(2026, 11, 17)},
      );
      final container = createContainer(
        repository: repository,
        now: DateTime(2026, 11, 17, 20),
        authenticated: false,
      );

      expect(
        await readStreak(container, workoutStreakProvider),
        const Streak(current: 0, best: 0),
      );
      expect(
        await readStreak(container, waterStreakProvider),
        const Streak(current: 0, best: 0),
      );
    });
  });
}
