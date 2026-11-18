import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_local_datasource.dart';
import 'package:olimpus/features/exercise/data/datasources/substitute_datasource.dart';
import 'package:olimpus/features/exercise/presentation/providers/substitution_provider.dart';
import 'package:olimpus/features/exercise/presentation/widgets/substitution_sheet.dart';

class _MockSubstituteDatasource extends Mock implements SubstituteDatasource {}

void main() {
  late AppDatabase db;
  late _MockSubstituteDatasource mockDatasource;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    mockDatasource = _MockSubstituteDatasource();

    await ExerciseLocalDataSource(db).insertExercises([
      ExerciseLibraryTableCompanion.insert(
        id: 'Dumbbell_Bench_Press',
        externalId: 'Dumbbell_Bench_Press',
        name: 'Supino Reto com Halteres',
        updatedAt: DateTime(2026, 9, 16),
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'substitutesProvider resolve nome em pt-BR via external_id e mantém fallback',
    () async {
      when(() => mockDatasource.getSubstitutes('ex-uuid-1')).thenAnswer(
        (_) async => const [
          SubstituteSuggestion(
            id: 'supabase-uuid-123',
            externalId: 'Dumbbell_Bench_Press',
            name: 'Dumbbell Bench Press',
            equipment: 'dumbbell',
            imageUrl: null,
          ),
          SubstituteSuggestion(
            id: 'supabase-uuid-999',
            externalId: 'Unknown_Exercise',
            name: 'Unknown Exercise',
            equipment: 'cable',
            imageUrl: null,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          substituteDatasourceProvider.overrideWithValue(mockDatasource),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        substitutesProvider('ex-uuid-1').future,
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'Supino Reto com Halteres');
      expect(result[1].name, 'Unknown Exercise');
    },
  );

  testWidgets(
    'showSubstitutionSheet exibe equipamento e nome traduzidos em pt-BR',
    (tester) async {
      when(() => mockDatasource.getSubstitutes('ex-uuid-1')).thenAnswer(
        (_) async => const [
          SubstituteSuggestion(
            id: 'supabase-uuid-123',
            externalId: 'Dumbbell_Bench_Press',
            name: 'Dumbbell Bench Press',
            equipment: 'dumbbell',
            imageUrl: null,
            reason: 'Alternativa equivalente para peitoral.',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            substituteDatasourceProvider.overrideWithValue(mockDatasource),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        showSubstitutionSheet(context, ref, 'ex-uuid-1'),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Supino Reto com Halteres'), findsOneWidget);
      expect(find.text('Halter'), findsOneWidget);
      expect(find.text('Dumbbell Bench Press'), findsNothing);
      expect(find.text('dumbbell'), findsNothing);
    },
  );
}
