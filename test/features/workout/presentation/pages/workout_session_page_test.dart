import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_session_repository.dart';
import 'package:olimpus/features/workout/presentation/pages/workout_session_page.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_session_providers.dart';

/// Repositório em memória que reemite a sessão a cada alteração.
class _FakeSessionRepository implements IWorkoutSessionRepository {
  _FakeSessionRepository(this.session);

  WorkoutSessionEntity session;
  final _controller = StreamController<WorkoutSessionEntity?>.broadcast();
  final updates = <SessionSet>[];
  var completed = false;

  void _emit() => _controller.add(session);

  @override
  Stream<WorkoutSessionEntity?> watchSession(String sessionId) async* {
    yield session;
    yield* _controller.stream;
  }

  @override
  Future<void> updateSet(SessionSet set) async {
    updates.add(set);
    session = WorkoutSessionEntity(
      id: session.id,
      userId: session.userId,
      templateName: session.templateName,
      startedAt: session.startedAt,
      exercises: [
        for (final e in session.exercises)
          SessionExercise(
            exerciseId: e.exerciseId,
            exerciseName: e.exerciseName,
            previousSets: e.previousSets,
            sets: [for (final s in e.sets) s.id == set.id ? set : s],
          ),
      ],
    );
    _emit();
  }

  @override
  Future<void> addSet({
    required String sessionId,
    required String exerciseId,
  }) async {}

  @override
  Future<void> completeSession(String sessionId) async => completed = true;

  @override
  Future<String> startSession({
    required String userId,
    required WorkoutTemplateEntity template,
  }) async => session.id;
}

void main() {
  late _FakeSessionRepository repo;

  setUp(() {
    repo = _FakeSessionRepository(
      WorkoutSessionEntity(
        id: 's1',
        userId: 'u1',
        templateName: 'Treino A',
        startedAt: DateTime(2026, 11, 25),
        exercises: const [
          SessionExercise(
            exerciseId: 'bench',
            exerciseName: 'Supino reto',
            previousSets: [
              SessionSet(
                id: 'p1',
                sessionId: 's0',
                exerciseId: 'bench',
                setNumber: 1,
                weightKg: 60,
                reps: 10,
                completed: true,
              ),
            ],
            sets: [
              SessionSet(
                id: 'a',
                sessionId: 's1',
                exerciseId: 'bench',
                setNumber: 1,
                weightKg: 60,
                reps: 10,
              ),
              SessionSet(
                id: 'b',
                sessionId: 's1',
                exerciseId: 'bench',
                setNumber: 2,
                weightKg: 60,
                reps: 10,
              ),
            ],
          ),
        ],
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workoutSessionRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: WorkoutSessionPage(sessionId: 's1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra carga anterior lado a lado e progresso', (tester) async {
    await pump(tester);

    expect(find.text('Treino A'), findsOneWidget);
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Última sessão: 60kg×10'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('previous-a'))).data,
      '60×10',
    );
    // Série 2 não existia na última sessão.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('previous-b'))).data,
      '—',
    );
    expect(find.text('0/2 séries'), findsOneWidget);
  });

  testWidgets('ajuste rápido +/- de peso e reps e conclusão da série', (
    tester,
  ) async {
    await pump(tester);

    final weight = find.byKey(const ValueKey('weight-a'));
    await tester.tap(
      find.descendant(of: weight, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
    expect(repo.updates.last.weightKg, 62.5);
    // Toques rápidos acumulam a partir do valor otimista.
    await tester.tap(
      find.descendant(of: weight, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
    expect(repo.updates.last.weightKg, 65);

    final reps = find.byKey(const ValueKey('reps-a'));
    await tester.tap(
      find.descendant(of: reps, matching: find.byIcon(Icons.remove)),
    );
    await tester.pumpAndSettle();
    expect(repo.updates.last.reps, 9);

    await tester.tap(find.byKey(const ValueKey('done-a')));
    await tester.pumpAndSettle();
    expect(repo.updates.last.completed, isTrue);
    expect(repo.updates.last.weightKg, 65);
    expect(find.text('1/2 séries'), findsOneWidget);
  });

  testWidgets('editar peso digitando o valor', (tester) async {
    await pump(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('weight-b')),
        matching: find.text('60'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '72,5');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.updates.last.weightKg, 72.5);
  });

  testWidgets('concluir treino pede confirmação e conclui a sessão', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workoutSessionRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutSessionPage(sessionId: 's1'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('finish-session')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 série(s) não concluída(s)'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(repo.completed, isTrue);
    // Volta para a tela anterior após concluir.
    expect(find.byType(WorkoutSessionPage), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
