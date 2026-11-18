import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/progress/domain/utils/calendar_utils.dart';

void main() {
  group('normalizeDay', () {
    test('remove horas, minutos e segundos', () {
      final result = normalizeDay(DateTime(2026, 11, 17, 14, 35, 42, 123));

      expect(result, DateTime(2026, 11, 17));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });
  });

  group('firstDayOfMonth', () {
    test('retorna o primeiro dia do mês à meia-noite', () {
      final result = firstDayOfMonth(DateTime(2026, 11, 24, 9, 30));

      expect(result, DateTime(2026, 11, 1));
    });
  });

  group('daysInMonth', () {
    test('fevereiro de ano comum tem 28 dias', () {
      expect(daysInMonth(DateTime(2026, 2)), 28);
    });

    test('fevereiro de ano bissexto tem 29 dias', () {
      expect(daysInMonth(DateTime(2024, 2)), 29);
    });

    test('abril tem 30 dias', () {
      expect(daysInMonth(DateTime(2026, 4)), 30);
    });

    test('janeiro tem 31 dias', () {
      expect(daysInMonth(DateTime(2026, 1)), 31);
    });
  });

  group('monthGrid', () {
    test('preenche o padding inicial até o primeiro dia e o final até 7', () {
      // 1º de fevereiro de 2026 é domingo (weekday 7).
      final grid = monthGrid(DateTime(2026, 2));

      expect(grid.length % 7, 0);
      expect(grid.length, 35);
      expect(grid.take(6), everyElement(isNull));
      expect(grid[6], DateTime(2026, 2, 1));
      expect(grid.whereType<DateTime>(), hasLength(28));
      expect(grid.last, isNull);
    });

    test('mês iniciado na segunda não tem padding inicial', () {
      // 1º de junho de 2026 é segunda-feira.
      final grid = monthGrid(DateTime(2026, 6));

      expect(grid.first, DateTime(2026, 6, 1));
      expect(grid.whereType<DateTime>(), hasLength(30));
      expect(grid.length, 35);
    });

    test('grade de fevereiro bissexto contém 29 dias', () {
      final grid = monthGrid(DateTime(2024, 2));
      final days = grid.whereType<DateTime>().toList();

      expect(days, hasLength(29));
      expect(days.first, DateTime(2024, 2, 1));
      expect(days.last, DateTime(2024, 2, 29));
      expect(grid.length % 7, 0);
    });

    test('respeita firstWeekday diferente de segunda', () {
      // 1º de novembro de 2026 é domingo.
      final withSundayStart = monthGrid(
        DateTime(2026, 11),
        firstWeekday: DateTime.sunday,
      );

      expect(withSundayStart.first, DateTime(2026, 11, 1));
      expect(withSundayStart.whereType<DateTime>(), hasLength(30));
    });

    test('meses de 28, 29, 30 e 31 dias geram grade múltipla de 7', () {
      for (final month in [
        DateTime(2026, 2),
        DateTime(2024, 2),
        DateTime(2026, 4),
        DateTime(2026, 1),
      ]) {
        final grid = monthGrid(month);

        expect(grid.length % 7, 0, reason: 'mês ${month.month}');
        expect(
          grid.whereType<DateTime>(),
          hasLength(daysInMonth(month)),
          reason: 'mês ${month.month}',
        );
      }
    });
  });
}
