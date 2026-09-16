import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';

void main() {
  testWidgets('AppErrorWidget renderiza mensagem amigável para NetworkException',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorWidget(
            error: NetworkException('Sem conexão com a internet.'),
          ),
        ),
      ),
    );

    expect(find.text('Sem conexão com a internet.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('AppErrorWidget renderiza botão de retry e dispara callback ao tocar',
      (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppErrorWidget(
            error: const SocketException('offline'),
            onRetry: () {
              retried = true;
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('Sem conexão com a internet'), findsOneWidget);

    final retryButton = find.widgetWithText(FilledButton, 'Tentar novamente');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('AppErrorWidget respeita customMessage quando fornecida',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorWidget(
            error: ServerException('Erro interno do servidor.'),
            customMessage: 'Falha ao carregar treinos de hoje.',
          ),
        ),
      ),
    );

    expect(find.text('Falha ao carregar treinos de hoje.'), findsOneWidget);
    expect(find.text('Erro interno do servidor.'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });
}
