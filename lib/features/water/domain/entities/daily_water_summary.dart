import 'package:equatable/equatable.dart';

/// Entidade de domínio para o resumo diário de consumo de água (usado no mini gráfico).
class DailyWaterSummary extends Equatable {
  const DailyWaterSummary({
    required this.date,
    required this.totalMl,
    required this.dayOfWeekAbbr,
    required this.isToday,
  });

  /// Data do dia correspondente (00:00:00 no fuso local).
  final DateTime date;

  /// Volume total de água consumido no dia em mililitros.
  final int totalMl;

  /// Abreviação do dia da semana (ex: 'Seg', 'Ter', 'Qua', etc.).
  final String dayOfWeekAbbr;

  /// Indica se esta data é o dia de hoje.
  final bool isToday;

  @override
  List<Object?> get props => [date, totalMl, dayOfWeekAbbr, isToday];
}

