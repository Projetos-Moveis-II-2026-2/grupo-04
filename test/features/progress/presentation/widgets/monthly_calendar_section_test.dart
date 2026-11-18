import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:olimpus/features/progress/domain/entities/monthly_workout_summary.dart';
import 'package:olimpus/features/progress/presentation/providers/progress_providers.dart';
import 'package:olimpus/features/progress/presentation/widgets/monthly_calendar_section.dart';

String _monthLabel(DateTime month) {
  final formatted = DateFormat('MMMM yyyy', 'pt_BR').format(month);
  return '${formatted[0].toUpperCase()}${formatted.substring(1)}';
}

MonthlyWorkoutSummary _summary({
  required DateTime month,
  Set<DateTime> trainedDays = const {},
  int workoutCount = 0,
  double totalVolumeKg = 0,
}) {
  return MonthlyWorkoutSummary(
    month: month,
    trainedDays: trainedDays,
    workoutCount: workoutCount,
    totalVolumeKg: totalVolumeKg,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  Future<void> pumpPage(
    WidgetTester tester,
    MonthlyWorkoutSummary summary,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyWorkoutSummaryProvider.overrideWith(
            (ref) => Stream.value(summary),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MonthlyCalendarSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  testWidgets('marca os dias com treino e exibe o resumo do mês', (
    tester,
  ) async {
    final day5 = DateTime(currentMonth.year, currentMonth.month, 5);
    final day12 = DateTime(currentMonth.year, currentMonth.month, 12);

    await pumpPage(
      tester,
      _summary(
        month: currentMonth,
        trainedDays: {day5, day12},
        workoutCount: 2,
        totalVolumeKg: 2100.5,
      ),
    );

    expect(find.text(_monthLabel(currentMonth)), findsOneWidget);
    expect(find.text('2 treinos'), findsOneWidget);
    expect(find.text('2.100,5 kg de volume'), findsOneWidget);
    expect(find.byKey(const ValueKey('trained-day-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('trained-day-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('regular-day-6')), findsOneWidget);
    expect(find.text('Nenhum treino concluído neste mês'), findsNothing);
  });

  testWidgets('navega entre meses e não avança além do mês atual', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _summary(
        month: currentMonth,
        trainedDays: {currentMonth},
        workoutCount: 1,
        totalVolumeKg: 1000,
      ),
    );

    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

    expect(find.text(_monthLabel(currentMonth)), findsOneWidget);
    expect(find.text(_monthLabel(nextMonth)), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-previous-month')));
    await tester.pumpAndSettle();

    expect(find.text(_monthLabel(previousMonth)), findsOneWidget);
    expect(find.text(_monthLabel(currentMonth)), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-next-month')));
    await tester.pumpAndSettle();

    expect(find.text(_monthLabel(currentMonth)), findsOneWidget);

    final nextButton = tester.widget<IconButton>(
      find.byKey(const Key('calendar-next-month')),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('exibe estado vazio quando não há treinos no mês', (
    tester,
  ) async {
    await pumpPage(tester, _summary(month: currentMonth));

    expect(find.text('Nenhum treino concluído neste mês'), findsOneWidget);
    expect(find.text('0 treinos'), findsOneWidget);
    expect(find.text('0 kg de volume'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('trained-day-'),
      ),
      findsNothing,
    );
  });
}
