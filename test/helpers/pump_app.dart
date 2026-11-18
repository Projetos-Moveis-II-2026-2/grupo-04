import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Monta [child] (ou [router]) dentro de um [ProviderScope] com `retry`
/// desabilitado para evitar timers pendentes em testes com erros assíncronos.
Future<void> pumpApp(
  WidgetTester tester, {
  Widget? child,
  GoRouter? router,
  List<Override> overrides = const [],
}) async {
  assert(
    child != null || router != null,
    'Informe child ou router para montar o widget de teste.',
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: router != null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp(home: child),
    ),
  );
}

/// Constrói um [GoRouter] mínimo para verificar fluxos de navegação.
GoRouter buildTestRouter({
  required String initialLocation,
  required List<RouteBase> routes,
}) {
  return GoRouter(initialLocation: initialLocation, routes: routes);
}

/// Extensão anti-flake para garantir que `pumpAndSettle` use timeout curto.
extension WidgetTesterPumpExt on WidgetTester {
  Future<int> pumpAndSettleBounded([
    Duration timeout = const Duration(seconds: 2),
  ]) {
    return pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }
}
