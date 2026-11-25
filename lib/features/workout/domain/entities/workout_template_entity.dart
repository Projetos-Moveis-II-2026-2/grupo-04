import 'package:equatable/equatable.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';

/// Ficha de treino do usuário (`workout_templates` + lista ordenada de `template_exercises`).
class WorkoutTemplateEntity extends Equatable {
  const WorkoutTemplateEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.exercises = const [],
    this.synced = false,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final List<TemplateExerciseItem> exercises;
  final bool synced;
  final DateTime updatedAt;

  WorkoutTemplateEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    bool clearDescription = false,
    List<TemplateExerciseItem>? exercises,
    bool? synced,
    DateTime? updatedAt,
  }) {
    return WorkoutTemplateEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      exercises: exercises ?? this.exercises,
      synced: synced ?? this.synced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    description,
    exercises,
    synced,
    updatedAt,
  ];
}
