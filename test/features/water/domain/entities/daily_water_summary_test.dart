import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/water/domain/entities/daily_water_summary.dart';

void main() {
  DailyWaterSummary buildSummary({
    int totalMl = 1500,
    String dayOfWeekAbbr = 'Qua',
    bool isToday = true,
  }) {
    return DailyWaterSummary(
      date: DateTime(2026, 9, 16),
      totalMl: totalMl,
      dayOfWeekAbbr: dayOfWeekAbbr,
      isToday: isToday,
    );
  }

  test('should expose all fields', () {
    final summary = buildSummary();

    expect(summary.date, DateTime(2026, 9, 16));
    expect(summary.totalMl, 1500);
    expect(summary.dayOfWeekAbbr, 'Qua');
    expect(summary.isToday, isTrue);
  });

  test('should be equal when all props match', () {
    expect(buildSummary(), buildSummary());
  });

  test('should differ when totalMl changes', () {
    expect(buildSummary(), isNot(buildSummary(totalMl: 2000)));
  });

  test('should differ when the day changes', () {
    expect(buildSummary(), isNot(buildSummary(dayOfWeekAbbr: 'Qui')));
  });

  test('should differ when isToday changes', () {
    expect(buildSummary(), isNot(buildSummary(isToday: false)));
  });

  test('props should include all fields', () {
    expect(buildSummary().props, hasLength(4));
  });
}
