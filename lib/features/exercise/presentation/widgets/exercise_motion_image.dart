import 'package:flutter/material.dart';

import '../../../../core/constants/api_endpoints.dart';
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

  static const _mediaBaseUrl = String.fromEnvironment(
    'EXERCISE_MEDIA_BASE_URL',
    defaultValue:
        '${ApiEndpoints.supabaseUrl}/storage/v1/object/public/exercise-media/v1',
  );
  static const _originalBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
  static const _legacyCdnUrl =
      'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/';

  static String? motionUrlFor(String externalId, List<String> frames) {
    final first = frames.firstOrNull;
    final second = frames.elementAtOrNull(1);
    if (first == null || second == null) return null;

    final id = Uri.encodeComponent(externalId);
    if (_mediaBaseUrl.isNotEmpty &&
        _isCatalogFrame(first, id, 0) &&
        _isCatalogFrame(second, id, 1)) {
      return '$_mediaBaseUrl/$id/motion.webp';
    }

    // O catálogo do Supabase grava a miniatura antes do WebP animado.
    const thumbnailFile = '/thumbnail.webp';
    if (!first.endsWith(thumbnailFile)) return null;
    final directory = first.substring(0, first.length - thumbnailFile.length);
    return second == '$directory/motion.webp' ? second : null;
  }

  static bool _isCatalogFrame(String url, String id, int index) =>
      url == '$_originalBaseUrl$id/$index.jpg' ||
      url == '$_legacyCdnUrl$id/$index.jpg';

  @override
  Widget build(BuildContext context) {
    final frames = exercise.imageUrlList;
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

    // O Drift ainda guarda os JPGs do catálogo local em instalações existentes.
    final id = Uri.encodeComponent(exercise.externalId);
    final legacyImage = first.startsWith(_originalBaseUrl)
        ? first.replaceFirst(_originalBaseUrl, _legacyCdnUrl)
        : first;
    final thumbnail = _mediaBaseUrl.isNotEmpty && _isCatalogFrame(first, id, 0)
        ? '$_mediaBaseUrl/$id/thumbnail.webp'
        : null;
    final motion = allowMotion
        ? motionUrlFor(exercise.externalId, frames)
        : null;
    final optimized = motion ?? thumbnail;
    if (optimized == null) return _networkImage(legacyImage, error);
    return Image.network(
      optimized,
      fit: fit,
      errorBuilder: (context, errorDetails, stackTrace) =>
          _networkImage(legacyImage, error),
    );
  }

  Widget _networkImage(String url, Widget error) => Image.network(
    url,
    fit: fit,
    errorBuilder: (context, errorDetails, stackTrace) => error,
  );
}
