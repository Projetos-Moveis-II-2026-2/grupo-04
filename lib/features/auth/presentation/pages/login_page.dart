import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_mapper.dart';
import '../widgets/auth_text_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authNotifierProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (previous, next) {
      if (next is AsyncError) {
        final message = AuthErrorMapper.map(
          next.error,
          defaultMessage: 'Ocorreu um erro ao fazer login. Tente novamente.',
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      } else if (next is AsyncData && next.value != null) {
        ref.read(sessionExpiredNoticeProvider.notifier).dismiss();
      }
    });

    final sessionExpired = ref.watch(sessionExpiredNoticeProvider);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sessionExpired) ...[
                  _SessionExpiredBanner(
                    onDismiss: ref
                        .read(sessionExpiredNoticeProvider.notifier)
                        .dismiss,
                  ),
                  const SizedBox(height: 24),
                ],
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Senha',
                  isPassword: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Esqueci minha senha'),
                ),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso exibido quando o usuário foi deslogado porque a sessão expirou
/// (refresh token expirado ou revogado no servidor).
class _SessionExpiredBanner extends StatelessWidget {
  const _SessionExpiredBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('session-expired-banner'),
      color: scheme.errorContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Icon(Icons.lock_clock, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sua sessão expirou. Entre novamente para continuar.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: scheme.onErrorContainer,
              tooltip: 'Fechar aviso',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
