import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';

class GetWorkoutTemplate {
  const GetWorkoutTemplate(this._repository);

  final IWorkoutTemplateRepository _repository;

  Future<WorkoutTemplateEntity?> call(String templateId) {
    return _repository.getTemplateById(templateId);
  }
}
