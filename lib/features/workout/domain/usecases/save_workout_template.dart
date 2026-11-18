import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_template_repository.dart';

class SaveWorkoutTemplate {
  const SaveWorkoutTemplate(this._repository);

  final IWorkoutTemplateRepository _repository;

  Future<void> call(WorkoutTemplateEntity template) {
    final trimmedName = template.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('O nome da ficha não pode ser vazio.');
    }
    final normalizedExercises = [
      for (var i = 0; i < template.exercises.length; i++)
        template.exercises[i].copyWith(templateId: template.id, sortOrder: i),
    ];
    final normalizedTemplate = template.copyWith(
      name: trimmedName,
      description: template.description?.trim().isEmpty ?? true
          ? null
          : template.description!.trim(),
      clearDescription: template.description?.trim().isEmpty ?? true,
      exercises: normalizedExercises,
    );
    return _repository.saveTemplate(normalizedTemplate);
  }
}
