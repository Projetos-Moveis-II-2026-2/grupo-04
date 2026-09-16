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

  /// Retorna o horário local do registro, garantindo correspondência com a data do registro.
  DateTime get localRecordedAt {
    final local = recordedAt.toLocal();
    final localStr =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    if (date.isNotEmpty && date != localStr) {
      try {
        final parts = date.split('-').map(int.parse).toList();
        if (parts.length == 3) {
          return DateTime(
            parts[0],
            parts[1],
            parts[2],
            recordedAt.hour,
            recordedAt.minute,
            recordedAt.second,
          );
        }
      } catch (_) {}
    }
    return local;
  }

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

