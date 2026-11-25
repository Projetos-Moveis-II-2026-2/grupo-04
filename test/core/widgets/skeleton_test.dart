import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/widgets/skeleton.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  group('Skeleton Widget', () {
    testWidgets('renderiza com dimensões e cantos arredondados definidos', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Skeleton(
              width: 120,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxWidth, 120);
      expect(container.constraints?.maxHeight, 40);

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.shape, BoxShape.rectangle);
    });

    testWidgets('Skeleton.circle renderiza com formato circular', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Skeleton.circle(size: 64))),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, 64);
      expect(container.constraints?.maxHeight, 64);

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.borderRadius, isNull);
    });

    testWidgets('deriva cores do colorScheme no tema claro e escuro', (
      tester,
    ) async {
      const lightTheme = ColorScheme.light(
        surfaceContainerHigh: Color(0xFFECE6F0),
      );
      const darkTheme = ColorScheme.dark(
        surfaceContainerHighest: Color(0xFF36343B),
      );

      // Tema Claro
      await tester.pumpWidget(
        Theme(
          data: ThemeData(colorScheme: lightTheme),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Skeleton(width: 50, height: 20),
          ),
        ),
      );

      var container = tester.widget<Container>(find.byType(Container));
      var decoration = container.decoration as BoxDecoration;
      expect(decoration.color, lightTheme.surfaceContainerHigh);

      // Tema Escuro
      await tester.pumpWidget(
        Theme(
          data: ThemeData(colorScheme: darkTheme),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Skeleton(width: 50, height: 20),
          ),
        ),
      );

      container = tester.widget<Container>(find.byType(Container));
      decoration = container.decoration as BoxDecoration;
      expect(decoration.color, darkTheme.surfaceContainerHighest);
    });

    testWidgets('possui rótulo semântico "Carregando"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Skeleton(width: 80, height: 20)),
        ),
      );

      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
    });
  });

  group('SkeletonWrapper Widget', () {
    testWidgets('aplica Shimmer quando animações estão ativas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonWrapper(child: Skeleton(width: 100, height: 30)),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets(
      'não aplica Shimmer quando MediaQuery.disableAnimationsOf é true (estático)',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: SkeletonWrapper(child: Skeleton(width: 100, height: 30)),
              ),
            ),
          ),
        );

        expect(find.byType(Shimmer), findsNothing);
        expect(find.byType(Skeleton), findsOneWidget);
      },
    );

    testWidgets('não aplica Shimmer quando enabled é false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonWrapper(
              enabled: false,
              child: Skeleton(width: 100, height: 30),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsNothing);
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('SkeletonWrapper possui rótulo semântico "Carregando"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonWrapper(child: SizedBox(width: 50, height: 20)),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
      handle.dispose();
    });
  });
}
