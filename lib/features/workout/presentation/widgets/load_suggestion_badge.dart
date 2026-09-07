import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/workout/data/datasources/ai_datasource.dart';
import 'package:olimpus/features/workout/presentation/providers/suggestion_provider.dart';

/// Badge da sugestão de carga (IA) na tela de execução. Consome
/// [suggestionProvider] — 404/429/falhas aparecem como mensagem curta.
class LoadSuggestionBadge extends ConsumerWidget {
  const LoadSuggestionBadge({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestionProvider(exerciseId));
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: switch (async) {
          AsyncValue(:final isLoading) when isLoading => Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Calculando sugestão de carga…',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          AsyncValue(:final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 18,
                    color: value.suggestIncrease ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value.suggestIncrease
                        ? 'Pode aumentar!'
                        : 'Mantenha a carga',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(value.recommendation, style: theme.textTheme.bodyMedium),
              if (value.nextWeightKg != null || value.nextReps != null)
                Text(_nextLine(value), style: theme.textTheme.bodySmall),
            ],
          ),
          AsyncValue(:final error?) => Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error is SuggestionRateLimited
                      ? 'Sugestão indisponível por limite semanal. ${error.nextAvailableAt != null ? 'Volte após ${_fmt(error.nextAvailableAt!)}.' : ''}'
                      : 'Sugestão indisponível agora.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => ref.invalidate(suggestionProvider(exerciseId)),
              ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  String _nextLine(LoadSuggestion value) {
    final parts = <String>[
      if (value.nextWeightKg != null) 'Próxima carga: ${value.nextWeightKg} kg',
      if (value.nextReps != null) 'Reps: ${value.nextReps}',
    ];
    return parts.join(' · ');
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
