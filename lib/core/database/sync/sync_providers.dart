import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/database/providers/database_providers.dart';
import 'package:olimpus/core/database/sync/initial_sync_service.dart';
import 'package:olimpus/core/database/sync/sync_queue_service.dart';
import 'package:olimpus/core/database/sync/sync_remote_gateway.dart';
import 'package:olimpus/core/network/connectivity_service.dart';
import 'package:olimpus/features/workout/data/datasources/supabase_workout_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// ── Pull inicial (#25) ──────────────────────────────────────────

final cloudPullDataSourceProvider = Provider<CloudPullDataSource>((ref) {
  return SupabaseCloudPullDataSource();
});

final initialSyncServiceProvider = FutureProvider<InitialSyncService>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return InitialSyncService(
    ref.watch(appDatabaseProvider),
    dataSource: ref.watch(cloudPullDataSourceProvider),
    stateStore: SharedPreferencesInitialPullStateStore(prefs),
  );
});

/// Executa o pull inicial quando existe sessão autenticada (restaurada
/// no boot) e a cada evento `signedIn`. O provider de auth (#37) também
/// pode disparar [initialSyncServiceProvider] diretamente.
final authSyncBindingProvider = Provider<void>((ref) {
  final client = Supabase.instance.client;

  Future<void> pullFor(Session? session) async {
    if (session?.user.id == null) return;
    final service = await ref.read(initialSyncServiceProvider.future);
    try {
      await service.pullInitial();
    } on Object {
      // Falha de pull é re-tentada no próximo evento de auth; não derruba o app.
    }
  }

  unawaited(pullFor(client.auth.currentSession));
  client.auth.onAuthStateChange.listen((event) {
    final e = event.event;
    if (e == AuthChangeEvent.signedIn || e == AuthChangeEvent.initialSession) {
      unawaited(pullFor(event.session));
    }
  });
});

Future<void> _safeDrain(SyncQueueService service) async {
  try {
    await service.processQueue();
  } on Object {
    // Falha programática não deve derrubar o app; o próximo ciclo tenta de novo.
  }
}

/// SharedPreferences implementa a bandeira `hasPulledInitial`.
class SharedPreferencesInitialPullStateStore implements InitialPullStateStore {
  SharedPreferencesInitialPullStateStore(
    this._prefs, {
    this.key = 'hasPulledInitial',
  });

  final SharedPreferences _prefs;
  final String key;

  @override
  Future<bool> hasPulled() async => _prefs.getBool(key) ?? false;

  @override
  Future<void> markPulled() => _prefs.setBool(key, true);
}
