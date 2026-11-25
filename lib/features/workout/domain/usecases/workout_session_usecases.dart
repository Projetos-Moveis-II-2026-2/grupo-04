import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_session_repository.dart';

class StartWorkoutSession {
  const StartWorkoutSession(this._repository);

  final IWorkoutSessionRepository _repository;

  Future<String> call({
    required String userId,
    required WorkoutTemplateEntity template,
  }) {
    if (template.exercises.isEmpty) {
      throw ArgumentError('A ficha não possui exercícios.');
    }
    return _repository.startSession(userId: userId, template: template);
  }
}

class WatchWorkoutSession {
  const WatchWorkoutSession(this._repository);

  final IWorkoutSessionRepository _repository;

  Stream<WorkoutSessionEntity?> call(String sessionId) =>
      _repository.watchSession(sessionId);
}

class UpdateSessionSet {
  const UpdateSessionSet(this._repository);

  final IWorkoutSessionRepository _repository;

  Future<void> call(SessionSet set) {
    if ((set.weightKg ?? 0) < 0 || (set.reps ?? 0) < 0) {
      throw ArgumentError('Peso e repetições não podem ser negativos.');
    }
    return _repository.updateSet(set);
  }
}

class AddSessionSet {
  const AddSessionSet(this._repository);

  final IWorkoutSessionRepository _repository;

  Future<void> call({required String sessionId, required String exerciseId}) =>
      _repository.addSet(sessionId: sessionId, exerciseId: exerciseId);
}

class CompleteWorkoutSession {
  const CompleteWorkoutSession(this._repository);

  final IWorkoutSessionRepository _repository;

  Future<void> call(String sessionId) => _repository.completeSession(sessionId);
}
