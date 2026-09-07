import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder para o fluxo de reset de senha.
/// Será substituída pela implementação completa na Issue #12.
class ResetPasswordPlaceholderPage extends StatelessWidget {
  const ResetPasswordPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redefinir Senha')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Funcionalidade em desenvolvimento.\n'
                'O fluxo de redefinição de senha será implementado em breve.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Voltar ao Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
