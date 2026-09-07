import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/exercise/data/datasources/substitute_datasource.dart';

final substituteDatasourceProvider = Provider<SubstituteDatasource>((ref) {
  return SubstituteDatasource();
});

/// Substituições do exercício: tenta RPC estruturada; se vier vazia,
/// cai no fallback LLM (rate limit compartilhado por usuário/semana).
final substitutesProvider = FutureProvider.autoDispose
    .family<List<SubstituteSuggestion>, String>((ref, exerciseId) {
      return ref.watch(substituteDatasourceProvider).getSubstitutes(exerciseId);
    });
