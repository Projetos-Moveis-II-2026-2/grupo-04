import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/sync/sync_providers.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/workout/data/datasources/workout_session_local_datasource.dart';
import 'package:olimpus/features/workout/data/repositories/workout_session_repository_impl.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_session_repository.dart';
import 'package:olimpus/features/workout/domain/usecases/workout_session_usecases.dart';

// ── Datasource & Repository ──

final workoutSessionLocalDataSourceProvider =
    Provider<WorkoutSessionLocalDataSource>((ref) {
      return WorkoutSessionLocalDataSource(ref.watch(appDatabaseProvider));
    });

final workoutSessionRepositoryProvider = Provider<IWorkoutSessionRepository>((
  ref,
) {
  return WorkoutSessionRepositoryImpl(
    localDataSource: ref.watch(workoutSessionLocalDataSourceProvider),
    syncQueueService: ref.watch(syncQueueServiceProvider),
  );
});

// ── UseCases ──

final startWorkoutSessionUseCaseProvider = Provider<StartWorkoutSession>((ref) {
  return StartWorkoutSession(ref.watch(workoutSessionRepositoryProvider));
});

final watchWorkoutSessionUseCaseProvider = Provider<WatchWorkoutSession>((ref) {
  return WatchWorkoutSession(ref.watch(workoutSessionRepositoryProvider));
});

final updateSessionSetUseCaseProvider = Provider<UpdateSessionSet>((ref) {
  return UpdateSessionSet(ref.watch(workoutSessionRepositoryProvider));
});

final addSessionSetUseCaseProvider = Provider<AddSessionSet>((ref) {
  return AddSessionSet(ref.watch(workoutSessionRepositoryProvider));
});

final completeWorkoutSessionUseCaseProvider = Provider<CompleteWorkoutSession>((
  ref,
) {
  return CompleteWorkoutSession(ref.watch(workoutSessionRepositoryProvider));
});

// ── Streams ──

/// Sessão em execução, reativa a cada alteração de série.
final workoutSessionStreamProvider =
    StreamProvider.family<WorkoutSessionEntity?, String>((ref, sessionId) {
      return ref.watch(watchWorkoutSessionUseCaseProvider)(sessionId);
    });
