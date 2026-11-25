import '../entities/streak.dart';
import '../utils/calendar_utils.dart';

/// Calcula a sequência atual e o recorde de dias ativos.
///
/// [activeDays] pode conter datas com qualquer horário; todas são normalizadas
/// para o início do dia no fuso local. Datas futuras em relação a [today] são
/// ignoradas.
///
/// Regras:
/// - [Streak.current] conta a sequência que termina hoje ou ontem. Se ainda não
///   houver atividade hoje, a sequência de ontem permanece válida.
/// - [toleranceDays] permite pular até N dias sem atividade entre dois dias
///   consecutivos (padrão `0`, estrito). A mesma tolerância é aplicada ao
///   recorde histórico.
/// - [Streak.best] é a maior sequência histórica, independente da sequência
///   atual.
/// - [Streak.lastActiveDay] é o dia ativo mais recente (até hoje).
///
/// Decisão D10: o cálculo é feito localmente sobre os dados do Drift ao abrir a
/// tela/app, sem cron ou agregação no Supabase (`pg_cron`). Assim o streak
/// funciona offline e reflete imediatamente os registros locais, sem depender
/// de sincronização ou de um job remoto.
Streak calculateStreak(
  Set<DateTime> activeDays, {
  required DateTime today,
  int toleranceDays = 0,
}) {
  assert(toleranceDays >= 0, 'toleranceDays não pode ser negativo');

  if (activeDays.isEmpty) {
    return const Streak(current: 0, best: 0);
  }

  final normalizedToday = normalizeDay(today);
  final days =
      activeDays
          .map(normalizeDay)
          .where((day) => !day.isAfter(normalizedToday))
          .toSet()
          .toList()
        ..sort();

  if (days.isEmpty) {
    return const Streak(current: 0, best: 0);
  }

  final maxGapInDays = toleranceDays + 1;

  var best = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (_daysBetween(days[i - 1], days[i]) <= maxGapInDays) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) best = run;
  }

  final lastActiveDay = days.last;
  final daysSinceLastActivity = _daysBetween(lastActiveDay, normalizedToday);

  var current = 0;
  // A sequência continua válida até `toleranceDays` dias depois de ontem.
  if (daysSinceLastActivity <= toleranceDays + 1) {
    current = 1;
    var previousDay = lastActiveDay;
    for (var i = days.length - 2; i >= 0; i--) {
      if (_daysBetween(days[i], previousDay) > maxGapInDays) break;
      current++;
      previousDay = days[i];
    }
  }

  return Streak(current: current, best: best, lastActiveDay: lastActiveDay);
}

/// Diferença em dias de calendário, imune a variações de horário de verão.
int _daysBetween(DateTime from, DateTime to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  return toUtc.difference(fromUtc).inDays;
}
