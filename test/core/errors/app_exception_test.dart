import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppException.from - DioException mapping', () {
    test('mapeia connectionTimeout para TimeoutException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<TimeoutException>());
      expect(exception.message, contains('demorou para responder'));
    });

    test('mapeia connectionError para NetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<NetworkException>());
      expect(exception.message, contains('Falha na conexão'));
    });

    test('mapeia badResponse 401 para UnauthorizedException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<UnauthorizedException>());
      expect(exception.message, contains('Acesso não autorizado'));
      expect(exception.code, '401');
    });

    test('mapeia badResponse 404 para NotFoundException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<NotFoundException>());
      expect(exception.message, contains('não encontrado'));
    });

    test('mapeia badResponse 429 para RateLimitException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
        ),
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<RateLimitException>());
      expect(exception.message, contains('Muitas requisições'));
    });

    test('mapeia badResponse 500 para ServerException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<ServerException>());
      expect(exception.message, contains('Instabilidade no servidor'));
    });

    test('extrai mensagem customizada do servidor em badResponse se disponível', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'message': 'Parâmetro de treino inválido.'},
        ),
      );

      final exception = AppException.from(dioException);

      expect(exception, isA<ClientException>());
      expect(exception.message, 'Parâmetro de treino inválido.');
    });
  });

  group('AppException.from - AuthException (Supabase)', () {
    test('mapeia credenciais inválidas para UnauthorizedException', () {
      const authException = AuthException('Invalid login credentials');
      final exception = AppException.from(authException);

      expect(exception, isA<UnauthorizedException>());
      expect(exception.message, 'Email ou senha incorretos.');
    });

    test('mapeia usuário já cadastrado para ClientException', () {
      const authException = AuthException('User already registered');
      final exception = AppException.from(authException);

      expect(exception, isA<ClientException>());
      expect(exception.message, contains('já está cadastrado'));
    });

    test('mapeia rate limit para RateLimitException', () {
      const authException = AuthException('rate limit exceeded');
      final exception = AppException.from(authException);

      expect(exception, isA<RateLimitException>());
      expect(exception.message, contains('Muitas tentativas em pouco tempo'));
    });
  });

  group('AppException.from - PostgrestException (Supabase)', () {
    test('mapeia código 23505 para ClientException de duplicidade', () {
      const postgrestException = PostgrestException(
        message: 'duplicate key value',
        code: '23505',
      );
      final exception = AppException.from(postgrestException);

      expect(exception, isA<ClientException>());
      expect(exception.message, contains('já existente'));
    });

    test('mapeia código PGRST116 para NotFoundException', () {
      const postgrestException = PostgrestException(
        message: 'JSON object requested, multiple (or no) rows returned',
        code: 'PGRST116',
      );
      final exception = AppException.from(postgrestException);

      expect(exception, isA<NotFoundException>());
      expect(exception.message, 'Registro não encontrado.');
    });
  });

  group('AppException.from - Outros erros', () {
    test('mapeia SocketException para NetworkException', () {
      const socketException = SocketException('Failed host lookup');
      final exception = AppException.from(socketException);

      expect(exception, isA<NetworkException>());
      expect(exception.message, contains('Sem conexão com a internet'));
    });

    test('retorna a própria instância se já for AppException', () {
      const original = NetworkException('Erro específico de rede');
      final result = AppException.from(original);

      expect(identical(result, original), isTrue);
    });

    test('faz fallback para GenericException em erro desconhecido', () {
      final exception = AppException.from(Exception('Erro qualquer'));

      expect(exception, isA<GenericException>());
      expect(exception.message, contains('Ocorreu um erro inesperado'));
    });
  });
}
