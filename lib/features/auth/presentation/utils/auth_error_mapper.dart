import 'package:supabase_flutter/supabase_flutter.dart';

/// Utilitário para mapear erros do Supabase Auth para mensagens em português amigáveis.
abstract final class AuthErrorMapper {
  static String map(Object? error, {String defaultMessage = 'Ocorreu um erro. Tente novamente.'}) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();

      if (msg.contains('invalid login credentials')) {
        return 'Email ou senha incorretos.';
      }
      if (msg.contains('user already registered')) {
        return 'Este email já está cadastrado. Faça login ou use outro email.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Seu email ainda não foi confirmado. Verifique sua caixa de entrada.';
      }
      if (msg.contains('password should be at least')) {
        return 'A senha deve conter no mínimo 6 caracteres.';
      }
      if (msg.contains('rate limit')) {
        return 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.';
      }
      if (msg.contains('invalid email')) {
        return 'O formato do email é inválido.';
      }
      if (msg.contains('same_password') || msg.contains('new password should be different')) {
        return 'A nova senha deve ser diferente da senha atual.';
      }

      return error.message;
    }

    return defaultMessage;
  }
}
