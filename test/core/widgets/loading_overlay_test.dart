import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/widgets/loading_overlay.dart';

void main() {
  group('LoadingOverlay Widget', () {
    testWidgets(
      'quando isLoading é false, exibe apenas child e permite toques',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LoadingOverlay(
                isLoading: false,
                child: ElevatedButton(
                  onPressed: () => tapped = true,
                  child: const Text('Confirmar'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Confirmar'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text('Confirmar'));
        await tester.pump();

        expect(tapped, isTrue);

        final popScope = tester.widget<PopScope>(find.byType(PopScope));
        expect(popScope.canPop, isTrue);
      },
    );

    testWidgets(
      'quando isLoading é true, exibe progresso, mensagem e bloqueia toques e pop',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LoadingOverlay(
                isLoading: true,
                message: 'Excluindo conta...',
                child: ElevatedButton(
                  onPressed: () => tapped = true,
                  child: const Text('Confirmar'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Confirmar'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Excluindo conta...'), findsOneWidget);

        final popScope = tester.widget<PopScope>(find.byType(PopScope));
        expect(popScope.canPop, isFalse);

        // Tenta tocar no botão que está embaixo do overlay bloqueante
        await tester.tap(find.text('Confirmar'), warnIfMissed: false);
        await tester.pump();

        expect(tapped, isFalse);
      },
    );

    testWidgets('funciona sem mensagem opcional', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingOverlay(isLoading: true, child: Text('Base')),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Base'), findsOneWidget);
    });
  });
}
