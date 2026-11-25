import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/water/domain/entities/water_reminder_settings.dart';
import 'package:olimpus/features/water/domain/water_reminder_schedule.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location location;

  setUpAll(() {
    tz.initializeTimeZones();
    location = tz.getLocation('UTC');
  });

  group('WaterReminderSettings Entity', () {
    test('possui valores padrão corretos conforme a proposta', () {
      const settings = WaterReminderSettings();

      expect(settings.enabled, isFalse);
      expect(settings.intervalHours, 2);
      expect(settings.startHour, 8);
      expect(settings.startMinute, 0);
      expect(settings.endHour, 22);
      expect(settings.endMinute, 0);
      expect(settings.startTime, const TimeOfDay(hour: 8, minute: 0));
      expect(settings.endTime, const TimeOfDay(hour: 22, minute: 0));
      expect(settings.startMinutesSinceMidnight, 8 * 60);
      expect(settings.endMinutesSinceMidnight, 22 * 60);
      expect(settings.isValidWindow, isTrue);
      expect(settings.formattedTimeWindow, '08:00 - 22:00');
    });

    test('valida se término é posterior ao início', () {
      const valid = WaterReminderSettings(
        startHour: 8,
        startMinute: 0,
        endHour: 8,
        endMinute: 30,
      );
      expect(valid.isValidWindow, isTrue);

      const equal = WaterReminderSettings(
        startHour: 8,
        startMinute: 0,
        endHour: 8,
        endMinute: 0,
      );
      expect(equal.isValidWindow, isFalse);

      const inverted = WaterReminderSettings(
        startHour: 10,
        startMinute: 0,
        endHour: 9,
        endMinute: 0,
      );
      expect(inverted.isValidWindow, isFalse);
    });

    test('copyWith preserva campos existentes e altera os solicitados', () {
      const original = WaterReminderSettings();
      final updated = original.copyWith(
        enabled: true,
        intervalHours: 3,
        startHour: 9,
        endHour: 21,
      );

      expect(updated.enabled, isTrue);
      expect(updated.intervalHours, 3);
      expect(updated.startHour, 9);
      expect(updated.endHour, 21);
      expect(updated.startMinute, 0);
      expect(updated.endMinute, 0);
    });

    test('igualdade e hashCode funcionam por valor', () {
      const a = WaterReminderSettings(enabled: true, intervalHours: 1);
      const b = WaterReminderSettings(enabled: true, intervalHours: 1);
      const c = WaterReminderSettings(enabled: false, intervalHours: 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('WaterReminderSettings'));
    });
  });

  group('calculateReminderTimes', () {
    test(
      'calcula horários padrão de 2h entre 08:00 e 22:00 (fim inclusivo)',
      () {
        const settings = WaterReminderSettings(
          intervalHours: 2,
          startHour: 8,
          startMinute: 0,
          endHour: 22,
          endMinute: 0,
        );

        final times = calculateReminderTimes(settings);

        expect(times.length, 8);
        expect(times.map((t) => '${t.hour}:${t.minute}').toList(), [
          '8:0',
          '10:0',
          '12:0',
          '14:0',
          '16:0',
          '18:0',
          '20:0',
          '22:0',
        ]);
      },
    );

    test('calcula horários com intervalo de 1h', () {
      const settings = WaterReminderSettings(
        intervalHours: 1,
        startHour: 8,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      final times = calculateReminderTimes(settings);

      expect(times.length, 4);
      expect(times.map((t) => t.hour).toList(), [8, 9, 10, 11]);
    });

    test(
      'calcula horários com intervalo de 3h quando fim não coincide exatamente',
      () {
        const settings = WaterReminderSettings(
          intervalHours: 3,
          startHour: 8,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
        );

        final times = calculateReminderTimes(settings);

        // 8, 11, 14, 17, 20 (23 ultrapassa 20)
        expect(times.length, 5);
        expect(times.map((t) => t.hour).toList(), [8, 11, 14, 17, 20]);
      },
    );

    test('retorna lista vazia para janela inválida ou intervalo nulo', () {
      const invalid = WaterReminderSettings(
        intervalHours: 2,
        startHour: 10,
        startMinute: 0,
        endHour: 8,
        endMinute: 0,
      );
      expect(calculateReminderTimes(invalid), isEmpty);

      const zeroInterval = WaterReminderSettings(
        intervalHours: 0,
        startHour: 8,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      );
      expect(calculateReminderTimes(zeroInterval), isEmpty);
    });
  });

  group('buildScheduledReminders', () {
    test('gera IDs fixos a partir de 4600 e alterna as 3 mensagens (P6a)', () {
      const settings = WaterReminderSettings(
        intervalHours: 2,
        startHour: 8,
        startMinute: 0,
        endHour: 22,
        endMinute: 0,
      );
      final now = tz.TZDateTime(location, 2026, 11, 25, 7, 0);

      final reminders = buildScheduledReminders(
        settings: settings,
        now: now,
        goalReachedToday: false,
        isAndroid: true,
      );

      expect(reminders.length, 8);
      expect(reminders.first.id, 4600);
      expect(reminders.last.id, 4607);
      expect(reminders.first.title, 'Hora de se hidratar 💧');

      // Verifica as 3 mensagens alternadas
      expect(reminders[0].body, kWaterReminderMessages[0]);
      expect(reminders[1].body, kWaterReminderMessages[1]);
      expect(reminders[2].body, kWaterReminderMessages[2]);
      expect(reminders[3].body, kWaterReminderMessages[0]);
    });

    test(
      'agenda para hoje se horário ainda não passou, e amanhã se já passou',
      () {
        const settings = WaterReminderSettings(
          intervalHours: 2,
          startHour: 8,
          startMinute: 0,
          endHour: 14,
          endMinute: 0,
        );
        // Agora é 11:00 do dia 25
        final now = tz.TZDateTime(location, 2026, 11, 25, 11, 0);

        final reminders = buildScheduledReminders(
          settings: settings,
          now: now,
          goalReachedToday: false,
          isAndroid: true,
        );

        // 08:00 e 10:00 já passaram hoje -> agendados para 26/11
        expect(reminders[0].scheduledDateTime.day, 26);
        expect(reminders[0].scheduledDateTime.hour, 8);

        expect(reminders[1].scheduledDateTime.day, 26);
        expect(reminders[1].scheduledDateTime.hour, 10);

        // 12:00 e 14:00 ainda não passaram -> agendados para hoje 25/11
        expect(reminders[2].scheduledDateTime.day, 25);
        expect(reminders[2].scheduledDateTime.hour, 12);

        expect(reminders[3].scheduledDateTime.day, 25);
        expect(reminders[3].scheduledDateTime.hour, 14);
      },
    );

    test(
      'silencia restante do dia quando meta foi batida no Android (P5a)',
      () {
        const settings = WaterReminderSettings(
          intervalHours: 2,
          startHour: 8,
          startMinute: 0,
          endHour: 16,
          endMinute: 0,
        );
        // Agora é 11:00 do dia 25
        final now = tz.TZDateTime(location, 2026, 11, 25, 11, 0);

        final reminders = buildScheduledReminders(
          settings: settings,
          now: now,
          goalReachedToday: true,
          isAndroid: true,
        );

        // TODOS os horários (inclusive os que ainda não passaram: 12, 14, 16)
        // devem ser agendados para amanhã (dia 26)
        for (final reminder in reminders) {
          expect(reminder.scheduledDateTime.day, 26);
        }
      },
    );

    test('no iOS com meta batida mantém programação diária padrão', () {
      const settings = WaterReminderSettings(
        intervalHours: 2,
        startHour: 8,
        startMinute: 0,
        endHour: 14,
        endMinute: 0,
      );
      final now = tz.TZDateTime(location, 2026, 11, 25, 11, 0);

      final reminders = buildScheduledReminders(
        settings: settings,
        now: now,
        goalReachedToday: true,
        isAndroid: false, // iOS
      );

      // Horários futuros de hoje permanecem para hoje no iOS
      expect(reminders[2].scheduledDateTime.day, 25);
      expect(reminders[2].scheduledDateTime.hour, 12);
    });

    test('ScheduledReminderItem igualdade e hashCode', () {
      final a = ScheduledReminderItem(
        id: 4600,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
        scheduledDateTime: tz.TZDateTime(location, 2026, 1, 1),
      );
      final b = ScheduledReminderItem(
        id: 4600,
        hour: 8,
        minute: 0,
        title: 'T',
        body: 'B',
        scheduledDateTime: tz.TZDateTime(location, 2026, 1, 1),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
