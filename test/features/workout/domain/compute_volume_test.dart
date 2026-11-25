import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/usecases/compute_volume.dart';

SessionSet _set(
  String exerciseId,
  int n,
  double? kg,
  int? reps, {
  bool done = true,
}) => SessionSet(
  id: '$exerciseId-$n',
  sessionId: 's',
  exerciseId: exerciseId,
  setNumber: n,
  weightKg: kg,
  reps: reps,
  completed: done,
);

void main() {
  const compute = ComputeVolume();

  test('soma peso × reps só das séries concluídas', () {
    final v = compute.ofSets([
      _set('a', 1, 60, 10),
      _set('a', 2, 62.5, 8),
      _set('a', 3, 100, 10, done: false),
    ]);
    expect(v, 600 + 500);
  });

  test('séries sem peso ou reps contam zero', () {
    expect(compute.ofSets([_set('a', 1, null, 10), _set('a', 2, 50, null)]), 0);
    expect(compute.ofSets(const []), 0);
  });

  test('volume por exercício e total do treino', () {
    final v = compute([
      SessionExercise(
        exerciseId: 'agacho',
        exerciseName: 'Agachamento',
        sets: [_set('agacho', 1, 100, 5), _set('agacho', 2, 100, 5)],
      ),
      SessionExercise(
        exerciseId: 'supino',
        exerciseName: 'Supino',
        sets: [_set('supino', 1, 62.5, 8)],
      ),
      SessionExercise(
        exerciseId: 'remada',
        exerciseName: 'Remada',
        sets: [_set('remada', 1, 40, 12, done: false)],
      ),
    ]);
    expect(v.of('agacho'), 1000);
    expect(v.of('supino'), 500);
    expect(v.of('remada'), 0);
    expect(v.of('inexistente'), 0);
    expect(v.total, 1500);
  });

  test('arredonda para 2 casas (DECIMAL(10,2) no Supabase)', () {
    expect(compute.ofSets([_set('a', 1, 33.333, 3)]), 100);
    expect(ComputeVolume.round(0.1 + 0.2), 0.3);
  });
}
