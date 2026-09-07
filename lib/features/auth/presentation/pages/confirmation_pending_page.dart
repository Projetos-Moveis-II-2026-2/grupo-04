import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_notifier.dart';

class ConfirmationPendingPage extends ConsumerStatefulWidget {
  const ConfirmationPendingPage({super.key, required this.email});
  final String email;

  @override
  ConsumerState<ConfirmationPendingPage> createState() =>
      _ConfirmationPendingPageState();
}

class _ConfirmationPendingPageState
    extends ConsumerState<ConfirmationPendingPage> {
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resend() async {
    try {
      await ref.read(authNotifierProvider.notifier).resendConfirmation(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail reenviado com sucesso!')),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao reenviar e-mail.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirme seu e-mail')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_unread, size: 64, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Enviamos um link de confirmação para:\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _cooldown == 0 ? _resend : null,
              child: Text(
                _cooldown == 0
                    ? 'Reenviar e-mail'
                    : 'Aguarde $_cooldown s para reenviar',
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Já confirmei, fazer login'),
            ),
          ],
        ),
      ),
    );
  }
}
