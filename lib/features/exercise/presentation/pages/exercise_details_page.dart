import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/exercise.dart';
import '../providers/exercise_providers.dart';
import '../utils/exercise_labels.dart';
import '../widgets/add_to_template_sheet.dart';

class ExerciseDetailsPage extends ConsumerWidget {
  final Exercise? exercise;
  final String? exerciseId;

  const ExerciseDetailsPage({super.key, required Exercise this.exercise})
    : exerciseId = null;

  const ExerciseDetailsPage.byId({super.key, required String this.exerciseId})
    : exercise = null;

  factory ExerciseDetailsPage.fromRouteState({
    required String id,
    Object? extra,
  }) {
    if (extra is Exercise) {
      return ExerciseDetailsPage(exercise: extra);
    }
    return ExerciseDetailsPage.byId(exerciseId: id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exercise != null) {
      return _buildScaffold(context, ref, exercise!);
    }

    final exercisesAsync = ref.watch(baseExercisesStreamProvider);
    return exercisesAsync.when(
      data: (exercises) {
        final found = exercises.where((e) => e.id == exerciseId).firstOrNull;
        if (found == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Exercício')),
            body: const Center(child: Text('Exercício não encontrado.')),
          );
        }
        return _buildScaffold(context, ref, found);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Exercício')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Exercício')),
        body: Center(child: Text('Erro ao carregar exercício: $error')),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref,
    Exercise currentExercise,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final sectionTitle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final secondary = currentExercise.secondaryMuscleList;

    return Scaffold(
      appBar: AppBar(title: Text(currentExercise.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImageGallery(imageUrls: currentExercise.imageUrlList),

            const SizedBox(height: 24),

            Text('Músculo Alvo', style: sectionTitle),
            const SizedBox(height: 8),
            _MuscleChips(
              muscles: currentExercise.primaryMuscleList,
              primary: true,
            ),

            if (secondary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Músculos Secundários',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _MuscleChips(muscles: secondary, primary: false),
            ],

            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(
                  icon: Icons.handyman_outlined,
                  label: 'Equipamento',
                  value: equipmentLabel(currentExercise.equipment),
                ),
                _DetailChip(
                  icon: Icons.signal_cellular_alt,
                  label: 'Nível',
                  value: levelLabel(currentExercise.level),
                ),
                _DetailChip(
                  label: 'Categoria',
                  value: categoryLabel(currentExercise.category),
                ),
                _DetailChip(
                  label: 'Mecânica',
                  value: mechanicLabel(currentExercise.mechanic),
                ),
                _DetailChip(
                  label: 'Força',
                  value: forceLabel(currentExercise.force),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text('Instruções', style: sectionTitle),
            const SizedBox(height: 8),
            _InstructionSteps(steps: currentExercise.instructionSteps),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: () =>
              addExerciseToTemplateFlow(context, ref, currentExercise),
          icon: const Icon(Icons.playlist_add),
          label: const Text('Usar no treino'),
        ),
      ),
    );
  }
}

/// Galeria horizontal das imagens do exercício (posições 0/1 do dataset).
///
/// Imagens remotas usam [CachedNetworkImage] para ficarem em cache em disco.
class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final urls = widget.imageUrls;

    if (urls.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cardColor,
        ),
        child: const Center(
          child: Icon(Icons.fitness_center, size: 60, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cardColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) => _GalleryImage(url: urls[index]),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            key: const Key('exercise-gallery-indicator'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < urls.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == _current
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Substitua este arquivo vazio na pasta assets/gifs',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      ),
    );
  }
}

class _MuscleChips extends StatelessWidget {
  const _MuscleChips({required this.muscles, required this.primary});

  final List<String> muscles;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodyLarge);
    }
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final muscle in muscles)
          Chip(
            label: Text(muscleLabel(muscle)),
            visualDensity: VisualDensity.compact,
            backgroundColor: primary ? scheme.primaryContainer : null,
            labelStyle: primary
                ? TextStyle(color: scheme.onPrimaryContainer)
                : null,
            side: primary ? BorderSide.none : null,
          ),
      ],
    );
  }
}

class _InstructionSteps extends StatelessWidget {
  const _InstructionSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (steps.isEmpty) {
      return Text(
        'Nenhuma instrução disponível para este exercício.',
        style: textTheme.bodyLarge?.copyWith(height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(
                    '${i + 1}',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[i],
                    style: textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon != null ? Icon(icon, size: 18) : null,
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
