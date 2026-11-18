import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_local_datasource.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';

void main() {
  late AppDatabase db;
  late ExerciseLocalDataSource dataSource;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dataSource = ExerciseLocalDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  List<ExerciseLibraryTableCompanion> buildCompanions(List<String> names) {
    final now = DateTime(2026, 9, 16);
    return [
      for (var i = 0; i < names.length; i++)
        ExerciseLibraryTableCompanion.insert(
          id: 'id-$i',
          externalId: 'ext-$i',
          name: names[i],
          updatedAt: now,
        ),
    ];
  }

  group('hasExercises', () {
    test(
      'retorna false quando a tabela está vazia e true após inserir',
      () async {
        expect(await dataSource.hasExercises(), isFalse);

        await dataSource.insertExercises(buildCompanions(['Supino Reto']));

        expect(await dataSource.hasExercises(), isTrue);
      },
    );
  });

  group('insertExercises em lotes', () {
    test('persiste todos os registros divididos em múltiplos lotes', () async {
      final names = List.generate(
        450,
        (i) => 'Exercicio ${i.toString().padLeft(3, '0')}',
      );

      await dataSource.insertExercises(buildCompanions(names), batchSize: 200);

      final rows = await db.select(db.exerciseLibraryTable).get();
      expect(rows, hasLength(450));
    });

    test('ignora lista vazia sem falhar', () async {
      await expectLater(dataSource.insertExercises(const []), completes);
      expect(await dataSource.hasExercises(), isFalse);
    });
  });

  group('searchByName', () {
    test('respeita o limite e ordena alfabeticamente por nome', () async {
      final names = List.generate(
        50,
        (i) => 'Exercicio ${i.toString().padLeft(2, '0')}',
      ).reversed.toList();
      await dataSource.insertExercises(buildCompanions(names));

      final firstPage = await dataSource.searchByName('', limit: 30);
      expect(firstPage, hasLength(30));
      expect(firstPage.first.name, 'Exercicio 00');
      expect(firstPage.last.name, 'Exercicio 29');

      final smallLimit = await dataSource.searchByName('', limit: 5);
      expect(smallLimit, hasLength(5));
      expect(await dataSource.searchByName('', limit: 0), isEmpty);
    });

    test(
      'filtra com LIKE case-insensitive e retorna apenas id e name',
      () async {
        await dataSource.insertExercises(
          buildCompanions([
            'Agachamento Livre',
            'Supino Inclinado',
            'Supino Reto',
            'Elevação Lateral',
            'Treino 100% Foco',
          ]),
        );

        final upper = await dataSource.searchByName('SUPINO');
        expect(upper, const [
          ExerciseOption(id: 'id-1', name: 'Supino Inclinado'),
          ExerciseOption(id: 'id-2', name: 'Supino Reto'),
        ]);

        final trimmed = await dataSource.searchByName('  reto  ');
        expect(trimmed, const [
          ExerciseOption(id: 'id-2', name: 'Supino Reto'),
        ]);

        final accented = await dataSource.searchByName('elevação');
        expect(accented, const [
          ExerciseOption(id: 'id-3', name: 'Elevação Lateral'),
        ]);

        // Caracteres especiais do LIKE devem ser tratados como literais.
        final literalPercent = await dataSource.searchByName('100%');
        expect(literalPercent, const [
          ExerciseOption(id: 'id-4', name: 'Treino 100% Foco'),
        ]);
        expect(await dataSource.searchByName('_%'), isEmpty);
      },
    );
  });
}
