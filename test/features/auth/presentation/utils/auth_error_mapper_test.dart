import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/auth/presentation/utils/auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthErrorMapper', () {
    test('retorna defaultMessage quando erro for nulo', () {
      final msg = AuthErrorMapper.map(null);
      expect(msg, 'Ocorreu um erro. Tente novamente.');
    });

    test('mapeia invalid login credentials corretamente', () {
      const error = AuthException('Invalid login credentials');
      final msg = AuthErrorMapper.map(error);
      expect(msg, 'Email ou senha incorretos.');
    });

    test('mapeia email not confirmed corretamente', () {
      const error = AuthException('Email not confirmed');
      final msg = AuthErrorMapper.map(error);
      expect(msg, 'Seu email ainda não foi confirmado. Verifique sua caixa de entrada.');
    });

    test('mapeia rate limit corretamente', () {
      const error = AuthException('rate limit exceeded');
      final msg = AuthErrorMapper.map(error);
      expect(msg, 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.');
    });

    test('retorna defaultMessage customizada para erro desconhecido', () {
      final msg = AuthErrorMapper.map(
        Exception('Erro interno desconhecido'),
        defaultMessage: 'Falha ao processar.',
      );
      expect(msg, 'Falha ao processar.');
    });
  });
}
