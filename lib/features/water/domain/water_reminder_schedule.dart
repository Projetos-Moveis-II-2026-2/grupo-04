import 'package:timezone/timezone.dart' as tz;

import 'entities/water_reminder_settings.dart';

/// Título padrão para as notificações de hidratação.
const String kWaterReminderTitle = 'Hora de se hidratar 💧';

/// Mensagens alternadas para os lembretes (Decisão aprovada P6a).
const List<String> kWaterReminderMessages = [
  'Que tal um copo de água agora? Toque para registrar.',
  'Pausa para hidratação: beba água e registre no Olimpus.',
  'Constância é o segredo. Bora beber um copo d\'água?',
];

/// ID inicial dos alarmes de hidratação (4600..4699).
const int kWaterReminderBaseId = 4600;

/// Representação de um lembrete calculado para agendamento.
class ScheduledReminderItem {
  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
  final tz.TZDateTime scheduledDateTime;

  const ScheduledReminderItem({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
    required this.scheduledDateTime,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduledReminderItem &&
        other.id == id &&
        other.hour == hour &&
        other.minute == minute &&
        other.title == title &&
        other.body == body &&
        other.scheduledDateTime == scheduledDateTime;
  }

  @override
  int get hashCode =>
      Object.hash(id, hour, minute, title, body, scheduledDateTime);
}

/// Calcula a lista de horários (hora e minuto) dentro da janela configurada.
///
/// A janela inclui o horário de término se o intervalo coincidir exatamente (fim inclusivo).
List<({int hour, int minute})> calculateReminderTimes(
  WaterReminderSettings settings,
) {
  if (!settings.isValidWindow || settings.intervalHours <= 0) {
    return const [];
  }

  final times = <({int hour, int minute})>[];
  final startMinutes = settings.startMinutesSinceMidnight;
  final endMinutes = settings.endMinutesSinceMidnight;
  final stepMinutes = settings.intervalHours * 60;

  var current = startMinutes;
  while (current <= endMinutes) {
    final h = current ~/ 60;
    final m = current % 60;
    times.add((hour: h, minute: m));
    current += stepMinutes;
  }

  return times;
}

/// Constrói os lembretes com data de primeiro disparo e rotação de mensagens.
///
/// Lógica de agendamento (Decisão aprovada P5a):
/// - Se [goalReachedToday] for `true` e [isAndroid] for `true`, todos os lembretes
///   são agendados com primeiro disparo para amanhã, silenciando o restante do dia
///   de hoje sem perder a recorrência diária.
/// - Caso contrário, para cada horário: se hoje naquele horário já passou de [now],
///   o primeiro disparo é amanhã; se ainda for no futuro hoje, o primeiro disparo é hoje.
List<ScheduledReminderItem> buildScheduledReminders({
  required WaterReminderSettings settings,
  required tz.TZDateTime now,
  required bool goalReachedToday,
  bool isAndroid = true,
}) {
  final times = calculateReminderTimes(settings);
  final items = <ScheduledReminderItem>[];

  for (var i = 0; i < times.length; i++) {
    final t = times[i];
    final id = kWaterReminderBaseId + i;
    final title = kWaterReminderTitle;
    final body = kWaterReminderMessages[i % kWaterReminderMessages.length];

    final todayAtTime = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      t.hour,
      t.minute,
    );

    final tz.TZDateTime firstTrigger;
    if (goalReachedToday && isAndroid) {
      firstTrigger = todayAtTime.add(const Duration(days: 1));
    } else if (todayAtTime.isAfter(now)) {
      firstTrigger = todayAtTime;
    } else {
      firstTrigger = todayAtTime.add(const Duration(days: 1));
    }

    items.add(
      ScheduledReminderItem(
        id: id,
        hour: t.hour,
        minute: t.minute,
        title: title,
        body: body,
        scheduledDateTime: firstTrigger,
      ),
    );
  }

  return items;
}
