// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/data/exercises.json';
const String _outDir = 'tool/translation/out';
const String _targetPath = 'assets/data/exercises_pt.json';

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Arquivo original não encontrado: $_sourcePath');
    exit(1);
  }

  final outDirectory = Directory(_outDir);
  if (!outDirectory.existsSync()) {
    stderr.writeln('Diretório de lotes traduzidos não encontrado: $_outDir');
    exit(1);
  }

  final originalList = jsonDecode(sourceFile.readAsStringSync()) as List<dynamic>;
  final originalById = <String, Map<String, dynamic>>{};
  for (final item in originalList) {
    final map = item as Map<String, dynamic>;
    originalById[map['id'] as String] = map;
  }

  final chunkFiles =
      outDirectory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (chunkFiles.isEmpty) {
    stderr.writeln('Nenhum arquivo .json encontrado em $_outDir');
    exit(1);
  }

  final translatedById = <String, Map<String, dynamic>>{};
  final errors = <String>[];

  for (final file in chunkFiles) {
    final dynamic parsed = jsonDecode(file.readAsStringSync(encoding: utf8));
    if (parsed is! List<dynamic>) {
      errors.add('${file.path}: esperado array JSON na raiz.');
      continue;
    }

    for (final entry in parsed) {
      if (entry is! Map<String, dynamic>) {
        errors.add('${file.path}: item não é objeto JSON.');
        continue;
      }

      final id = entry['id'];
      if (id is! String || id.trim().isEmpty) {
        errors.add('${file.path}: item sem campo "id" válido.');
        continue;
      }

      final original = originalById[id];
      if (original == null) {
        errors.add('${file.path}: id "$id" não existe em $_sourcePath.');
        continue;
      }

      if (translatedById.containsKey(id)) {
        errors.add('${file.path}: id duplicado "$id".');
        continue;
      }

      final name = entry['name'];
      if (name is! String || name.trim().isEmpty) {
        errors.add('$id: campo "name" vazio ou inválido.');
        continue;
      }

      final instructions = entry['instructions'];
      final originalInstructions = original['instructions'] as List<dynamic>;
      if (instructions is! List<dynamic>) {
        errors.add('$id: campo "instructions" não é lista.');
        continue;
      }

      if (instructions.length != originalInstructions.length) {
        errors.add(
          '$id: quantidade de instruções divergente '
          '(esperado ${originalInstructions.length}, obtido ${instructions.length}).',
        );
        continue;
      }

      final cleanInstructions = <String>[];
      var hasEmptyInstruction = false;
      for (var i = 0; i < instructions.length; i++) {
        final step = instructions[i];
        if (step is! String || step.trim().isEmpty) {
          errors.add('$id: instrução [$i] vazia ou inválida.');
          hasEmptyInstruction = true;
          break;
        }
        cleanInstructions.add(step);
      }
      if (hasEmptyInstruction) continue;

      translatedById[id] = {
        'name': name,
        'instructions': cleanInstructions,
      };
    }
  }

  final missingIds = originalById.keys
      .where((id) => !translatedById.containsKey(id))
      .toList()
    ..sort();
  if (missingIds.isNotEmpty) {
    errors.add(
      'Faltam ${missingIds.length} exercício(s) traduzido(s): '
      '${missingIds.take(10).join(', ')}'
      '${missingIds.length > 10 ? ' ...' : ''}',
    );
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Falha na validação do merge (${errors.length} erro(s)):');
    for (final error in errors) {
      stderr.writeln(' - $error');
    }
    exit(1);
  }

  final sortedIds = translatedById.keys.toList()..sort();
  final output = <String, Map<String, dynamic>>{
    for (final id in sortedIds) id: translatedById[id]!,
  };

  final encoder = const JsonEncoder.withIndent('  ');
  final targetFile = File(_targetPath);
  targetFile.writeAsStringSync('${encoder.convert(output)}\n', encoding: utf8);

  print(
    'Merge concluído com sucesso: ${output.length} exercícios salvos em $_targetPath.',
  );
}
