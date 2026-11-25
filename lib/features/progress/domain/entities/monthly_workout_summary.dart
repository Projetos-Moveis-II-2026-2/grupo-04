import 'package:equatable/equatable.dart';

/// Resumo consolidado dos treinos concluídos em um mês.
class MonthlyWorkoutSummary extends Equatable {
  const MonthlyWorkoutSummary({
    required this.month,
    required this.trainedDays,
    required this.workoutCount,
    required this.totalVolumeKg,
  });

  /// Mês de referência normalizado para o primeiro dia às 00:00 (fuso local).
  final DateTime month;

  /// Dias do mês com pelo menos um treino concluído (sem hora, fuso local).
  final Set<DateTime> trainedDays;

  /// Quantidade total de treinos concluídos no mês.
  final int workoutCount;

  /// Soma do volume total (kg) dos treinos concluídos no mês.
  final double totalVolumeKg;

  /// Indica que nenhum treino foi concluído no mês.
  bool get isEmpty => workoutCount == 0;

  @override
  List<Object?> get props => [month, trainedDays, workoutCount, totalVolumeKg];
}
