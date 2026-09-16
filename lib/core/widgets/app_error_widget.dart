import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:olimpus/core/errors/app_exception.dart';

/// Widget padrão reutilizável para exibição de erros e opção de retry.
///
/// Ideal para uso em conjunto com [AsyncValue.when] do Riverpod.
class AppErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? customMessage;
  final String retryButtonText;

  const AppErrorWidget({
    required this.error,
    super.key,
    this.stackTrace,
    this.onRetry,
    this.customMessage,
    this.retryButtonText = 'Tentar novamente',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appException = AppException.from(error, stackTrace);
    final displayMessage = customMessage ?? appException.message;
    final iconData = _getIconForException(appException);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: 48,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (kDebugMode && appException.originalError != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: Text(
                  'Detalhes técnicos (debug)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      'Erro: ${appException.originalError}\n\n'
                      'Stack: ${stackTrace ?? ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryButtonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _getIconForException(AppException exception) {
    return switch (exception) {
      NetworkException() => Icons.wifi_off_rounded,
      TimeoutException() => Icons.timer_off_outlined,
      UnauthorizedException() => Icons.lock_outline_rounded,
      NotFoundException() => Icons.search_off_rounded,
      ServerException() => Icons.cloud_off_rounded,
      _ => Icons.error_outline_rounded,
    };
  }
}
