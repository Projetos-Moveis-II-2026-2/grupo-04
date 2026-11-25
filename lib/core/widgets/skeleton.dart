import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Bloco base para exibição de skeletons na UI.
///
/// Aceita [width], [height], [borderRadius] e [shape], derivando suas cores
/// diretamente de [Theme.of(context).colorScheme] para manter compatibilidade
/// e legibilidade tanto no tema claro quanto no escuro, sem cores fixas.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  const Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = null,
      shape = BoxShape.circle;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark ||
        colorScheme.brightness == Brightness.dark;

    final color = isDark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerHigh;

    return Semantics(
      label: 'Carregando',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : (borderRadius ?? BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Wrapper que aplica o efeito de brilho animado (shimmer) a widgets skeleton filhos.
///
/// Se [MediaQuery.disableAnimationsOf] for verdadeiro ou se [enabled] for falso,
/// o shimmer é desativado e os widgets filhos são exibidos de forma estática.
/// Cores de base e destaque derivam de [ColorScheme].
class SkeletonWrapper extends StatelessWidget {
  const SkeletonWrapper({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark ||
        colorScheme.brightness == Brightness.dark;

    // Cores de fundo e destaque calculadas a partir do ColorScheme
    final baseColor = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainer;
    final highlightColor = isDark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerLowest;

    Widget content = child;

    if (enabled && !disableAnimations) {
      content = Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: child,
      );
    }

    return Semantics(label: 'Carregando', container: true, child: content);
  }
}
