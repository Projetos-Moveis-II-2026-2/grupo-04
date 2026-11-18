@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/local_supabase.dart';
import 'helpers/test_env.dart';

/// RLS pode responder com lista vazia (linhas invisíveis) ou com erro HTTP.
Future<void> _expectRlsDenied(
  Future<List<Map<String, dynamic>>> Function() action,
) async {
  try {
    final rows = await action();
    expect(
      rows,
      isEmpty,
      reason: 'RLS deveria ocultar/negar o acesso aos dados de outro usuário.',
    );
  } on PostgrestException {
    // Negação explícita do PostgREST também é um resultado válido.
  }
}

Future<String> _insertOwnSession(TestUser owner) async {
  final id = randomUuid();
  final now = DateTime.now().toUtc();
  await owner.client
      .from('workout_sessions')
      .insert({
        'id': id,
        'user_id': owner.id,
        'started_at': now.toIso8601String(),
        'completed_at': now.add(const Duration(minutes: 30)).toIso8601String(),
        'total_volume_kg': 350.0,
        'notes': 'Sessão do usuário A (teste RLS #56)',
      })
      .select('id')
      .single();
  return id;
}

Future<String> _insertOwnWater(TestUser owner) async {
  final id = randomUuid();
  final now = DateTime.now().toUtc();
  await owner.client
      .from('water_intake')
      .insert({
        'id': id,
        'user_id': owner.id,
        'amount_ml': 350,
        'recorded_at': now.toIso8601String(),
        'date': now.toIso8601String().substring(0, 10),
      })
      .select('id')
      .single();
  return id;
}

void main() {
  group('RLS no Supabase local', () {
    late LocalSupabase local;
    late TestUser userA;
    late TestUser userB;

    setUp(() async {
      local = LocalSupabase();
      userA = await local.createUser(prefix: 'rls.a');
      userB = await local.createUser(prefix: 'rls.b');
    });

    tearDown(() async {
      await local.dispose();
    });

    test('usuário B não lê, atualiza nem apaga workout_session de A', () async {
      final sessionId = await _insertOwnSession(userA);

      await _expectRlsDenied(
        () => userB.client
            .from('workout_sessions')
            .select('id')
            .eq('id', sessionId),
      );

      await _expectRlsDenied(
        () => userB.client
            .from('workout_sessions')
            .update({'notes': 'tentativa de invasão'})
            .eq('id', sessionId)
            .select('id'),
      );

      await _expectRlsDenied(
        () => userB.client
            .from('workout_sessions')
            .delete()
            .eq('id', sessionId)
            .select('id'),
      );

      final owned = await userA.client
          .from('workout_sessions')
          .select('id, notes')
          .eq('id', sessionId)
          .maybeSingle();
      expect(owned, isNotNull);
      expect(owned!['notes'], 'Sessão do usuário A (teste RLS #56)');
    });

    test('usuário B não lê, atualiza nem apaga water_intake de A', () async {
      final waterId = await _insertOwnWater(userA);

      await _expectRlsDenied(
        () => userB.client.from('water_intake').select('id').eq('id', waterId),
      );

      await _expectRlsDenied(
        () => userB.client
            .from('water_intake')
            .update({'amount_ml': 5000})
            .eq('id', waterId)
            .select('id'),
      );

      await _expectRlsDenied(
        () => userB.client
            .from('water_intake')
            .delete()
            .eq('id', waterId)
            .select('id'),
      );

      final owned = await userA.client
          .from('water_intake')
          .select('id, amount_ml')
          .eq('id', waterId)
          .maybeSingle();
      expect(owned, isNotNull);
      expect(owned!['amount_ml'], 350);
    });
  }, skip: supabaseSkipReasonOrNull);
}
