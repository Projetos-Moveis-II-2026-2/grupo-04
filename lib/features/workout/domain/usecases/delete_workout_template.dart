import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';

class DeleteWorkoutTemplate {
  const DeleteWorkoutTemplate(this._repository);

  final IWorkoutTemplateRepository _repository;

  Future<void> call(String templateId) {
    return _repository.deleteTemplate(templateId);
  }
}
