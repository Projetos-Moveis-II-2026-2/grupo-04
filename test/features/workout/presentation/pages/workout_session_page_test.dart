import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/domain/repositories/i_workout_session_repository.dart';
import 'package:olimpus/features/workout/presentation/pages/workout_session_page.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_session_providers.dart';
import 'package:olimpus/core/notifications/local_notification_service.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/workout/presentation/providers/rest_timer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Registra as chamadas de notificação (som) sem tocar no plugin.
class _FakeNotifications implements LocalNotificationService {
  final calls = <String>[];

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required AlertChannel channel,
  }) async => calls.add('show:$title');

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required AlertChannel channel,
  }) async => calls.add('schedule');

  @override
  Future<void> cancel(int id) async => calls.add('cancel');
}

/// Relógio controlado pelo teste (avança junto com `tester.pump`).
class _Clock {
  DateTime now = DateTime(2026, 11, 25, 10);
}

void main() {
  late _FakeSessionRepository repo;
  late SharedPreferences prefs;
  late _FakeNotifications notifications;
  late _Clock clock;

  List<Override> overrides() => [
    workoutSessionRepositoryProvider.overrideWithValue(repo),
    sharedPreferencesProvider.overrideWithValue(prefs),
    localNotificationServiceProvider.overrideWithValue(notifications),
    restTimerClockProvider.overrideWithValue(() => clock.now),
  ];

  /// Avança relógio e timers juntos.
  Future<void> elapse(WidgetTester tester, Duration d) async {
    for (var i = 0; i < d.inSeconds; i++) {
      clock.now = clock.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    notifications = _FakeNotifications();
    clock = _Clock();
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
        overrides: overrides(),
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

  testWidgets('volume por exercício e total atualizam em tempo real (#40)', (
    tester,
  ) async {
    String text(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    await pump(tester);
    expect(text('volume-bench'), '0 kg');
    expect(text('previous-volume-bench'), 'anterior: 600 kg');
    expect(text('session-volume'), 'Volume total: 0 kg');

    // Concluir série 1 (60×10) → 600 kg.
    await tester.tap(find.byKey(const ValueKey('done-a')));
    await tester.pumpAndSettle();
    expect(text('volume-bench'), '600 kg');
    expect(text('session-volume'), 'Volume total: 600 kg');

    // +2,5 kg na série concluída → 62,5×10 = 625 kg.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('weight-a')),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pumpAndSettle();
    expect(text('volume-bench'), '625 kg');

    // Concluir série 2 (60×10) → 1.225 kg (formato pt-BR).
    await tester.tap(find.byKey(const ValueKey('done-b')));
    await tester.pumpAndSettle();
    expect(text('session-volume'), 'Volume total: 1.225 kg');
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
        overrides: overrides(),
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

  group('cronômetro de descanso (#41)', () {
    String label(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('rest-timer-label')))
        .data!;

    testWidgets(
      'Verificação #41: concluir série → timer inicia → zerar mostra alerta',
      (tester) async {
        await prefs.setInt('rest_timer_seconds', 30);
        await pump(tester);
        expect(label(tester), 'Descanso · 0:30');

        await tester.tap(find.byKey(const ValueKey('done-a')));
        await tester.pump();
        expect(label(tester), '0:30');
        expect(notifications.calls, containsAll(['schedule', 'permission']));

        await elapse(tester, const Duration(seconds: 10));
        expect(label(tester), '0:20');

        await elapse(tester, const Duration(seconds: 20));
        // Alerta visual + sonoro (notificação imediata).
        expect(label(tester), 'Descanso concluído!');
        expect(find.byIcon(Icons.alarm_on), findsOneWidget);
        expect(notifications.calls.last, 'show:Descanso concluído');

        await tester.tap(find.byKey(const ValueKey('rest-dismiss')));
        await tester.pump();
        expect(label(tester), 'Descanso · 0:30');
      },
    );

    testWidgets('iniciar, pausar, retomar e parar manualmente', (tester) async {
      await pump(tester);
      expect(label(tester), 'Descanso · 1:30'); // padrão 90 s

      await tester.tap(find.byKey(const ValueKey('rest-start')));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 5));
      expect(label(tester), '1:25');

      await tester.tap(find.byKey(const ValueKey('rest-pause')));
      await tester.pump();
      expect(label(tester), 'Pausado · 1:25');
      expect(notifications.calls.last, 'cancel');
      // Pausado não corre.
      await elapse(tester, const Duration(seconds: 10));
      expect(label(tester), 'Pausado · 1:25');

      await tester.tap(find.byKey(const ValueKey('rest-resume')));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 5));
      expect(label(tester), '1:20');

      await tester.tap(find.byKey(const ValueKey('rest-stop')));
      await tester.pump();
      expect(label(tester), 'Descanso · 1:30');
      expect(notifications.calls.where((c) => c.startsWith('show')), isEmpty);
    });

    testWidgets('não inicia sozinho com a opção desligada', (tester) async {
      await prefs.setBool('rest_timer_auto_start', false);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('done-a')));
      await tester.pump();
      expect(label(tester), 'Descanso · 1:30');
      expect(notifications.calls, isEmpty);
    });

    testWidgets('alterar peso de série já concluída não reinicia o timer', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('done-a')));
      await tester.pump();
      await elapse(tester, const Duration(seconds: 10));

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('weight-a')),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pump();
      expect(label(tester), '1:20');
    });
  });

  test('configuração limita o tempo a 30–180 s', () async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final settings = container.read(restTimerSettingsProvider.notifier);

    await settings.setSeconds(10);
    expect(container.read(restTimerSettingsProvider).seconds, 30);
    await settings.setSeconds(500);
    expect(container.read(restTimerSettingsProvider).seconds, 180);
    await settings.setSeconds(120);
    expect(prefs.getInt('rest_timer_seconds'), 120);
  });
}
