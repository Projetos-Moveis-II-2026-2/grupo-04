import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/presentation/widgets/exercise_motion_image.dart';

void main() {
  const frame0 = 'assets/exercises/flyes_0.jpg';
  const frame1 = 'assets/exercises/flyes_1.jpg';
  const frame2 = 'assets/exercises/flyes_2.jpg';
  const frameDuration = Duration(milliseconds: 700);
  const transitionDuration = Duration(milliseconds: 250);

  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: SizedBox(width: 300, height: 300, child: child)),
      ),
    );
  }

  String? currentAnimatedKey(WidgetTester tester) {
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    final key = switcher.child?.key;
    return key is ValueKey<String> ? key.value : null;
  }

  group('ExerciseMotionImage Widget Tests', () {
    testWidgets('exibe ícone fitness_center padrão quando frames está vazio', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ExerciseMotionImage(frames: [])));

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });

    testWidgets(
      'exibe fallback customizado quando frames contém apenas espaços',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const ExerciseMotionImage(
              frames: ['   ', ''],
              fallback: Icon(Icons.bolt),
            ),
          ),
        );

        expect(find.byIcon(Icons.bolt), findsOneWidget);
        expect(find.byType(AnimatedSwitcher), findsNothing);
      },
    );

    testWidgets('não alterna quando há apenas 1 quadro', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMotionImage(
            frames: [frame0],
            frameDuration: frameDuration,
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsNothing);

      await tester.pump(frameDuration * 3);

      expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
    });

    testWidgets(
      'alterna quadros 0 → 1 → 0 → 1 ao longo do tempo com 2 quadros',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const ExerciseMotionImage(
              frames: [frame0, frame1],
              frameDuration: frameDuration,
              transitionDuration: transitionDuration,
            ),
          ),
        );

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
        expect(currentAnimatedKey(tester), frame0);

        // Após 1º intervalo (700 ms): vai para o quadro 1
        await tester.pump(frameDuration);
        expect(currentAnimatedKey(tester), frame1);
        // Avança o cross-fade (250 ms) até concluir a transição para o quadro 1
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byKey(const ValueKey<String>(frame1)), findsOneWidget);
        expect(find.byKey(const ValueKey<String>(frame0)), findsNothing);

        // Completa o 2º intervalo (restam 400 ms dos 700 ms): volta para o quadro 0
        await tester.pump(const Duration(milliseconds: 400));
        expect(currentAnimatedKey(tester), frame0);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
        expect(find.byKey(const ValueKey<String>(frame1)), findsNothing);

        // Completa o 3º intervalo (restam 400 ms dos 700 ms): avança para o quadro 1
        await tester.pump(const Duration(milliseconds: 400));
        expect(currentAnimatedKey(tester), frame1);
      },
    );

    testWidgets('faz loop ping-pong (0 → 1 → 2 → 1 → 0) com 3 quadros', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMotionImage(
            frames: [frame0, frame1, frame2],
            frameDuration: frameDuration,
          ),
        ),
      );

      expect(currentAnimatedKey(tester), frame0);

      await tester.pump(frameDuration);
      expect(currentAnimatedKey(tester), frame1);

      await tester.pump(frameDuration);
      expect(currentAnimatedKey(tester), frame2);

      await tester.pump(frameDuration);
      expect(currentAnimatedKey(tester), frame1);

      await tester.pump(frameDuration);
      expect(currentAnimatedKey(tester), frame0);
    });

    testWidgets('não anima quando animate é false (ex.: card da lista)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMotionImage(
            frames: [frame0, frame1],
            animate: false,
            frameDuration: frameDuration,
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
      expect(find.byKey(const ValueKey<String>(frame1)), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsNothing);

      await tester.pump(frameDuration * 3);

      expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
      expect(find.byKey(const ValueKey<String>(frame1)), findsNothing);
    });

    testWidgets(
      'respeita MediaQuery.disableAnimations e para de animar mostrando o 1º quadro',
      (tester) async {
        // Inicia com animações desativadas
        await tester.pumpWidget(
          wrap(
            const ExerciseMotionImage(
              frames: [frame0, frame1],
              frameDuration: frameDuration,
            ),
            disableAnimations: true,
          ),
        );

        expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
        expect(find.byType(AnimatedSwitcher), findsNothing);

        await tester.pump(frameDuration * 2);
        expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
        expect(find.byKey(const ValueKey<String>(frame1)), findsNothing);

        // Ativa animações dinamicamente e avança para o 2º quadro
        await tester.pumpWidget(
          wrap(
            const ExerciseMotionImage(
              frames: [frame0, frame1],
              frameDuration: frameDuration,
            ),
            disableAnimations: false,
          ),
        );
        await tester.pump(frameDuration);
        expect(currentAnimatedKey(tester), frame1);

        // Desativa animações novamente: deve cancelar o timer e voltar ao 1º quadro
        await tester.pumpWidget(
          wrap(
            const ExerciseMotionImage(
              frames: [frame0, frame1],
              frameDuration: frameDuration,
            ),
            disableAnimations: true,
          ),
        );
        expect(find.byKey(const ValueKey<String>(frame0)), findsOneWidget);
        expect(find.byType(AnimatedSwitcher), findsNothing);
      },
    );

    testWidgets(
      'cancela o Timer no dispose ao sair da tela sem timer pendente',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const ExerciseMotionImage(
              frames: [frame0, frame1],
              frameDuration: frameDuration,
            ),
          ),
        );

        await tester.pump(frameDuration);
        expect(currentAnimatedKey(tester), frame1);

        // Desmonta o widget simulando saída da tela
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(frameDuration * 5);

        expect(find.byType(ExerciseMotionImage), findsNothing);
      },
    );

    testWidgets('renderiza CachedNetworkImage para URLs de rede', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMotionImage(
            frames: ['https://example.com/0.jpg', 'https://example.com/1.jpg'],
            animate: false,
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });
  });
}
