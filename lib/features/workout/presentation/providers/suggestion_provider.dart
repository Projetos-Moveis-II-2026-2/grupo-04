import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/workout/data/datasources/ai_datasource.dart';

final aiDatasourceProvider = Provider<AiDatasource>((ref) {
  return AiDatasource(ref.watch(supabaseClientProvider));
});

/// Sugestão de carga para o exercício aberto na execução.
/// Estados: loading (chamando), data (sugestão), error (404 sem histórico,
/// 429 rate limit, falha de rede/IA).
final suggestionProvider = FutureProvider.autoDispose
    .family<LoadSuggestion, String>((ref, exerciseId) {
      return ref.watch(aiDatasourceProvider).getSuggestion(exerciseId);
    });
