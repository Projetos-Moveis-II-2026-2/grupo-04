// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'supabase_migration_builder.dart';

const String sourcePath = 'assets/data/exercises_pt.json';

const String _generatedBy = 'tool/translation/generate_supabase_migration.dart';

void main() {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Arquivo não encontrado: $sourcePath');
    exitCode = 1;
    return;
  }

  final Map<String, dynamic> catalog;
  try {
    var content = utf8.decode(sourceFile.readAsBytesSync());
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      stderr.writeln('$sourcePath: esperado um objeto JSON na raiz.');
      exitCode = 1;
      return;
    }
    catalog = decoded;
  } on FormatException catch (error) {
    stderr.writeln('$sourcePath inválido: ${error.message}');
    exitCode = 1;
    return;
  }

  final String sql;
  try {
    sql = buildMigrationSql(catalog);
  } on CatalogValidationException catch (error) {
    stderr.writeln('Falha na validação de $sourcePath:');
    for (final message in error.errors) {
      stderr.writeln(' - $message');
    }
    exitCode = 1;
    return;
  }

  final outputFile = File(migrationPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(sql, encoding: utf8, flush: true);

  print(
    'Migration gerada por $_generatedBy: ${catalog.length} exercícios em '
    '$migrationPath.',
  );
}
