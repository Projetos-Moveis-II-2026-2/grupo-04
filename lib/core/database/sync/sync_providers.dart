import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/providers/database_providers.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';
import 'package:olimpus/core/network/connectivity_service.dart';

/// Estado de conectividade como provider (`Stream<bool>` → `AsyncValue<bool>`).
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isOnlineStream;
});

final syncRemoteGatewayProvider = Provider<SyncRemoteGateway>((ref) {
  return SupabaseSyncGateway();
});

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final service = SyncQueueService(
    ref.watch(appDatabaseProvider),
    gateway: ref.watch(syncRemoteGatewayProvider),
  );
  ref.onDispose(() {
    service.onGiveUp = null;
  });
  return service;
});

/// Drena a fila automaticamente quando a conexão volta (e no boot se online).
final syncQueueAutoProcessorProvider = Provider<void>((ref) {
  final service = ref.watch(syncQueueServiceProvider);

  void drainIfOnline(bool? online) {
    if (online ?? false) {
      unawaited(_safeDrain(service));
    }
  }

  ref.listen(isOnlineProvider, (_, next) => drainIfOnline(next.value));
  drainIfOnline(ref.read(isOnlineProvider).value);
});

/// Garante que o auto-processor existe enquanto o app está vivo.
final appLifecycleSyncBindingProvider = Provider<void>((ref) {
  ref.watch(syncQueueAutoProcessorProvider);
});

Future<void> _safeDrain(SyncQueueService service) async {
  try {
    await service.processQueue();
  } on Object {
    // Falha programática não deve derrubar o app; o próximo ciclo tenta de novo.
  }
}
