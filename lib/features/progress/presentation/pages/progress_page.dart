import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:olimpus/core/widgets/app_error_widget.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/exercise_load_point.dart';
import '../../domain/entities/user_exercise_summary.dart';
import '../providers/progress_providers.dart';
import '../widgets/exercise_load_chart.dart';
import '../widgets/exercise_selector.dart';
import '../widgets/monthly_calendar_section.dart';

/// Página principal da aba de Progresso e Evolução de Carga.
///
/// Apresenta o calendário mensal de treinos concluídos e, reativamente,
/// o histórico de cargas máximas por exercício,
/// respeitando tema Material 3, ciclo de vida seguro (Riverpod) e estados
/// de carregamento, erro, vazio e exibição gráfica.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final exercisesAsync = ref.watch(userExercisesWithProgressProvider);
    final hasDemoAsync = ref.watch(hasDemoDataProgressionProvider);
    final hasDemoData = hasDemoAsync.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolução'),
        actions: [
          // Ações exclusivas para o modo Debug (Demonstração / Banca)
          if (kDebugMode && user != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Opções de demonstração (debug)',
              onSelected: (value) async {
                final repo = ref.read(progressRepositoryProvider);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                if (value == 'seed') {
                  await repo.seedDemoData(user.id);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Dados de demonstração gerados com sucesso!',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (value == 'clear') {
                  await repo.clearDemoData(user.id);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Dados de demonstração removidos.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'seed',
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Gerar dados de demonstração'),
                    ],
                  ),
                ),
                if (hasDemoData)
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.red,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Limpar dados de demonstração',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppErrorWidget(
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(userExercisesWithProgressProvider),
        ),
        data: (exercises) {
          if (exercises.isEmpty) {
            return _EmptyProgressView(
              onSeedDemo: kDebugMode && user != null
                  ? () async {
                      await ref
                          .read(progressRepositoryProvider)
                          .seedDemoData(user.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Dados de demonstração gerados com sucesso!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  : null,
            );
          }

          return _ProgressDataView(
            exercises: exercises,
            hasDemoData: hasDemoData,
            onClearDemo: kDebugMode && user != null
                ? () async {
                    await ref
                        .read(progressRepositoryProvider)
                        .clearDemoData(user.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dados de demonstração removidos.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : null,
          );
        },
      ),
    );
  }
}

/// Exibição quando ainda não há registros de treino para o usuário.
class _EmptyProgressView extends StatelessWidget {
  const _EmptyProgressView({this.onSeedDemo});

  final VoidCallback? onSeedDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: double.infinity,
              child: MonthlyCalendarSection(),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.trending_up_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Treine para ver sua evolução',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Complete séries nos seus treinos para acompanhar aqui a curva de carga máxima e o seu progresso ao longo do tempo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            // Botão exclusivo de debug para geração rápida de dados de demonstração
            if (kDebugMode && onSeedDemo != null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.science_outlined),
                label: const Text('Gerar dados de demonstração'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                ),
                onPressed: onSeedDemo,
              ),
              const SizedBox(height: 16),
            ],

            // Atalho para consumo de água (mantendo a navegação do placeholder)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.water_drop_rounded),
              label: const Text('Ver Consumo de Água'),
              onPressed: () => context.push('/water'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exibição quando existem exercícios registrados e dados para o gráfico.
class _ProgressDataView extends ConsumerWidget {
  const _ProgressDataView({
    required this.exercises,
    required this.hasDemoData,
    this.onClearDemo,
  });

  final List<UserExerciseSummary> exercises;
  final bool hasDemoData;
  final VoidCallback? onClearDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedExerciseId = ref.watch(activeExerciseIdProvider);
    final progressionAsync = ref.watch(exerciseLoadProgressionProvider);

    final selectedExercise = exercises.firstWhere(
      (e) => e.exerciseId == selectedExerciseId,
      orElse: () => exercises.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner discreto em debug indicando dados de demonstração ativos
          if (kDebugMode && hasDemoData && onClearDemo != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 20,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo demonstração ativo (dados locais de teste).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onClearDemo,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ),
          ],

          const MonthlyCalendarSection(),
          const SizedBox(height: 24),

          // Seletor de Exercício
          Text(
            'Exercício selecionado',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ExerciseSelector(
            exercises: exercises,
            selectedExerciseId: selectedExerciseId,
            onChanged: (newId) {
              if (newId != null) {
                ref.read(selectedExerciseIdProvider.notifier).select(newId);
              }
            },
          ),

          const SizedBox(height: 20),

          // Gráfico de evolução de carga
          progressionAsync.when(
            loading: () => const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => AppErrorWidget(
              error: error,
              stackTrace: stackTrace,
              onRetry: () => ref.invalidate(exerciseLoadProgressionProvider),
            ),
            data: (points) {
              if (points.isEmpty) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.fitness_center_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma série concluída com carga para este exercício.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExerciseLoadChart(
                    exerciseName: selectedExercise.name,
                    points: points,
                  ),
                  const SizedBox(height: 20),
                  _SessionHistoryList(points: points),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Atalho complementar para hidratação
          FilledButton.tonalIcon(
            icon: const Icon(Icons.water_drop_rounded),
            label: const Text('Ver Consumo de Água'),
            onPressed: () => context.push('/water'),
          ),
        ],
      ),
    );
  }
}

/// Lista resumida das sessões passadas do exercício com suas respectivas cargas máximas.
class _SessionHistoryList extends StatelessWidget {
  const _SessionHistoryList({required this.points});

  final List<ExerciseLoadPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final numberFormat = NumberFormat('#,##0.#', 'pt_BR');

    // Exibe em ordem decrescente (mais recente primeiro)
    final reversedPoints = points.reversed.toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Histórico de Sessões',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${points.length} treinos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reversedPoints.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final point = reversedPoints[index];
                final isLatest = index == 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isLatest
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fitness_center_rounded,
                          size: 14,
                          color: isLatest
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dateFormat.format(point.date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isLatest
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        '${numberFormat.format(point.maxWeightKg)} kg',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLatest ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
