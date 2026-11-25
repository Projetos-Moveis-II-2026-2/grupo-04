import 'package:flutter/material.dart';

/// Configurações do usuário para os lembretes de hidratação.
class WaterReminderSettings {
  /// Se os lembretes periódicos estão ativados.
  final bool enabled;

  /// Intervalo entre lembretes em horas (1, 2 ou 3).
  final int intervalHours;

  /// Hora de início da janela de lembretes (0..23).
  final int startHour;

  /// Minuto de início da janela de lembretes (0..59).
  final int startMinute;

  /// Hora de término da janela de lembretes (0..23).
  final int endHour;

  /// Minuto de término da janela de lembretes (0..59).
  final int endMinute;

  const WaterReminderSettings({
    this.enabled = false,
    this.intervalHours = 2,
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
  });

  /// Início em formato TimeOfDay.
  TimeOfDay get startTime => TimeOfDay(hour: startHour, minute: startMinute);

  /// Fim em formato TimeOfDay.
  TimeOfDay get endTime => TimeOfDay(hour: endHour, minute: endMinute);

  /// Total de minutos do horário de início desde 00:00.
  int get startMinutesSinceMidnight => startHour * 60 + startMinute;

  /// Total de minutos do horário de término desde 00:00.
  int get endMinutesSinceMidnight => endHour * 60 + endMinute;

  /// Valida se a janela é válida (término estritamente posterior ao início).
  bool get isValidWindow => endMinutesSinceMidnight > startMinutesSinceMidnight;

  /// Retorna a janela formatada em texto (ex: "08:00 - 22:00").
  String get formattedTimeWindow {
    final startH = startHour.toString().padLeft(2, '0');
    final startM = startMinute.toString().padLeft(2, '0');
    final endH = endHour.toString().padLeft(2, '0');
    final endM = endMinute.toString().padLeft(2, '0');
    return '$startH:$startM - $endH:$endM';
  }

  WaterReminderSettings copyWith({
    bool? enabled,
    int? intervalHours,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return WaterReminderSettings(
      enabled: enabled ?? this.enabled,
      intervalHours: intervalHours ?? this.intervalHours,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaterReminderSettings &&
        other.enabled == enabled &&
        other.intervalHours == intervalHours &&
        other.startHour == startHour &&
        other.startMinute == startMinute &&
        other.endHour == endHour &&
        other.endMinute == endMinute;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    intervalHours,
    startHour,
    startMinute,
    endHour,
    endMinute,
  );

  @override
  String toString() {
    return 'WaterReminderSettings(enabled: $enabled, intervalHours: $intervalHours, start: $startHour:$startMinute, end: $endHour:$endMinute)';
  }
}
