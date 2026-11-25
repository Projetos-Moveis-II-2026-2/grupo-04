import 'dart:convert';

/// Quantidade de exercícios esperada em `assets/data/exercises_pt.json`.
///
/// A migration `20260906231952_seed_exercises.sql` insere exatamente 876
/// linhas em `public.exercise_library`, então qualquer divergência aqui
/// indica catálogo incompleto.
const int expectedExerciseCount = 876;

/// Delimitador dollar-quoted usado para embutir o JSON no SQL.
///
/// O payload não pode conter esta sequência, senão o PostgreSQL encerraria
/// o literal antes da hora.
const String ptDollarTag = r'$pt$';
const String _blockDollarTag = r'$do$';

/// Caminho fixo da migration gerada. Re-rodar o gerador deve produzir
/// exatamente o mesmo arquivo.
const String migrationPath =
    'supabase/migrations/20261125000000_exercise_library_pt_br.sql';

/// Erro de validação do catálogo traduzido.
class CatalogValidationException implements Exception {
  CatalogValidationException(this.errors);

  /// Lista de problemas encontrados, um por linha.
  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}

/// Valida o catálogo e devolve o SQL da migration que leva a tradução
/// pt-BR para `public.exercise_library`.
///
/// O mapa esperado é `id -> {name: String, instructions: List<String>}`.
/// Lança [CatalogValidationException] se o catálogo estiver inválido.
String buildMigrationSql(Map<String, dynamic> catalog) {
  final errors = <String>[];

  if (catalog.length != expectedExerciseCount) {
    errors.add(
      'esperado $expectedExerciseCount exercícios, encontrado '
      '${catalog.length}.',
    );
  }

  final sortedIds = catalog.keys.toList()..sort();
  final normalized = <String, Map<String, dynamic>>{};

  for (final id in sortedIds) {
    final entry = catalog[id];
    if (entry is! Map) {
      errors.add('$id: entrada não é um objeto JSON.');
      continue;
    }

    final name = entry['name'];
    if (name is! String || name.trim().isEmpty) {
      errors.add('$id: campo "name" vazio ou inválido.');
      continue;
    }

    final instructions = entry['instructions'];
    if (instructions is! List) {
      errors.add('$id: campo "instructions" não é uma lista.');
      continue;
    }

    final steps = <String>[];
    var invalid = false;
    for (var i = 0; i < instructions.length; i++) {
      final step = instructions[i];
      if (step is! String || step.trim().isEmpty) {
        errors.add('$id: instrução [$i] vazia ou inválida.');
        invalid = true;
        break;
      }
      steps.add(step);
    }
    if (invalid) continue;

    normalized[id] = {'name': name, 'instructions': steps};
  }

  if (errors.isNotEmpty) {
    throw CatalogValidationException(errors);
  }

  final json = _encodeCatalog(normalized);
  for (final tag in [ptDollarTag, _blockDollarTag]) {
    if (json.contains(tag)) {
      throw CatalogValidationException([
        'o JSON serializado contém a sequência $tag, que encerraria '
            'um bloco dollar-quoted do SQL.',
      ]);
    }
  }

  return _buildSql(json);
}

/// Serializa o catálogo com chaves ordenadas e um exercício por linha,
/// mantendo os acentos sem escape (`ensureAscii` equivalente desligado).
String _encodeCatalog(Map<String, Map<String, dynamic>> catalog) {
  final buffer = StringBuffer('{\n');
  var first = true;
  for (final entry in catalog.entries) {
    if (!first) buffer.write(',\n');
    buffer
      ..write(jsonEncode(entry.key))
      ..write(':')
      ..write(jsonEncode(entry.value));
    first = false;
  }
  buffer.write('\n}');
  return buffer.toString();
}

String _buildSql(String json) {
  return '''
-- Migration gerada por tool/translation/generate_supabase_migration.dart (#124) — não editar à mão.
-- Fonte: assets/data/exercises_pt.json ($expectedExerciseCount exercícios em pt-BR).
-- O original em inglês fica guardado em name_en/instructions_en para o casamento do LLM e rollback.
--
-- Ordem de execução: as migrations rodam antes do seed do Supabase CLI
-- (config.toml [db.seed] aponta para ./seed.sql, que não existe neste projeto).
-- A contagem de $expectedExerciseCount linhas vale porque a migration
-- 20260906231952_seed_exercises.sql já inseriu os 876 exercícios antes desta.
DO $_blockDollarTag
DECLARE
  n INTEGER;
BEGIN
  ALTER TABLE public.exercise_library
    ADD COLUMN IF NOT EXISTS name_en TEXT,
    ADD COLUMN IF NOT EXISTS instructions_en TEXT[];

  UPDATE public.exercise_library
  SET name_en = replace(replace(name, chr(157), ''), chr(13), ''),
      instructions_en = ARRAY(
        SELECT replace(replace(x, chr(157), ''), chr(13), '')
        FROM unnest(instructions) WITH ORDINALITY AS u(x, n)
        ORDER BY n
      )
  WHERE name_en IS NULL;

  UPDATE public.exercise_library AS e
  SET name = t.value->>'name',
      instructions = ARRAY(
        SELECT y
        FROM jsonb_array_elements_text(t.value->'instructions')
             WITH ORDINALITY AS j(y, i)
        ORDER BY i
      )
  FROM jsonb_each($ptDollarTag
$json
$ptDollarTag::jsonb) AS t
  WHERE e.external_id = t.key;

  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> $expectedExerciseCount THEN
    RAISE EXCEPTION 'exercise_library pt-BR: esperado $expectedExerciseCount linhas, atualizadas %', n;
  END IF;
  COMMENT ON COLUMN public.exercise_library.name_en IS
    'Nome original em inglês (free-exercise-db), preservado após a tradução do catálogo para pt-BR (#124).';
  COMMENT ON COLUMN public.exercise_library.instructions_en IS
    'Instruções originais em inglês (free-exercise-db), preservadas após a tradução do catálogo para pt-BR (#124).';

  NOTIFY pgrst, 'reload schema';
END
$_blockDollarTag;
''';
}
