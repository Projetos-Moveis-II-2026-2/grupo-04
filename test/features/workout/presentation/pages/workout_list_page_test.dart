import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/workout/presentation/pages/workout_list_page.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  group('WorkoutListPage Smoke Tests', () {
    testWidgets('renderiza card de treino livre e navega para /workout/free', (
      tester,
    ) async {
      final router = buildTestRouter(
        initialLocation: '/workout',
        routes: [
          GoRoute(
            path: '/workout',
            builder: (_, _) => const WorkoutListPage(),
            routes: [
              GoRoute(
                path: 'free',
                builder: (_, _) => const Scaffold(body: Text('Tela Livre')),
              ),
            ],
          ),
        ],
      );

      await pumpApp(tester, router: router);
      await tester.pump();

      expect(find.text('Meus Treinos'), findsOneWidget);
      expect(find.text('Treino livre'), findsOneWidget);
      expect(
        find.text('Registre séries e cronometre seus descansos'),
        findsOneWidget,
      );

      await tester.tap(find.text('Treino livre'));
      await tester.pumpAndSettleBounded();

      expect(find.text('Tela Livre'), findsOneWidget);
    });
  });
}
