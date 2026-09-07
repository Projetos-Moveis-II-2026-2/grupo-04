import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/network/connectivity_service.dart';

/// Singleton do serviço de conectividade.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

/// Estado de rede como `Stream<bool>` → `AsyncValue<bool>`.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnlineStream;
});
