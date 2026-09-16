import 'dart:io';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Classe base abstrata para todas as exceções de domínio do Olimpus.
abstract base class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;

  /// Converte qualquer erro/exceção externa em uma [AppException] padronizada
  /// com mensagem amigável em português (pt-BR).
  factory AppException.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return _mapDioException(error);
    }

    if (error is AuthException) {
      return _mapAuthException(error);
    }

    if (error is PostgrestException) {
      return _mapPostgrestException(error);
    }

    if (error is SocketException) {
      return NetworkException(
        'Sem conexão com a internet. Verifique sua rede e tente novamente.',
        originalError: error,
      );
    }

    return GenericException(
      'Ocorreu um erro inesperado. Tente novamente.',
      originalError: error,
    );
  }

  static AppException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutException(
          'O servidor demorou para responder. Tente novamente em instantes.',
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          'Falha na conexão com o servidor. Verifique sua internet.',
          originalError: error,
        );

      case DioExceptionType.badCertificate:
        return NetworkException(
          'Falha de segurança na conexão (certificado inválido).',
          originalError: error,
        );

      case DioExceptionType.cancel:
        return ClientException(
          'A requisição foi cancelada.',
          originalError: error,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String? serverMsg;
        if (responseData is Map && responseData['message'] is String) {
          serverMsg = responseData['message'] as String;
        }

        if (statusCode == 401 || statusCode == 403) {
          return UnauthorizedException(
            serverMsg ?? 'Acesso não autorizado. Faça login novamente.',
            code: statusCode?.toString(),
            originalError: error,
          );
        }

        if (statusCode == 404) {
          return NotFoundException(
            serverMsg ?? 'Recurso não encontrado.',
            code: statusCode?.toString(),
            originalError: error,
          );
        }

        if (statusCode == 429) {
          return RateLimitException(
            serverMsg ?? 'Muitas requisições. Aguarde alguns instantes.',
            code: statusCode?.toString(),
            originalError: error,
          );
        }

        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            serverMsg ?? 'Instabilidade no servidor. Tente novamente mais tarde.',
            code: statusCode.toString(),
            originalError: error,
          );
        }

        return ClientException(
          serverMsg ?? 'Não foi possível completar a requisição.',
          code: statusCode?.toString(),
          originalError: error,
        );

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return NetworkException(
            'Sem conexão com a internet. Verifique sua rede e tente novamente.',
            originalError: error,
          );
        }
        return GenericException(
          'Falha de comunicação com o servidor.',
          originalError: error,
        );
    }
  }

  static AppException _mapAuthException(AuthException error) {
    final msg = error.message.toLowerCase();

    if (msg.contains('invalid login credentials')) {
      return UnauthorizedException(
        'Email ou senha incorretos.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('user already registered')) {
      return ClientException(
        'Este email já está cadastrado. Faça login ou use outro email.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('email not confirmed')) {
      return UnauthorizedException(
        'Seu email ainda não foi confirmado. Verifique sua caixa de entrada.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('password should be at least')) {
      return ClientException(
        'A senha deve conter no mínimo 6 caracteres.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('rate limit')) {
      return RateLimitException(
        'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('invalid email')) {
      return ClientException(
        'O formato do email é inválido.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('same_password') ||
        msg.contains('new password should be different')) {
      return ClientException(
        'A nova senha deve ser diferente da senha atual.',
        code: error.statusCode,
        originalError: error,
      );
    }
    if (msg.contains('failed to delete account') ||
        msg.contains('delete-account')) {
      return ClientException(
        'Não foi possível excluir a conta. Tente novamente mais tarde.',
        code: error.statusCode,
        originalError: error,
      );
    }

    return ClientException(
      error.message,
      code: error.statusCode,
      originalError: error,
    );
  }

  static AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '23505') {
      return ClientException(
        'Registro já existente no sistema.',
        code: error.code,
        originalError: error,
      );
    }
    if (error.code == 'PGRST116') {
      return NotFoundException(
        'Registro não encontrado.',
        code: error.code,
        originalError: error,
      );
    }

    return ServerException(
      'Erro ao consultar banco de dados. Tente novamente mais tarde.',
      code: error.code,
      originalError: error,
    );
  }
}

/// Erro relacionado à conectividade de rede, DNS ou conexão recusada.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});
}

/// Erro de timeout em requisições de rede (conexão, envio ou recebimento).
final class TimeoutException extends AppException {
  const TimeoutException(super.message, {super.code, super.originalError});
}

/// Erro interno ou indisponibilidade no servidor (status 5xx).
final class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.originalError});
}

/// Erro de permissão ou autenticação (status 401 ou 403).
final class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.code, super.originalError});
}

/// Recurso solicitado não foi encontrado (status 404).
final class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.originalError});
}

/// Erro do cliente ou validação inválida (status 400 ou regras de negócio).
final class ClientException extends AppException {
  const ClientException(super.message, {super.code, super.originalError});
}

/// Erro de limite de requisições excedido (status 429).
final class RateLimitException extends AppException {
  const RateLimitException(super.message, {super.code, super.originalError});
}

/// Erro genérico ou inesperado no aplicativo.
final class GenericException extends AppException {
  const GenericException(super.message, {super.code, super.originalError});
}
