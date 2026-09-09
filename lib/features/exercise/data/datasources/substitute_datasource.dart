import 'package:supabase_flutter/supabase_flutter.dart';

/// Linha de substituição — vem da RPC `find_substitutes` (camada 1)
/// ou do fallback LLM `suggest-substitute` (camada 2).
class SubstituteSuggestion {
  const SubstituteSuggestion({
    required this.id,
    required this.name,
    required this.equipment,
    required this.imageUrl,
    this.reason,
  });

  factory SubstituteSuggestion.fromRpcRow(Map<String, dynamic> row) {
    return SubstituteSuggestion(
      id: row['id'] as String,
      name: row['name'] as String,
      equipment: row['equipment'] as String?,
      imageUrl: row['image_url'] as String?,
    );
  }

  factory SubstituteSuggestion.fromLlmJson(Map<String, dynamic> json) {
    return SubstituteSuggestion(
      // fallback LLM sem match no catálogo: sem id selecionável
      id: json['matched_id'] as String? ?? '',
      name: json['matched_name'] as String? ?? json['name'] as String,
      equipment: json['equipment'] as String?,
      imageUrl: json['image_url'] as String?,
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final String name;
  final String? equipment;
  final String? imageUrl;
  final String? reason;
}

class SubstituteRateLimited implements Exception {
  SubstituteRateLimited(this.nextAvailableAt);

  final DateTime? nextAvailableAt;

  @override
  String toString() => 'Assistente disponível a partir de $nextAvailableAt';
}

/// Camada 1: RPC `find_substitutes` (mesmos músculos, equipamento
/// diferente). Camada 2 (apenas se a 1ª vier vazia): Edge Function
/// `suggest-substitute` via LLM, com rate limit compartilhado.
class SubstituteDatasource {
  SubstituteDatasource(this._client);

  final SupabaseClient _client;

  Future<List<SubstituteSuggestion>> getSubstitutes(String exerciseId) async {
    final rows = await _client.rpc(
      'find_substitutes',
      params: {'p_exercise_id': exerciseId, 'p_limit': 10},
    );

    final structured = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SubstituteSuggestion.fromRpcRow)
        .toList();
    if (structured.isNotEmpty) return structured;

    return _fallbackFromLLM(exerciseId);
  }

  Future<List<SubstituteSuggestion>> _fallbackFromLLM(String exerciseId) async {
    try {
      final res = await _client.functions.invoke(
        'suggest-substitute',
        body: {'exercise_id': exerciseId},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      return ((data['substitutes'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(SubstituteSuggestion.fromLlmJson)
          .toList();
    } on FunctionException catch (e) {
      if (e.status == 429) {
        final payload = e.details;
        final nextAt = payload is Map && payload['next_available_at'] != null
            ? DateTime.tryParse(payload['next_available_at'] as String)
            : null;
        throw SubstituteRateLimited(nextAt);
      }
      rethrow;
    }
  }
}
