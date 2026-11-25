import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/core/utils/ui_feedback_extension.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/usecases/compute_volume.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_session_providers.dart';
import 'package:olimpus/features/workout/presentation/widgets/session_set_row.dart';

/// Tela de execução do treino: registra séries (peso/reps/concluída) com a
/// carga da última sessão do mesmo exercício lado a lado.
class WorkoutSessionPage extends ConsumerStatefulWidget {
  const WorkoutSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends ConsumerState<WorkoutSessionPage> {
  /// Valores otimistas por série, para que toques rápidos em +/- não usem um
  /// estado defasado enquanto o Drift ainda não emitiu a atualização.
  final Map<String, SessionSet> _pending = {};
  bool _finishing = false;

  SessionSet _current(SessionSet fromDb) => _pending[fromDb.id] ?? fromDb;

  Future<void> _updateSet(SessionSet set) async {
    setState(() => _pending[set.id] = set);
    try {
      await ref.read(updateSessionSetUseCaseProvider)(set);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(set.id));
      context.showErrorSnackBar(e);
    }
  }

  Future<void> _addSet(String exerciseId) async {
    try {
      await ref.read(addSessionSetUseCaseProvider)(
        sessionId: widget.sessionId,
        exerciseId: exerciseId,
      );
    } on Object catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    }
  }

  Future<void> _finish(WorkoutSessionEntity session) async {
    final pendingSets = session.totalSets - session.completedSets;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Concluir treino'),
        content: Text(
          pendingSets > 0
              ? '$pendingSets série(s) não concluída(s) serão descartadas. '
                    'Deseja concluir o treino?'
              : 'Deseja concluir o treino?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar treinando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _finishing = true);
    try {
      await ref.read(completeWorkoutSessionUseCaseProvider)(widget.sessionId);
      if (!mounted) return;
      context.showSuccessSnackBar('Treino concluído! Bom trabalho 💪');
      final popped = await Navigator.of(context).maybePop();
      if (popped || !mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go('/workout');
      } else {
        setState(() => _finishing = false);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      context.showErrorSnackBar(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(
      workoutSessionStreamProvider(widget.sessionId),
    );

    ref.listen(workoutSessionStreamProvider(widget.sessionId), (_, next) {
      final session = next.value;
      if (session == null || _pending.isEmpty) return;
      for (final ex in session.exercises) {
        for (final s in ex.sets) {
          if (_pending[s.id] == s) _pending.remove(s.id);
        }
      }
    });

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro ao carregar o treino: $e')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Sessão de treino não encontrada.')),
          );
        }
        return _buildSession(context, session);
      },
    );
  }

  Widget _buildSession(BuildContext context, WorkoutSessionEntity session) {
    final theme = Theme.of(context);
    final completed = session.exercises.fold<int>(
      0,
      (sum, e) => sum + e.sets.where((s) => _current(s).completed).length,
    );
    final total = session.totalSets;
    // Volume ao vivo a partir dos valores otimistas (reflete cada toque).
    const computeVolume = ComputeVolume();
    final volume = computeVolume([
      for (final e in session.exercises)
        SessionExercise(
          exerciseId: e.exerciseId,
          exerciseName: e.exerciseName,
          sets: [for (final s in e.sets) _current(s)],
        ),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.templateName ?? 'Treino'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : completed / total,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$completed/$total séries',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Volume total: ${formatVolume(volume.total)} kg',
                      key: const ValueKey('session-volume'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: session.exercises.length,
        itemBuilder: (context, index) {
          final exercise = session.exercises[index];
          return _ExerciseCard(
            exercise: exercise,
            volumeKg: volume.of(exercise.exerciseId),
            previousVolumeKg: computeVolume.ofSets(exercise.previousSets),
            readOnly: session.isCompleted,
            current: _current,
            onSetChanged: _updateSet,
            onAddSet: () => _addSet(exercise.exerciseId),
          );
        },
      ),
      bottomNavigationBar: session.isCompleted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('finish-session'),
                  onPressed: _finishing ? null : () => _finish(session),
                  icon: _finishing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined),
                  label: const Text('Concluir treino'),
                ),
              ),
            ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.volumeKg,
    required this.previousVolumeKg,
    required this.readOnly,
    required this.current,
    required this.onSetChanged,
    required this.onAddSet,
  });

  final SessionExercise exercise;
  final double volumeKg;
  final double previousVolumeKg;
  final bool readOnly;
  final SessionSet Function(SessionSet) current;
  final ValueChanged<SessionSet> onSetChanged;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previous = exercise.previousSets;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatVolume(volumeKg)} kg',
                        key: ValueKey('volume-${exercise.exerciseId}'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (previousVolumeKg > 0)
                        Text(
                          'anterior: ${formatVolume(previousVolumeKg)} kg',
                          key: ValueKey(
                            'previous-volume-${exercise.exerciseId}',
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              previous.isEmpty
                  ? 'Primeira vez com este exercício'
                  : 'Última sessão: ${previous.map((s) => '${formatKg(s.weightKg)}kg×${s.reps ?? '-'}').join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            const SessionSetHeader(),
            for (final s in exercise.sets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: IgnorePointer(
                  ignoring: readOnly,
                  child: SessionSetRow(
                    set: current(s),
                    previous: exercise.previousFor(s.setNumber),
                    onChanged: onSetChanged,
                  ),
                ),
              ),
            if (!readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddSet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar série'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
