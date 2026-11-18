import 'package:equatable/equatable.dart';

/// Sequência de dias consecutivos com uma atividade concluída.
class Streak extends Equatable {
  const Streak({required this.current, required this.best, this.lastActiveDay});

  /// Quantidade de dias da sequência atual.
  final int current;

  /// Maior sequência já registrada.
  final int best;

  /// Último dia com atividade (00:00 no fuso local), se houver.
  final DateTime? lastActiveDay;

  /// Indica que não existe nenhum dia ativo registrado.
  bool get isEmpty => current == 0 && best == 0;

  @override
  List<Object?> get props => [current, best, lastActiveDay];
}
