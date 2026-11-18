import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';

import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/monthly_workout_summary.dart';
import '../../domain/entities/streak.dart';
import '../../domain/repositories/i_progress_repository.dart';
import '../../domain/usecases/calculate_streak.dart';
import '../../domain/utils/calendar_utils.dart';

/// Provedor da implementação do repositório de progresso.
final progressRepositoryProvider = Provider<IProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProgressRepositoryImpl(db: db);
});

/// Fornece a data/hora atual para os cálculos de streak.
///
/// Pode ser sobrescrito em testes para fixar o "hoje".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Mês selecionado no calendário de treinos (sempre o primeiro dia do mês).
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => firstDayOfMonth(DateTime.now());

  /// Retrocede um mês.
  void previous() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  /// Avança um mês, sem ultrapassar o mês atual.
  void next() {
    final nextMonth = DateTime(state.year, state.month + 1, 1);
    final currentMonth = firstDayOfMonth(DateTime.now());
    if (nextMonth.isAfter(currentMonth)) return;
    state = nextMonth;
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

/// Stream reativo com o resumo dos treinos do mês selecionado para o
/// usuário autenticado.
final monthlyWorkoutSummaryProvider = StreamProvider<MonthlyWorkoutSummary>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final month = ref.watch(selectedMonthProvider);
  final repository = ref.watch(progressRepositoryProvider);

  if (user == null) {
    return Stream.value(
      MonthlyWorkoutSummary(
        month: firstDayOfMonth(month),
        trainedDays: const <DateTime>{},
        workoutCount: 0,
        totalVolumeKg: 0,
      ),
    );
  }

  return repository.watchMonthlySummary(user.id, month);
});

/// Streak de treinos do usuário autenticado.
///
/// Recalcula localmente sempre que as sessões mudam ou o [clockProvider] é
/// atualizado, sem depender de jobs no backend (decisão D10).
final workoutStreakProvider = StreamProvider<Streak>((ref) {
  final user = ref.watch(currentUserProvider);
  final now = ref.watch(clockProvider);

  if (user == null) {
    return Stream.value(const Streak(current: 0, best: 0));
  }

  return ref
      .watch(progressRepositoryProvider)
      .watchTrainedDays(user.id)
      .map((days) => calculateStreak(days, today: now()));
});

/// Streak de hidratação do usuário autenticado.
///
/// Um dia conta quando a soma de água atinge a meta diária já gerenciada pela
/// feature de água ([dailyWaterGoalProvider]).
final waterStreakProvider = StreamProvider<Streak>((ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value(const Streak(current: 0, best: 0));
  }

  final now = ref.watch(clockProvider);
  final dailyGoalMl = ref.watch(dailyWaterGoalProvider);

  return ref
      .watch(progressRepositoryProvider)
      .watchWaterGoalDays(user.id, dailyGoalMl)
      .map((days) => calculateStreak(days, today: now()));
});
