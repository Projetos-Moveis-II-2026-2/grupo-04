import 'package:flutter/material.dart';
import 'package:olimpus/core/errors/app_exception.dart';

/// Extensão de conveniência em [BuildContext] para feedback visual consistente.
extension UiFeedbackExtension on BuildContext {
  /// Exibe uma SnackBar de erro com mensagem amigável e ação opcional de retry.
  void showErrorSnackBar(
    Object error, {
    VoidCallback? onRetry,
    String? customMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    final appException = AppException.from(error);
    final message = customMessage ?? appException.message;
    final colorScheme = Theme.of(this).colorScheme;

    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        backgroundColor: colorScheme.errorContainer,
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Tentar de novo',
                textColor: colorScheme.error,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Exibe uma SnackBar de sucesso padronizada.
  void showSuccessSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = Theme.of(this).colorScheme;

    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        backgroundColor: colorScheme.primaryContainer,
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
        duration: duration,
      ),
    );
  }
}
