import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/exercise/data/datasources/substitute_datasource.dart';
import 'package:olimpus/features/exercise/presentation/providers/substitution_provider.dart';

/// Bottom sheet do assistente de substituição (#28): lista cards com
/// imagem/nome/equipamento das substituições do exercício.
///
/// Ao abrir, consome [substitutesProvider]; o retorno é o id do
/// exercício escolhido (ou null se fechado sem escolha) — a tela que
/// abrir o sheet troca o exercício no template.
Future<String?> showSubstitutionSheet(
  BuildContext context,
  WidgetRef ref,
  String exerciseId,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, controller) => _SubstitutionSheetBody(
        exerciseId: exerciseId,
        controller: controller,
      ),
    ),
  );
}

class _SubstitutionSheetBody extends ConsumerWidget {
  const _SubstitutionSheetBody({
    required this.exerciseId,
    required this.controller,
  });

  final String exerciseId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(substitutesProvider(exerciseId));
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Substituir exercício',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (async) {
            AsyncValue(:final isLoading) when isLoading => const Center(
              child: CircularProgressIndicator(),
            ),
            AsyncValue(:final value?) when value.isNotEmpty =>
              ListView.separated(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) =>
                    _SubstituteCard(suggestion: value[i]),
              ),
            AsyncValue(isLoading: false, hasValue: true) => Center(
              child: Text(
                'Nenhuma substituição encontrada.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            AsyncValue(:final error?) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  error is SubstituteRateLimited
                      ? 'Assistente indisponível por limite semanal.'
                      : 'Não foi possível buscar substituições.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(substitutesProvider(exerciseId)),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

class _SubstituteCard extends StatelessWidget {
  const _SubstituteCard({required this.suggestion});

  final SubstituteSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectable = suggestion.id.isNotEmpty;
    final onTap = selectable
        ? () => Navigator.of(context).pop(suggestion.id)
        : null;

    return ListTile(
      onTap: onTap,
      enabled: selectable,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: suggestion.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: suggestion.imageUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => const Icon(Icons.fitness_center),
              )
            : const Icon(Icons.fitness_center, size: 32),
      ),
      title: Text(
        suggestion.name + (selectable ? '' : ' (fora do catálogo)'),
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (suggestion.equipment != null) Text(suggestion.equipment!),
          if (suggestion.reason != null) Text(suggestion.reason!),
        ],
      ),
      isThreeLine: suggestion.reason != null,
    );
  }
}
