import 'package:supabase_flutter/supabase_flutter.dart';

/// Porta mínima usada pelo SyncQueueService para falar com o Supabase.
/// Permite mock limpo nos testes (sem depender de Supabase.initialize).
abstract interface class SyncRemoteGateway {
  /// Faz upsert do payload em [table], conflitando por `id`.
  Future<void> upsert(String table, Map<String, dynamic> payload);

  /// Deleta o registro `id` em [table].
  Future<void> delete(String table, String id);

  /// Marca o registro local [localId] de [table] como sincronizado.
  Future<void> markSynced(String table, String localId);
}

/// Implementação real sobre o client do supabase_flutter.
class SupabaseSyncGateway implements SyncRemoteGateway {
  SupabaseSyncGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsert(String table, Map<String, dynamic> payload) =>
      _client.from(table).upsert(payload, onConflict: 'id');

  @override
  Future<void> delete(String table, String id) =>
      _client.from(table).delete().eq('id', id);

  @override
  Future<void> markSynced(String table, String localId) async {
    // Marcação é sempre local; nada a fazer no remoto.
  }
}
