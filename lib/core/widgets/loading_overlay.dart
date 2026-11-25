import 'package:flutter/material.dart';

/// Overlay de tela para ações assíncronas (como exclusão de conta e escritas críticas).
///
/// Bloqueia toques e navegação de retorno (botão voltar) enquanto [isLoading] for `true`,
/// exibindo um indicador de progresso e mensagem descritiva opcional sobre um card.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !isLoading,
      child: Stack(
        children: [
          child,
          if (isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: colorScheme.scrim.withValues(alpha: 0.5),
                  child: Center(
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                            if (message != null && message!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
