import 'package:dio/dio.dart';
import 'package:olimpus/core/network/interceptors/error_interceptor.dart';
import 'package:olimpus/core/network/interceptors/retry_interceptor.dart';

/// Fábrica e cliente HTTP centralizado do Olimpus usando Dio.
abstract final class DioClient {
  /// Cria uma nova instância configurada do [Dio] com timeouts padronizados
  /// e interceptors de retry e tratamento global de erros.
  static Dio create({
    String? baseUrl,
    BaseOptions? customOptions,
    List<Interceptor>? customInterceptors,
    int maxRetries = 2,
    List<Duration>? retryDelays,
  }) {
    final defaultOptions = BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final dio = Dio(customOptions ?? defaultOptions);

    final retry = RetryInterceptor(
      dio: dio,
      maxRetries: maxRetries,
      retryDelays: retryDelays ??
          const [
            Duration(seconds: 1),
            Duration(seconds: 2),
          ],
    );

    dio.interceptors.addAll([
      retry,
      const ErrorInterceptor(),
      ...?customInterceptors,
    ]);

    return dio;
  }
}
