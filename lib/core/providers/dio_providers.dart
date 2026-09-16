import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/network/dio_client.dart';

/// Provider do cliente HTTP central [Dio] com timeouts e interceptors globais.
final dioClientProvider = Provider<Dio>((ref) {
  return DioClient.create();
});
