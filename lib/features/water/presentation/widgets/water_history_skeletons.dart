import 'package:flutter/material.dart';
import 'package:olimpus/core/widgets/skeleton.dart';

/// Skeleton do card de total diário de consumo de água.
class DailyWaterTotalCardSkeleton extends StatelessWidget {
  const DailyWaterTotalCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SkeletonWrapper(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Skeleton.circle(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Skeleton(width: 110, height: 14),
                        SizedBox(height: 6),
                        Skeleton(width: 140, height: 12),
                      ],
                    ),
                  ),
                  Skeleton(
                    width: 50,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Skeleton(width: 140, height: 36),
                  SizedBox(width: 8),
                  Skeleton(width: 36, height: 18),
                ],
              ),
              const SizedBox(height: 14),
              Skeleton(height: 10, borderRadius: BorderRadius.circular(8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton do gráfico semanal de consumo de água (altura 180 na área de barras).
class WeeklyWaterChartSkeleton extends StatelessWidget {
  const WeeklyWaterChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SkeletonWrapper(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Skeleton(width: 100, height: 16),
                      SizedBox(height: 6),
                      Skeleton(width: 130, height: 12),
                    ],
                  ),
                  Row(
                    children: const [
                      Skeleton.circle(size: 10),
                      SizedBox(width: 6),
                      Skeleton(width: 32, height: 12),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(100),
                    _bar(140),
                    _bar(80),
                    _bar(120),
                    _bar(90),
                    _bar(150),
                    _bar(110),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Skeleton(
          width: 22,
          height: height,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        const Skeleton(width: 22, height: 12),
      ],
    );
  }
}

/// Skeleton da lista de registros de água de hoje.
class TodayWaterEntriesListSkeleton extends StatelessWidget {
  const TodayWaterEntriesListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Skeleton(width: 130, height: 16),
                Skeleton(width: 60, height: 12),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: const ListTile(
                  leading: Skeleton(
                    width: 38,
                    height: 38,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  title: Skeleton(width: 70, height: 16),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Skeleton(width: 40, height: 12),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
