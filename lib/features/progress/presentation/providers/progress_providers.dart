import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';

import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/exercise_load_point.dart';
import '../../domain/entities/monthly_workout_summary.dart';
import '../../domain/entities/user_exercise_summary.dart';
import '../../domain/repositories/i_progress_repository.dart';
import '../../domain/utils/calendar_utils.dart';

/// Provider do repositório de progresso.
final progressRepositoryProvider = Provider<IProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProgressRepositoryImpl(db: db);
});

/// Stream reativo com a lista de exercícios que possuem séries registradas pelo usuário.
final userExercisesWithProgressProvider =
    StreamProvider<List<UserExerciseSummary>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user == null) return Stream.value(const []);

      final repo = ref.watch(progressRepositoryProvider);
      return repo.watchUserExercisesWithLogs(user.id);
    });

/// Notifier que gerencia a seleção manual de exercício pelo usuário.
class SelectedExerciseNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? exerciseId) {
    state = exerciseId;
  }
}

final selectedExerciseIdProvider =
    NotifierProvider<SelectedExerciseNotifier, String?>(
      SelectedExerciseNotifier.new,
    );

/// Provider que resolve o exercício ativo para o gráfico.
///
/// Caso o usuário ainda não tenha selecionado manualmente, seleciona
/// o primeiro exercício da lista disponível por padrão.
final activeExerciseIdProvider = Provider<String?>((ref) {
  final manualSelection = ref.watch(selectedExerciseIdProvider);
  if (manualSelection != null) return manualSelection;

  final exercisesAsync = ref.watch(userExercisesWithProgressProvider);
  return exercisesAsync.value?.firstOrNull?.exerciseId;
});

/// Stream reativo com a evolução de carga (pontos de carga máxima por sessão)
/// do exercício ativo.
final exerciseLoadProgressionProvider = StreamProvider<List<ExerciseLoadPoint>>(
  (ref) {
    final user = ref.watch(currentUserProvider);
    final exerciseId = ref.watch(activeExerciseIdProvider);

    if (user == null || exerciseId == null) {
      return Stream.value(const []);
    }

    final repo = ref.watch(progressRepositoryProvider);
    return repo.watchExerciseLoadProgression(
      userId: user.id,
      exerciseId: exerciseId,
    );
  },
);

/// Stream reativo que indica se o usuário possui dados gerados pelo seeder de demonstração.
final hasDemoDataProgressionProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(false);

  final repo = ref.watch(progressRepositoryProvider);
  return repo.watchHasDemoData(user.id);
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
