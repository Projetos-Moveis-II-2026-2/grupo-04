import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/features/progress/domain/entities/streak.dart';
import 'package:olimpus/features/progress/presentation/providers/progress_providers.dart';
import 'package:olimpus/features/progress/presentation/widgets/streak_card.dart';
import 'package:olimpus/features/workout/presentation/pages/templates_page.dart';

import '../providers/auth_providers.dart';

/// Aba "Início" (Dashboard principal do aplicativo).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Olimpus',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de Boas-Vindas
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(
                        Icons.bolt,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bem-vindo de volta!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Atleta',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Resumo compacto de streaks (treino e hidratação)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suas sequências',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/progress'),
                  child: const Text('Ver evolução'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _HomeStreakSummary(),
            const SizedBox(height: 24),

            // Seção Minhas Fichas de Treino (Home)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Minhas Fichas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/templates/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova ficha'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const TemplatesListView(shrinkWrap: true, compact: true),
            const SizedBox(height: 24),

            // Seção de Atalhos Rápidos
            Text(
              'Acesso Rápido',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _DashboardActionCard(
                    icon: Icons.fitness_center,
                    title: 'Treinos',
                    subtitle: 'Iniciar sessão',
                    color: theme.colorScheme.primary,
                    onTap: () => context.go('/workout'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardActionCard(
                    icon: Icons.sports_gymnastics,
                    title: 'Exercícios',
                    subtitle: 'Explorar catálogo',
                    color: theme.colorScheme.secondary,
                    onTap: () => context.go('/exercises'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DashboardActionCard(
              icon: Icons.water_drop_rounded,
              title: 'Hidratação',
              subtitle: 'Acompanhe seu consumo e histórico diário',
              color: const Color(0xFF0288D1),
              onTap: () => context.push('/water'),
            ),
            const SizedBox(height: 12),
            _DashboardActionCard(
              icon: Icons.bar_chart,
              title: 'Minha Evolução',
              subtitle: 'Histórico de cargas, volume e metas',
              color: theme.colorScheme.tertiary,
              onTap: () => context.go('/progress'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumo compacto dos streaks de treino e hidratação exibido na Home.
class _HomeStreakSummary extends ConsumerWidget {
  const _HomeStreakSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutStreak = ref.watch(workoutStreakProvider);
    final waterStreak = ref.watch(waterStreakProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StreakAsync(
            streakAsync: workoutStreak,
            type: StreakType.workout,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StreakAsync(streakAsync: waterStreak, type: StreakType.water),
        ),
      ],
    );
  }
}

class _StreakAsync extends StatelessWidget {
  const _StreakAsync({required this.streakAsync, required this.type});

  final AsyncValue<Streak> streakAsync;
  final StreakType type;

  @override
  Widget build(BuildContext context) {
    return streakAsync.when(
      data: (streak) => StreakCard(streak: streak, type: type, compact: true),
      loading: () => const Card(elevation: 0, child: SizedBox(height: 58)),
      error: (_, _) => const SizedBox(height: 58),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
