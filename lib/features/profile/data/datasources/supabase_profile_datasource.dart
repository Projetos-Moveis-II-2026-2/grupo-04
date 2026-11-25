import 'package:supabase_flutter/supabase_flutter.dart';

/// Datasource remoto para operações na tabela `profiles` do Supabase.
class SupabaseProfileDatasource {
  final SupabaseClient _client;

  const SupabaseProfileDatasource(this._client);

  /// Busca os dados do perfil pelo ID do usuário.
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  /// Atualiza ou insere (upsert) os dados do perfil do usuário.
  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> profileData,
  ) async {
    final data = {'id': userId, ...profileData};
    await _client.from('profiles').upsert(data);
  }
}
