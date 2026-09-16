import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';

import '../../data/repositories/water_repository_impl.dart';
import '../../domain/entities/daily_water_summary.dart';
import '../../domain/entities/water_intake_record.dart';
import '../../domain/repositories/i_water_repository.dart';

/// Provedor da implementação do repositório de água.
final waterRepositoryProvider = Provider<IWaterRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final syncQueue = ref.watch(syncQueueServiceProvider);
  return WaterRepositoryImpl(
    db: db,
    syncQueue: syncQueue,
  );
});

/// Stream reativo com os registros de água do dia de hoje para o usuário atual.
final todayWaterEntriesProvider =
    StreamProvider<List<WaterIntakeRecord>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  final repo = ref.watch(waterRepositoryProvider);
  return repo.watchTodayEntries(user.id);
});

/// Stream reativo com o volume total de água (em ml) consumido hoje.
///
/// Também é o provider oficial para ser consumido pela barra de hidratação (Issue #25).
final todayWaterTotalProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  final repo = ref.watch(waterRepositoryProvider);
  return repo.watchTodayTotal(user.id);
});

/// Stream reativo com o consolidado dos últimos 7 dias (incluindo hoje).
final weeklyWaterSummaryProvider =
    StreamProvider<List<DailyWaterSummary>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  final repo = ref.watch(waterRepositoryProvider);
  return repo.watchLast7DaysSummary(user.id);
});

const _kDailyWaterGoalKey = 'daily_water_goal_ml';

/// Gerencia e persiste a meta diária de consumo de água (em ml).
class DailyWaterGoalNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final user = ref.watch(currentUserProvider);
    final userKey =
        user != null ? '${_kDailyWaterGoalKey}_${user.id}' : _kDailyWaterGoalKey;

    if (user != null) {
      _fetchRemoteGoal(user.id);
    }

    return prefs.getInt(userKey) ??
        prefs.getInt(_kDailyWaterGoalKey) ??
        2000;
  }

  Future<void> _fetchRemoteGoal(String userId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final data = await client
          .from('profiles')
          .select('daily_water_goal_ml')
          .eq('id', userId)
          .maybeSingle();
      if (data != null && data['daily_water_goal_ml'] != null) {
        final remoteGoal = data['daily_water_goal_ml'] as int;
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setInt('${_kDailyWaterGoalKey}_$userId', remoteGoal);
        if (state != remoteGoal) {
          state = remoteGoal;
        }
      }
    } catch (_) {}
  }

  Future<void> setGoal(int goalMl) async {
    state = goalMl;
    final prefs = ref.read(sharedPreferencesProvider);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await prefs.setInt('${_kDailyWaterGoalKey}_${user.id}', goalMl);
      try {
        final client = ref.read(supabaseClientProvider);
        await client
            .from('profiles')
            .update({'daily_water_goal_ml': goalMl}).eq('id', user.id);
      } catch (_) {
        // Falhas silenciosas de rede não bloqueiam persistência local
      }
    } else {
      await prefs.setInt(_kDailyWaterGoalKey, goalMl);
    }
  }
}

final dailyWaterGoalProvider =
    NotifierProvider<DailyWaterGoalNotifier, int>(DailyWaterGoalNotifier.new);

