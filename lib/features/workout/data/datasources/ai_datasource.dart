import 'package:supabase_flutter/supabase_flutter.dart';

/// Sugestão de carga devolvida pela Edge Function `suggest-load`.
class LoadSuggestion {
  const LoadSuggestion({
    required this.suggestIncrease,
    required this.recommendation,
    required this.nextWeightKg,
    required this.nextReps,
  });

  factory LoadSuggestion.fromJson(Map<String, dynamic> json) {
    return LoadSuggestion(
      suggestIncrease: json['suggest_increase'] as bool? ?? false,
      recommendation: json['recommendation'] as String? ?? '',
      nextWeightKg: (json['next_weight_kg'] as num?)?.toDouble(),
      nextReps: json['next_reps'] as int?,
    );
  }

  final bool suggestIncrease;
  final String recommendation;
  final double? nextWeightKg;
  final int? nextReps;
}

/// Exceção de rate limit (1 chamada por exercício a cada 7 dias).
class SuggestionRateLimited implements Exception {
  SuggestionRateLimited(this.nextAvailableAt);

  final DateTime? nextAvailableAt;

  @override
  String toString() => 'Sugestão disponível a partir de $nextAvailableAt';
}

/// Invoca a Edge Function `suggest-load` (JWT do usuário anexado
/// automaticamente pela sessão atual).
class AiDatasource {
  AiDatasource(this._client);

  final SupabaseClient _client;

  Future<LoadSuggestion> getSuggestion(String exerciseId) async {
    try {
      final res = await _client.functions.invoke(
        'suggest-load',
        body: {'exercise_id': exerciseId},
      );
      return LoadSuggestion.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on FunctionException catch (e) {
      if (e.status == 429) {
        final payload = e.details;
        final nextAt = payload is Map && payload['next_available_at'] != null
            ? DateTime.tryParse(payload['next_available_at'] as String)
            : null;
        throw SuggestionRateLimited(nextAt);
      }
      rethrow;
    }
  }
}
