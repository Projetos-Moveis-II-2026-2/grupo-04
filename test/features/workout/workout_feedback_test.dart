import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/core/providers/action_feedback_provider.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/pages/settings_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise.dart';
import 'package:olimpus/features/workout/presentation/pages/free_workout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  final effects = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    effects.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate' ||
          call.method == 'SystemSound.play') {
        effects.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('configurações persistem vibração e som de forma independente', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );

    await tester.tap(find.text('Vibração'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Som de feedback'));
    await tester.pumpAndSettle();
    effects.clear();
    await prefs.reload();

    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restored.dispose);

    expect(restored.read(actionFeedbackProvider), (
      vibration: false,
      sound: true,
    ));
    await restored.read(actionFeedbackProvider.notifier).play();
    expect(effects.map((call) => call.method), ['SystemSound.play']);
  });

  testWidgets(
    'salva série válida e dispara feedback ao concluir e iniciar timer',
    (tester) async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);
      await db
          .into(db.exerciseLibraryTable)
          .insert(
            ExerciseLibraryTableCompanion.insert(
              id: 'agachamento',
              externalId: 'agachamento',
              name: 'Agachamento',
              updatedAt: DateTime.now(),
            ),
          );

      const user = AppUser(
        id: 'usuario-1',
        email: 'teste@example.com',
        emailConfirmedAt: null,
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(user),
          ],
          child: const MaterialApp(home: FreeWorkoutPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Concluir série'));
      await tester.pumpAndSettle();
      expect(effects, isEmpty);

      await tester.tap(find.byType(DropdownMenu<Exercise>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agachamento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '12,5');
      await tester.enterText(find.byType(TextFormField).last, '10');
      effects.clear();
      await tester.tap(find.text('Concluir série'));
      await tester.pumpAndSettle();

      expect(find.text('Séries concluídas neste treino: 1'), findsOneWidget);
      expect(effects.single.arguments, 'HapticFeedbackType.mediumImpact');
      final set = await db.select(db.exerciseSets).getSingle();
      expect(set.exerciseId, 'agachamento');
      expect(set.completed, isTrue);
      expect(set.weightKg, 12.5);
      expect(set.reps, 10);

      effects.clear();
      await tester.ensureVisible(find.text('Iniciar timer'));
      await tester.tap(find.text('Iniciar timer'));
      await tester.pump();
      expect(find.text('Parar timer'), findsOneWidget);
      expect(effects.single.arguments, 'HapticFeedbackType.lightImpact');

      await tester.tap(find.text('Parar timer'));
      await tester.pump();
      expect(find.text('Iniciar timer'), findsOneWidget);

      await tester.ensureVisible(find.text('Concluir treino'));
      await tester.tap(find.text('Concluir treino'));
      await tester.pumpAndSettle();
      expect(find.text('Séries concluídas neste treino: 0'), findsOneWidget);
      expect(
        (await db.select(db.workoutSessions).getSingle()).completedAt,
        isNotNull,
      );
    },
  );
}
