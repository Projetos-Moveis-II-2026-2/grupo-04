import 'package:flutter/material.dart';

import '../../../../core/constants/exercise_media.dart';
import '../../domain/entities/exercise.dart';

class ExerciseMotionImage extends StatelessWidget {
  const ExerciseMotionImage({
    super.key,
    required this.exercise,
    required this.fit,
    this.animate = true,
    this.fallback = const Center(child: Icon(Icons.fitness_center)),
    this.errorFallback,
  });

  final Exercise exercise;
  final BoxFit fit;
  final bool animate;
  final Widget fallback;
  final Widget? errorFallback;

  /// URL da animação quando [frames] contém o par de quadros do catálogo
  /// (0 e 1) ou o formato legado `[...,/thumbnail.webp, ...,/motion.webp]`.
  static String? motionUrlFor(String externalId, List<String> frames) {
    final first = frames.firstOrNull;
    final second = frames.elementAtOrNull(1);
    if (first == null || second == null) return null;

    if (ExerciseMedia.isFrame(first, externalId, 0) &&
        ExerciseMedia.isFrame(second, externalId, 1)) {
      return ExerciseMedia.motionUrl(externalId);
    }

    // Ajusta formatos antigos antes de comparar o par miniatura/animação.
    final normalizedFirst = ExerciseMedia.normalize(first);
    final normalizedSecond = ExerciseMedia.normalize(second);
    const thumbnailFile = '/thumbnail.webp';
    if (!normalizedFirst.endsWith(thumbnailFile)) return null;
    final directory = normalizedFirst.substring(
      0,
      normalizedFirst.length - thumbnailFile.length,
    );
    return normalizedSecond == '$directory/motion.webp'
        ? normalizedSecond
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final frames = exercise.imageUrlList
        .map(ExerciseMedia.normalize)
        .toList(growable: false);
    if (frames.isEmpty) return fallback;

    final first = frames.first;
    final allowMotion = animate && !MediaQuery.disableAnimationsOf(context);
    final error = errorFallback ?? fallback;

    if (first.startsWith('assets/')) {
      return Image.asset(
        first,
        fit: fit,
        errorBuilder: (context, errorDetails, stackTrace) => error,
      );
    }

    final isFirstFrame = ExerciseMedia.isFrame(first, exercise.externalId, 0);
    final thumbnail = isFirstFrame
        ? ExerciseMedia.thumbnailUrl(exercise.externalId)
        : null;
    final motion = allowMotion
        ? motionUrlFor(exercise.externalId, frames)
        : null;
    final optimized = motion ?? thumbnail;
    if (optimized == null) return _networkImage(first, error);
    return Image.network(
      optimized,
      fit: fit,
      errorBuilder: (context, errorDetails, stackTrace) =>
          _networkImage(first, error),
    );
  }

  Widget _networkImage(String url, Widget error) => Image.network(
    url,
    fit: fit,
    errorBuilder: (context, errorDetails, stackTrace) => error,
  );
}
