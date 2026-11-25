import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/translation/supabase_migration_builder.dart';

void main() {
  group('buildMigrationSql', () {
    test('gera o SQL com os 876 ids do catálogo', () {
      final catalog = jsonDecode(
        utf8.decode(File('assets/data/exercises_pt.json').readAsBytesSync()),
      ) as Map<String, dynamic>;

      final sql = buildMigrationSql(catalog);

      expect(catalog, hasLength(expectedExerciseCount));
      for (final id in catalog.keys) {
        expect(sql, contains(jsonEncode(id)));
      }
    });

    test('abre e fecha o dollar-quote \$pt\$ exatamente uma vez', () {
      final catalog = jsonDecode(
        utf8.decode(File('assets/data/exercises_pt.json').readAsBytesSync()),
      ) as Map<String, dynamic>;

      final sql = buildMigrationSql(catalog);

      expect(ptDollarTag.allMatches(sql), hasLength(2));
    });

    test('falha com nome vazio', () {
      final catalog = <String, dynamic>{
        for (var i = 0; i < expectedExerciseCount; i++)
          'id_$i': {
            'name': 'Exercício $i',
            'instructions': ['Passo 1'],
          },
      };
      catalog['id_0'] = {
        'name': '   ',
        'instructions': ['Passo 1'],
      };

      expect(
        () => buildMigrationSql(catalog),
        throwsA(
          isA<CatalogValidationException>().having(
            (error) => error.errors.join('\n'),
            'erros',
            contains('id_0'),
          ),
        ),
      );
    });

    test('rejeita delimitadores SQL dentro do catálogo', () {
      final catalog = jsonDecode(
        File('assets/data/exercises_pt.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final entry = catalog.values.first as Map<String, dynamic>;
      for (final tag in [ptDollarTag, r'$do$']) {
        entry['name'] = 'Exercício $tag';
        expect(
          () => buildMigrationSql(catalog),
          throwsA(isA<CatalogValidationException>()),
        );
      }
    });
  });
}
