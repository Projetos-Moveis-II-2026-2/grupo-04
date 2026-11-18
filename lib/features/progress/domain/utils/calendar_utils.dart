/// Funções puras para construção do calendário mensal.
library;

/// Normaliza [date] para o início do dia (00:00) no fuso local.
DateTime normalizeDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Retorna o primeiro dia do mês de [month] às 00:00 (fuso local).
DateTime firstDayOfMonth(DateTime month) {
  final local = month.toLocal();
  return DateTime(local.year, local.month, 1);
}

/// Retorna a quantidade de dias do mês de [month].
int daysInMonth(DateTime month) {
  final first = firstDayOfMonth(month);
  return DateTime(first.year, first.month + 1, 0).day;
}

/// Monta as células da grade mensal de [month].
///
/// A lista é preenchida com `null` nas posições de padding antes do primeiro
/// dia e no final, garantindo que o total seja múltiplo de 7.
/// [firstWeekday] segue a convenção de [DateTime.weekday] (padrão: segunda).
List<DateTime?> monthGrid(
  DateTime month, {
  int firstWeekday = DateTime.monday,
}) {
  final first = firstDayOfMonth(month);
  final leadingPadding = (first.weekday - firstWeekday + 7) % 7;
  final totalDays = daysInMonth(first);

  final cells = <DateTime?>[
    ...List<DateTime?>.filled(leadingPadding, null),
    for (var day = 1; day <= totalDays; day++)
      DateTime(first.year, first.month, day),
  ];

  while (cells.length % 7 != 0) {
    cells.add(null);
  }

  return cells;
}
