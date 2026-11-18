import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_local_datasource.dart';
import 'package:olimpus/features/exercise/data/datasources/substitute_datasource.dart';

final substituteDatasourceProvider = Provider<SubstituteDatasource>((ref) {
  return SubstituteDatasource(ref.watch(supabaseClientProvider));
});

/// Substituições do exercício: tenta RPC estruturada; se vier vazia,
/// cai no fallback LLM (rate limit compartilhado por usuário/semana).
///
/// Resolve o nome em pt-BR no catálogo local usando `id` ou `externalId`
/// quando disponível, mantendo o nome retornado pelo backend como fallback.
final substitutesProvider = FutureProvider.autoDispose
    .family<List<SubstituteSuggestion>, String>((ref, exerciseId) async {
      final suggestions = await ref
          .watch(substituteDatasourceProvider)
          .getSubstitutes(exerciseId);
      if (suggestions.isEmpty) return suggestions;

      final keys = <String>[
        for (final s in suggestions) ...[
          if (s.id.isNotEmpty) s.id,
          if (s.externalId != null && s.externalId!.isNotEmpty) s.externalId!,
        ],
      ];
      if (keys.isEmpty) return suggestions;

      final localDs = ExerciseLocalDataSource(ref.watch(appDatabaseProvider));
      final localizedNames = await localDs.findNamesByKeys(keys);
      if (localizedNames.isEmpty) return suggestions;

      return suggestions
          .map((s) {
            final translated =
                localizedNames[s.id] ??
                (s.externalId != null ? localizedNames[s.externalId!] : null);
            return translated != null ? s.copyWith(name: translated) : s;
          })
          .toList(growable: false);
    });
