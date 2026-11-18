import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/progress/domain/entities/streak.dart';
import 'package:olimpus/features/progress/domain/usecases/calculate_streak.dart';

void main() {
  final today = DateTime(2026, 11, 17, 14, 30);

  group('calculateStreak', () {
    test('retorna zeros para conjunto vazio', () {
      final streak = calculateStreak(const <DateTime>{}, today: today);

      expect(streak, const Streak(current: 0, best: 0));
      expect(streak.lastActiveDay, isNull);
      expect(streak.isEmpty, isTrue);
    });

    test('conta apenas hoje', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 17, 7, 15),
      }, today: today);

      expect(streak.current, 1);
      expect(streak.best, 1);
      expect(streak.lastActiveDay, DateTime(2026, 11, 17));
    });

    test('conta hoje, ontem e anteontem', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 17, 6),
        DateTime(2026, 11, 16, 21),
        DateTime(2026, 11, 15, 12),
      }, today: today);

      expect(streak.current, 3);
      expect(streak.best, 3);
    });

    test('não quebra quando a última atividade foi ontem', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 16, 20),
        DateTime(2026, 11, 15, 9),
      }, today: today);

      expect(streak.current, 2);
      expect(streak.best, 2);
      expect(streak.lastActiveDay, DateTime(2026, 11, 16));
    });

    test('quebra com lacuna de dois dias', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 17, 8),
        // 15/11 e 16/11 ausentes.
        DateTime(2026, 11, 14, 8),
      }, today: today);

      expect(streak.current, 1);
      expect(streak.best, 1);
    });

    test('quebra quando a última atividade foi há três dias', () {
      final streak = calculateStreak({DateTime(2026, 11, 14, 8)}, today: today);

      expect(streak.current, 0);
      expect(streak.best, 1);
    });

    test('preserva recorde maior que a sequência atual', () {
      final streak = calculateStreak({
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 4),
        DateTime(2026, 10, 5),
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 17),
      }, today: today);

      expect(streak.current, 2);
      expect(streak.best, 5);
    });

    test('tolerância de 1 dia mantém a sequência com um dia de folga', () {
      final streak = calculateStreak(
        {
          DateTime(2026, 11, 17),
          // 16/11 ausente.
          DateTime(2026, 11, 15),
          DateTime(2026, 11, 14),
        },
        today: today,
        toleranceDays: 1,
      );

      expect(streak.current, 3);
      expect(streak.best, 3);
    });

    test('tolerância de 1 dia aceita última atividade há dois dias', () {
      final streak = calculateStreak(
        {DateTime(2026, 11, 15)},
        today: today,
        toleranceDays: 1,
      );

      expect(streak.current, 1);
      expect(streak.best, 1);
    });

    test('tolerância não une lacunas maiores que o permitido', () {
      final streak = calculateStreak(
        {
          DateTime(2026, 11, 17),
          // 16/11 e 15/11 ausentes.
          DateTime(2026, 11, 14),
        },
        today: today,
        toleranceDays: 1,
      );

      expect(streak.current, 1);
      expect(streak.best, 1);
    });

    test('atravessa a virada de mês e de ano', () {
      final streak = calculateStreak({
        DateTime(2025, 12, 31, 23, 50),
        DateTime(2026, 1, 1, 0, 10),
        DateTime(2026, 1, 2, 10),
      }, today: DateTime(2026, 1, 2, 18));

      expect(streak.current, 3);
      expect(streak.best, 3);
    });

    test('normaliza horários diferentes do mesmo dia', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 17, 0, 1),
        DateTime(2026, 11, 17, 23, 59),
        DateTime(2026, 11, 16, 12),
      }, today: today);

      expect(streak.current, 2);
      expect(streak.best, 2);
      expect(streak.lastActiveDay, DateTime(2026, 11, 17));
    });

    test('ignora dias futuros em relação a hoje', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 17),
        DateTime(2026, 11, 18),
        DateTime(2026, 11, 19),
      }, today: today);

      expect(streak.current, 1);
      expect(streak.best, 1);
      expect(streak.lastActiveDay, DateTime(2026, 11, 17));
    });

    test('considera o fuso local ao normalizar a data de hoje', () {
      final streak = calculateStreak({
        DateTime(2026, 11, 17, 8),
      }, today: DateTime(2026, 11, 17, 23, 59));

      expect(streak.current, 1);
    });
  });
}
