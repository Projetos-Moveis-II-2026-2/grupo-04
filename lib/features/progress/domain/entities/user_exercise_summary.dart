import 'package:equatable/equatable.dart';

/// Representa um exercício que já possui séries registradas pelo usuário.
class UserExerciseSummary extends Equatable {
  /// Identificador do exercício (conforme registrado nas séries).
  final String exerciseId;

  /// Nome amigável do exercício (obtido da biblioteca local de exercícios).
  final String name;

  const UserExerciseSummary({required this.exerciseId, required this.name});

  @override
  List<Object?> get props => [exerciseId, name];
}
