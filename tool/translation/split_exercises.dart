// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const int _chunkSize = 30;
const String _sourcePath = 'assets/data/exercises.json';
const String _chunksDir = 'tool/translation/chunks';

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Arquivo não encontrado: $_sourcePath');
    exit(1);
  }

  final decoded = jsonDecode(sourceFile.readAsStringSync()) as List<dynamic>;
  final outDir = Directory(_chunksDir);
  if (outDir.existsSync()) {
    for (final entity in outDir.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        entity.deleteSync();
      }
    }
  } else {
    outDir.createSync(recursive: true);
  }

  final encoder = const JsonEncoder.withIndent('  ');
  var chunkIndex = 1;

  for (var i = 0; i < decoded.length; i += _chunkSize) {
    final end = (i + _chunkSize).clamp(0, decoded.length);
    final chunkItems = <Map<String, dynamic>>[];

    for (var j = i; j < end; j++) {
      final raw = decoded[j] as Map<String, dynamic>;
      chunkItems.add({
        'id': raw['id'] as String,
        'name': raw['name'] as String,
        'instructions': (raw['instructions'] as List<dynamic>).cast<String>(),
      });
    }

    final fileName = 'chunk_${chunkIndex.toString().padLeft(3, '0')}.json';
    final outFile = File('$_chunksDir/$fileName');
    outFile.writeAsStringSync('${encoder.convert(chunkItems)}\n', encoding: utf8);
    chunkIndex++;
  }

  print(
    'Gerados ${chunkIndex - 1} lotes em $_chunksDir '
    '(${decoded.length} exercícios, até $_chunkSize por lote).',
  );
}
