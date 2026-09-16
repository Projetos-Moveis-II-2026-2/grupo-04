import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:olimpus/core/network/interceptors/error_interceptor.dart';

class _MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '/test')),
    );
  });

  test('ErrorInterceptor anexa AppException correspondente ao DioException', () {
    const interceptor = ErrorInterceptor();
    final handler = _MockErrorInterceptorHandler();

    final dioException = DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionTimeout,
    );

    interceptor.onError(dioException, handler);

    final captured = verify(() => handler.next(captureAny())).captured.single
        as DioException;

    expect(captured.error, isA<TimeoutException>());
    expect(
      (captured.error as TimeoutException).message,
      contains('demorou para responder'),
    );
  });
}
