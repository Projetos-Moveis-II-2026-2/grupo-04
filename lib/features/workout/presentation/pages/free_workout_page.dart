import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/providers/action_feedback_provider.dart';
import 'package:olimpus/core/utils/ui_feedback_extension.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/workout/presentation/providers/free_workout_exercises_provider.dart';
import 'package:olimpus/features/workout/presentation/widgets/exercise_picker_sheet.dart';

import '../../data/repositories/free_workout_repository.dart';

final _freeWorkoutRepositoryProvider = Provider<FreeWorkoutRepository>((ref) {
  return FreeWorkoutRepository(ref.watch(appDatabaseProvider));
});

final _completedSetsProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  return ref
      .watch(_freeWorkoutRepositoryProvider)
      .watchCompletedSetCount(userId);
});

class FreeWorkoutPage extends ConsumerWidget {
  const FreeWorkoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Treino livre')),
      body: user == null
          ? null
          : _FreeWorkout(key: ValueKey(user.id), userId: user.id),
    );
  }
}

class _FreeWorkout extends ConsumerStatefulWidget {
  const _FreeWorkout({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<_FreeWorkout> createState() => _FreeWorkoutState();
}

class _FreeWorkoutState extends ConsumerState<_FreeWorkout> {
  static const _restDuration = Duration(minutes: 1);

  final _form = GlobalKey<FormState>();
  final _exerciseInput = TextEditingController();
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _rest = ValueNotifier((
    seconds: _restDuration.inSeconds,
    running: false,
  ));
  Exercise? _exercise;
  bool _exerciseInvalid = false;
  bool _saving = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _rest.dispose();
    _exerciseInput.dispose();
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  double? _parseWeight(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  Future<void> _pickExercise() async {
    if (_saving) return;
    final selected = await showExercisePickerSheet(context);
    if (!mounted || selected == null) return;
    setState(() {
      _exercise = selected;
      _exerciseInput.text = selected.name;
      _exerciseInvalid = false;
    });
  }

  Future<void> _completeSet() async {
    if (_saving) return;
    final exercise = _exercise;
    final inputsValid = _form.currentState?.validate() ?? false;
    if (exercise == null || _exerciseInput.text != exercise.name) {
      setState(() => _exerciseInvalid = true);
      return;
    }
    if (!inputsValid) return;

    setState(() {
      _exerciseInvalid = false;
      _saving = true;
    });
    try {
      await ref
          .read(_freeWorkoutRepositoryProvider)
          .completeSet(
            userId: widget.userId,
            exerciseId: exercise.id,
            reps: int.parse(_reps.text.trim()),
            weightKg: _parseWeight(_weight.text)!,
          );
      if (!mounted) return;
      unawaited(ref.read(actionFeedbackProvider.notifier).play());
      context.showSuccessSnackBar('Série concluída');
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(
          error,
          customMessage: 'Erro ao salvar a série.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishWorkout() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(_freeWorkoutRepositoryProvider)
          .finishWorkout(widget.userId);
      if (!mounted) return;
      _stopTimer();
      context.showSuccessSnackBar('Treino concluído');
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(
          error,
          customMessage: 'Erro ao concluir o treino.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    final end = DateTime.now().add(_restDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = (end.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil();
      if (remaining <= 0) {
        timer.cancel();
        _timer = null;
      }
      _rest.value = (
        seconds: remaining.clamp(0, _restDuration.inSeconds),
        running: _timer != null,
      );
    });
    _rest.value = (seconds: _restDuration.inSeconds, running: true);
    unawaited(
      ref.read(actionFeedbackProvider.notifier).play(lightImpact: true),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _rest.value = (seconds: _restDuration.inSeconds, running: false);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutExercisesProvider);
    final count = ref.watch(_completedSetsProvider(widget.userId));
    const buttonStyle = ButtonStyle(enableFeedback: false);
    final isCatalogLoading = exercises.isLoading && !exercises.hasValue;
    final hasCatalogError = exercises.hasError && !exercises.hasValue;

    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        count.when(
          data: (total) => Text('Séries concluídas neste treino: $total'),
          loading: () => const Text('Carregando séries…'),
          error: (_, _) => const Text('Erro ao carregar séries.'),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('free_workout_exercise_field'),
                controller: _exerciseInput,
                readOnly: true,
                showCursor: false,
                mouseCursor: _saving
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                enabled: !_saving,
                onTap: _saving ? null : _pickExercise,
                decoration: InputDecoration(
                  labelText: 'Exercício',
                  helperText: isCatalogLoading
                      ? 'Carregando catálogo…'
                      : hasCatalogError
                      ? 'Erro ao carregar exercícios.'
                      : null,
                  errorText: _exerciseInvalid
                      ? 'Selecione um exercício.'
                      : null,
                  suffixIcon: isCatalogLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.arrow_drop_down),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weight,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Carga (kg)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final weight = _parseWeight(value);
                  return weight == null || !weight.isFinite || weight < 0
                      ? 'Informe uma carga válida.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reps,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Repetições'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (int.tryParse(value?.trim() ?? '') ?? 0) > 0
                    ? null
                    : 'Informe um número de repetições maior que zero.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: buttonStyle,
                icon: const Icon(Icons.check),
                label: const Text('Concluir série'),
                onPressed: _saving ? null : _completeSet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: _rest,
          builder: (context, rest, _) {
            final minutes = rest.seconds ~/ 60;
            final seconds = (rest.seconds % 60).toString().padLeft(2, '0');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rest.seconds == 0
                      ? 'Descanso concluído'
                      : 'Descanso · $minutes:$seconds',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                OutlinedButton.icon(
                  style: buttonStyle,
                  onPressed: rest.running ? _stopTimer : _startTimer,
                  icon: Icon(rest.running ? Icons.stop : Icons.timer_outlined),
                  label: Text(rest.running ? 'Parar timer' : 'Iniciar timer'),
                ),
              ],
            );
          },
        ),
        if ((count.value ?? 0) > 0)
          TextButton(
            onPressed: _saving ? null : _finishWorkout,
            child: const Text('Concluir treino'),
          ),
      ],
    );
  }
}
