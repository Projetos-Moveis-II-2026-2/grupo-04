import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Configuração de rotas do app (go_router).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => const _HomePage())],
);

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Olimpus')),
      body: const Center(child: Text('Olimpus')),
    );
  }
}
