import 'dart:async';

import 'package:dio/dio.dart';

/// Interceptor que repete automaticamente requisições idempotentes que falharam
/// por problemas transitórios de rede/timeout ou status 503 (Service Unavailable).
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final retryCount = (requestOptions.extra['retry_count'] as int?) ?? 0;

    if (_shouldRetry(err, requestOptions, retryCount)) {
      final nextRetryCount = retryCount + 1;
      requestOptions.extra['retry_count'] = nextRetryCount;

      final delayIndex =
          (nextRetryCount - 1).clamp(0, retryDelays.length - 1);
      final delay = retryDelays[delayIndex];

      await Future<void>.delayed(delay);

      try {
        final response = await dio.fetch<dynamic>(requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      } catch (e) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(
    DioException err,
    RequestOptions requestOptions,
    int retryCount,
  ) {
    if (retryCount >= maxRetries) {
      return false;
    }

    final isIdempotentMethod = const ['GET', 'HEAD', 'OPTIONS']
        .contains(requestOptions.method.toUpperCase());
    final explicitAllowRetry = requestOptions.extra['allow_retry'] == true;

    // Apenas repete se for método idempotente ou se tiver sido explicitamente autorizado
    if (!isIdempotentMethod && !explicitAllowRetry) {
      return false;
    }

    // Apenas erros transitórios de rede/timeout ou status 503
    final isNetworkOrTimeout = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;

    final is503 = err.response?.statusCode == 503;

    return isNetworkOrTimeout || is503;
  }
}
