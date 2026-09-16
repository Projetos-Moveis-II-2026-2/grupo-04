import 'package:equatable/equatable.dart';

/// Entidade de domínio que representa um registro individual de consumo de água.
class WaterIntakeRecord extends Equatable {
  const WaterIntakeRecord({
    required this.id,
    required this.userId,
    required this.amountMl,
    required this.recordedAt,
    required this.date,
    this.remoteId,
    this.synced = false,
  });

  final String id;
  final String? remoteId;
  final String userId;
  final int amountMl;
  final DateTime recordedAt;
  final String date;
  final bool synced;

  /// Retorna o horário local do registro.
  DateTime get localRecordedAt => recordedAt.toLocal();

  @override
  List<Object?> get props => [
        id,
        remoteId,
        userId,
        amountMl,
        recordedAt,
        date,
        synced,
      ];
}

