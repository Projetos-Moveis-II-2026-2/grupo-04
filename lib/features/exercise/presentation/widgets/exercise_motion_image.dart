import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Exibe a imagem de um exercício, alternando suavemente entre os quadros
/// (ex.: posição inicial `0.jpg` e final `1.jpg`) para simular o movimento.
///
/// - Com 2+ quadros e [animate] `true`: alterna em loop ping-pong (0 → 1 → 0)
///   com cross-fade via [AnimatedSwitcher].
/// - Com 1 quadro, [animate] `false` ou quando o sistema solicita redução de
///   movimento ([MediaQuery.disableAnimationsOf]): exibe o primeiro quadro
///   estático e não mantém [Timer] ativo.
/// - Sem quadros: exibe [fallback] (padrão: ícone [Icons.fitness_center]).
class ExerciseMotionImage extends StatefulWidget {
  final List<String> frames;
  final BoxFit fit;
  final Duration frameDuration;
  final Duration transitionDuration;
  final bool animate;
  final Widget? fallback;
  final Widget? errorWidget;

  const ExerciseMotionImage({
    super.key,
    required this.frames,
    this.fit = BoxFit.contain,
    this.frameDuration = const Duration(milliseconds: 700),
    this.transitionDuration = const Duration(milliseconds: 250),
    this.animate = true,
    this.fallback,
    this.errorWidget,
  });

  @override
  State<ExerciseMotionImage> createState() => _ExerciseMotionImageState();
}

class _ExerciseMotionImageState extends State<ExerciseMotionImage> {
  Timer? _timer;
  late List<String> _frames;
  int _currentIndex = 0;
  int _direction = 1;
  final Set<String> _precachedFrames = <String>{};

  static List<String> _sanitizeFrames(List<String> raw) {
    return raw
        .map((frame) => frame.trim())
        .where((frame) => frame.isNotEmpty)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _frames = _sanitizeFrames(widget.frames);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant ExerciseMotionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedFrames = _sanitizeFrames(widget.frames);
    final framesChanged = !listEquals(updatedFrames, _frames);
    if (framesChanged) {
      _frames = updatedFrames;
      _currentIndex = 0;
      _direction = 1;
      _precachedFrames.clear();
    }

    if (framesChanged ||
        widget.animate != oldWidget.animate ||
        widget.frameDuration != oldWidget.frameDuration) {
      _stopTimer();
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final shouldAnimate =
        widget.animate && !disableAnimations && _frames.length >= 2;

    if (!shouldAnimate) {
      _stopTimer();
      if (_currentIndex != 0) {
        _currentIndex = 0;
        _direction = 1;
      }
      return;
    }

    _precacheFramesIfNeeded();
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(widget.frameDuration, (_) => _advanceFrame());
    }
  }

  void _precacheFramesIfNeeded() {
    for (final frame in _frames) {
      if (_precachedFrames.add(frame)) {
        final ImageProvider provider = frame.startsWith('assets/')
            ? AssetImage(frame)
            : CachedNetworkImageProvider(frame);
        precacheImage(provider, context, onError: (_, _) {});
      }
    }
  }

  void _advanceFrame() {
    if (!mounted || _frames.length < 2) return;
    setState(() {
      final next = _currentIndex + _direction;
      if (next >= _frames.length) {
        _direction = -1;
        _currentIndex = _frames.length - 2;
      } else if (next < 0) {
        _direction = 1;
        _currentIndex = 1;
      } else {
        _currentIndex = next;
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) {
      return widget.fallback ??
          const Center(
            child: Icon(Icons.fitness_center, size: 60, color: Colors.grey),
          );
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final shouldAnimate =
        widget.animate && !disableAnimations && _frames.length >= 2;

    final safeIndex = shouldAnimate && _currentIndex < _frames.length
        ? _currentIndex
        : 0;
    final currentFrame = _frames[safeIndex];
    final frameWidget = _buildFrame(context, currentFrame);

    if (!shouldAnimate) {
      return frameWidget;
    }

    return AnimatedSwitcher(
      duration: widget.transitionDuration,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [...previousChildren, ?currentChild],
        );
      },
      child: frameWidget,
    );
  }

  Widget _buildFrame(BuildContext context, String frameUrl) {
    final defaultError =
        widget.errorWidget ??
        const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        );

    if (frameUrl.startsWith('assets/')) {
      return SizedBox.expand(
        key: ValueKey<String>(frameUrl),
        child: Image.asset(
          frameUrl,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => defaultError,
        ),
      );
    }

    return SizedBox.expand(
      key: ValueKey<String>(frameUrl),
      child: CachedNetworkImage(
        imageUrl: frameUrl,
        fit: widget.fit,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => defaultError,
      ),
    );
  }
}
