import 'package:equatable/equatable.dart';

/// Representa o registro da carga máxima alcançada em um exercício durante uma sessão de treino.
class ExerciseLoadPoint extends Equatable {
  /// Data de início da sessão de treino.
  final DateTime date;

  /// Carga máxima (em kg) entre todas as séries completadas do exercício na sessão.
  final double maxWeightKg;

  /// Identificador da sessão de treino correspondente.
  final String sessionId;

  const ExerciseLoadPoint({
    required this.date,
    required this.maxWeightKg,
    required this.sessionId,
  });

  @override
  List<Object?> get props => [date, maxWeightKg, sessionId];
}
