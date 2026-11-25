import 'package:equatable/equatable.dart';

/// Projeção leve de exercício usada em seletores para evitar carregar
/// instruções, grupos musculares e URLs de imagem em memória.
class ExerciseOption extends Equatable {
  final String id;
  final String name;

  const ExerciseOption({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
