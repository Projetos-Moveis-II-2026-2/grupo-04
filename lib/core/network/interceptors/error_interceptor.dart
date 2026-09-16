import 'package:dio/dio.dart';
import 'package:olimpus/core/errors/app_exception.dart';

/// Interceptor que intercepta falhas do Dio e anexa o [AppException] correspondente.
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = AppException.from(err);
    final mappedException = err.copyWith(error: appException);
    handler.next(mappedException);
  }
}
