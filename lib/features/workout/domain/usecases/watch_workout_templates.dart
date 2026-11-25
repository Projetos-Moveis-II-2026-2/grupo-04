import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';

class WatchWorkoutTemplates {
  const WatchWorkoutTemplates(this._repository);

  final IWorkoutTemplateRepository _repository;

  Stream<List<WorkoutTemplateEntity>> call(String userId) {
    return _repository.watchTemplates(userId);
  }
}
