import 'package:olimpus/core/database/sync/initial_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Baixa as tabelas user-scoped do Supabase; a RLS filtra para as linhas
/// do usuário autenticado (nenhum user_id explícito na query).
class SupabaseCloudPullDataSource implements CloudPullDataSource {
  SupabaseCloudPullDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PullSnapshot> fetchAll() async {
    final templates = await _client
        .from('workout_templates')
        .select()
        .order('updated_at');
    final sessions = await _client
        .from('workout_sessions')
        .select()
        .order('updated_at');
    final sets = await _client
        .from('exercise_sets')
        .select()
        .order('updated_at');
    final water = await _client
        .from('water_intake')
        .select()
        .order('updated_at');

    return PullSnapshot(
      workoutTemplates: _copy(templates),
      workoutSessions: _copy(sessions),
      exerciseSets: _copy(sets),
      waterIntake: _copy(water),
    );
  }

  static List<Map<String, dynamic>> _copy(List<dynamic> rows) =>
      rows.cast<Map<String, dynamic>>().map(Map<String, dynamic>.from).toList();
}
