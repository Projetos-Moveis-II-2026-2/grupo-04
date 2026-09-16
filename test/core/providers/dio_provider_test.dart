import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/network/interceptors/error_interceptor.dart';
import 'package:olimpus/core/network/interceptors/retry_interceptor.dart';
import 'package:olimpus/core/providers.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  test('dioClientProvider cria instância com interceptors configurados', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dio = container.read(dioClientProvider);

    expect(dio, isA<Dio>());
    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 15));

    final hasRetry = dio.interceptors.any((i) => i is RetryInterceptor);
    final hasError = dio.interceptors.any((i) => i is ErrorInterceptor);

    expect(hasRetry, isTrue);
    expect(hasError, isTrue);
  });

  test('dioClientProvider pode ser sobrescrito em testes', () {
    final mockDio = _MockDio();
    final container = ProviderContainer(
      overrides: [
        dioClientProvider.overrideWithValue(mockDio),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioClientProvider);

    expect(identical(dio, mockDio), isTrue);
  });
}
