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

    test(
      'pagina com offset e limit mantendo ordem estável sem lacunas',
      () async {
        final names = List.generate(
          65,
          (i) => 'Exercicio ${i.toString().padLeft(2, '0')}',
        ).reversed.toList();
        await dataSource.insertExercises(buildCompanions(names));

        final page1 = await dataSource.searchByName('', limit: 30, offset: 0);
        final page2 = await dataSource.searchByName('', limit: 30, offset: 30);
        final page3 = await dataSource.searchByName('', limit: 30, offset: 60);
        final beyondEnd = await dataSource.searchByName(
          '',
          limit: 30,
          offset: 65,
        );
        final negativeOffset = await dataSource.searchByName(
          '',
          limit: 5,
          offset: -10,
        );

        expect(page1, hasLength(30));
        expect(page2, hasLength(30));
        expect(page3, hasLength(5));
        expect(beyondEnd, isEmpty);
        expect(negativeOffset, page1.take(5).toList());

        final allPaged = [...page1, ...page2, ...page3];
        expect(allPaged, hasLength(65));
        expect(allPaged.map((e) => e.id).toSet(), hasLength(65));
        expect(allPaged.first.name, 'Exercicio 00');
        expect(allPaged.last.name, 'Exercicio 64');
      },
    );

    test('desempata por id quando há nomes duplicados evitando repetição ou lacuna', () async {
      final now = DateTime(2026, 9, 16);
      await dataSource.insertExercises([
        ExerciseLibraryTableCompanion.insert(
          id: 'id-d',
          externalId: 'ext-d',
          name: 'Supino',
          updatedAt: now,
        ),
        ExerciseLibraryTableCompanion.insert(
          id: 'id-b',
          externalId: 'ext-b',
          name: 'Supino',
          updatedAt: now,
        ),
        ExerciseLibraryTableCompanion.insert(
          id: 'id-a',
          externalId: 'ext-a',
          name: 'Supino',
          updatedAt: now,
        ),
        ExerciseLibraryTableCompanion.insert(
          id: 'id-e',
          externalId: 'ext-e',
          name: 'Supino',
          updatedAt: now,
        ),
        ExerciseLibraryTableCompanion.insert(
          id: 'id-c',
          externalId: 'ext-c',
          name: 'Supino',
          updatedAt: now,
        ),
      ]);

      final page1 = await dataSource.searchByName('', limit: 2, offset: 0);
      final page2 = await dataSource.searchByName('', limit: 2, offset: 2);
      final page3 = await dataSource.searchByName('', limit: 2, offset: 4);

      expect(page1.map((e) => e.id), ['id-a', 'id-b']);
      expect(page2.map((e) => e.id), ['id-c', 'id-d']);
      expect(page3.map((e) => e.id), ['id-e']);
    });

    test(
      'combina query com offset e suporta estratégia limit + 1 para hasMore',
      () async {
        final companions = [
          ...buildCompanions(
            List.generate(35, (i) => 'Supino ${i.toString().padLeft(2, '0')}'),
          ),
          for (var i = 0; i < 20; i++)
            ExerciseLibraryTableCompanion.insert(
              id: 'ag-$i',
              externalId: 'ext-ag-$i',
              name: 'Agachamento ${i.toString().padLeft(2, '0')}',
              updatedAt: DateTime(2026, 9, 16),
            ),
        ];
        await dataSource.insertExercises(companions);

        // Pede pageSize + 1 (21) para detectar se há próxima página.
        final firstProbe = await dataSource.searchByName(
          'supino',
          limit: 21,
          offset: 0,
        );
        expect(firstProbe, hasLength(21));
        final firstPage = firstProbe.take(20).toList();
        expect(firstPage.first.name, 'Supino 00');
        expect(firstPage.last.name, 'Supino 19');

        final secondProbe = await dataSource.searchByName(
          'supino',
          limit: 21,
          offset: 20,
        );
        expect(secondProbe, hasLength(15));
        expect(secondProbe.first.name, 'Supino 20');
        expect(secondProbe.last.name, 'Supino 34');
      },
    );
  });
}
