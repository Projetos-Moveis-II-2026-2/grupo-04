import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/network/interceptors/retry_interceptor.dart';

class _MockDio extends Mock implements Dio {}

class _MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  late _MockDio mockDio;
  late _MockErrorInterceptorHandler handler;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/test'));
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '/test')),
    );
    registerFallbackValue(
      Response<dynamic>(requestOptions: RequestOptions(path: '/test')),
    );
  });

  setUp(() {
    mockDio = _MockDio();
    handler = _MockErrorInterceptorHandler();
  });

  test('repete requisição GET que sofreu timeout de conexão', () async {
    final interceptor = RetryInterceptor(
      dio: mockDio,
      maxRetries: 2,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    final requestOptions = RequestOptions(
      path: '/exercises',
      method: 'GET',
    );

    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
    );

    final successResponse = Response<dynamic>(
      requestOptions: requestOptions,
      data: {'status': 'ok'},
      statusCode: 200,
    );

    when(() => mockDio.fetch<dynamic>(any()))
        .thenAnswer((_) async => successResponse);

    await interceptor.onError(dioException, handler);

    verify(() => mockDio.fetch<dynamic>(any())).called(1);
    verify(() => handler.resolve(successResponse)).called(1);
  });

  test('não repete requisição POST sem allow_retry', () async {
    final interceptor = RetryInterceptor(
      dio: mockDio,
      maxRetries: 2,
      retryDelays: const [Duration.zero],
    );

    final requestOptions = RequestOptions(
      path: '/workouts',
      method: 'POST',
    );

    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
    );

    await interceptor.onError(dioException, handler);

    verifyNever(() => mockDio.fetch<dynamic>(any()));
    verify(() => handler.next(dioException)).called(1);
  });

  test('repete requisição POST se allow_retry estiver explicitamente habilitado', () async {
    final interceptor = RetryInterceptor(
      dio: mockDio,
      maxRetries: 2,
      retryDelays: const [Duration.zero],
    );

    final requestOptions = RequestOptions(
      path: '/workouts',
      method: 'POST',
      extra: {'allow_retry': true},
    );

    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
    );

    final successResponse = Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: 201,
    );

    when(() => mockDio.fetch<dynamic>(any()))
        .thenAnswer((_) async => successResponse);

    await interceptor.onError(dioException, handler);

    verify(() => mockDio.fetch<dynamic>(any())).called(1);
    verify(() => handler.resolve(successResponse)).called(1);
  });

  test('para de repetir quando atinge maxRetries', () async {
    final interceptor = RetryInterceptor(
      dio: mockDio,
      maxRetries: 2,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    final requestOptions = RequestOptions(
      path: '/exercises',
      method: 'GET',
      extra: {'retry_count': 2},
    );

    final dioException = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
    );

    await interceptor.onError(dioException, handler);

    verifyNever(() => mockDio.fetch<dynamic>(any()));
    verify(() => handler.next(dioException)).called(1);
  });
}
