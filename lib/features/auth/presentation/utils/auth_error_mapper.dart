import 'package:olimpus/core/errors/app_exception.dart';

/// Utilitário para mapear erros do Supabase Auth para mensagens em português amigáveis.
///
/// Delega para [AppException.from] garantindo coerência com o tratamento global de erros.
abstract final class AuthErrorMapper {
  static String map(
    Object? error, {
    String defaultMessage = 'Ocorreu um erro. Tente novamente.',
  }) {
    if (error == null) {
      return defaultMessage;
    }

    final exception = AppException.from(error);
    if (exception is GenericException) {
      return defaultMessage;
    }

    return exception.message;
  }
}
