import 'package:equatable/equatable.dart';

/// Item de exercício dentro de uma ficha de treino (`template_exercises`).
class TemplateExerciseItem extends Equatable {
  const TemplateExerciseItem({
    required this.id,
    required this.templateId,
    required this.exerciseId,
    required this.exerciseName,
    this.primaryMuscles,
    this.equipment,
    this.imageUrl,
    required this.sortOrder,
    this.targetSets = 3,
    this.targetReps = 10,
  });

  final String id;
  final String templateId;
  final String exerciseId;
  final String exerciseName;
  final String? primaryMuscles;
  final String? equipment;
  final String? imageUrl;
  final int sortOrder;
  final int targetSets;
  final int? targetReps;

  TemplateExerciseItem copyWith({
    String? id,
    String? templateId,
    String? exerciseId,
    String? exerciseName,
    String? primaryMuscles,
    String? equipment,
    String? imageUrl,
    int? sortOrder,
    int? targetSets,
    int? targetReps,
    bool clearTargetReps = false,
  }) {
    return TemplateExerciseItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      equipment: equipment ?? this.equipment,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      targetSets: targetSets ?? this.targetSets,
      targetReps: clearTargetReps ? null : (targetReps ?? this.targetReps),
    );
  }

  @override
  List<Object?> get props => [
    id,
    templateId,
    exerciseId,
    exerciseName,
    primaryMuscles,
    equipment,
    imageUrl,
    sortOrder,
    targetSets,
    targetReps,
  ];
}
