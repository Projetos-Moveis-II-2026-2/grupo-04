import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';

import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/monthly_workout_summary.dart';
import '../../domain/repositories/i_progress_repository.dart';
import '../../domain/utils/calendar_utils.dart';

/// Provedor da implementação do repositório de progresso.
final progressRepositoryProvider = Provider<IProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProgressRepositoryImpl(db: db);
});

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
