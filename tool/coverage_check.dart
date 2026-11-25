import 'dart:io';

/// Percentual mínimo de cobertura de linhas exigido para a camada de domínio.
const double _minimumCoverage = 60;

/// Caminho padrão do relatório gerado por `flutter test --coverage`.
const String _defaultLcovPath = 'coverage/lcov.info';

void main(List<String> args) {
  final lcovFile = File(args.isEmpty ? _defaultLcovPath : args.first);

  if (!lcovFile.existsSync()) {
    stderr
      ..writeln('Arquivo de cobertura não encontrado: ${lcovFile.path}')
      ..writeln('Rode "flutter test --coverage" antes de verificar.');
    exitCode = 1;
    return;
  }

  final records = _parseLcov(lcovFile.readAsLinesSync());
  final domainRecords =
      records.entries.where((entry) => _isDomainFile(entry.key)).toList()
        ..sort((a, b) => a.key.compareTo(b.key));

  if (domainRecords.isEmpty) {
    stderr.writeln(
      'Nenhum arquivo de lib/features/*/domain/ encontrado em ${lcovFile.path}.',
    );
    exitCode = 1;
    return;
  }

  var totalFound = 0;
  var totalHit = 0;

  stdout.writeln('Cobertura de domínio (lib/features/*/domain/):');
  for (final entry in domainRecords) {
    final found = entry.value.linesFound;
    final hit = entry.value.linesHit;
    if (found == 0) {
      stdout.writeln(
        '    n/a  ${_relativePath(entry.key)} (sem linhas executáveis)',
      );
      continue;
    }
    totalFound += found;
    totalHit += hit;
    final percent = hit / found * 100;
    stdout.writeln(
      '${percent.toStringAsFixed(1).padLeft(7)}%  '
      '${_relativePath(entry.key)} ($hit/$found)',
    );
  }

  if (totalFound == 0) {
    stderr.writeln(
      'Nenhuma linha executável de domínio encontrada em ${lcovFile.path}.',
    );
    exitCode = 1;
    return;
  }

  final totalPercent = totalHit / totalFound * 100;
  stdout
    ..writeln('')
    ..writeln(
      'Total: ${totalPercent.toStringAsFixed(1)}% '
      '($totalHit/$totalFound) — mínimo ${_minimumCoverage.toStringAsFixed(1)}%',
    );

  if (totalPercent < _minimumCoverage) {
    stderr.writeln(
      'Cobertura de domínio abaixo do mínimo: '
      '${totalPercent.toStringAsFixed(1)}% < '
      '${_minimumCoverage.toStringAsFixed(1)}%.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('Cobertura de domínio OK.');
}

final RegExp _domainPathPattern = RegExp(
  r'^lib/features/[^/]+/domain/.+\.dart$',
);

bool _isDomainFile(String path) => _domainPathPattern.hasMatch(path);

String _relativePath(String path) => path.replaceFirst('lib/features/', '');

Map<String, _LcovRecord> _parseLcov(List<String> lines) {
  final records = <String, _LcovRecord>{};
  String? currentPath;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentPath = line.substring(3).replaceAll(r'\', '/');
      records.putIfAbsent(currentPath, () => _LcovRecord());
      continue;
    }

    final path = currentPath;
    if (path == null) continue;

    if (line.startsWith('LF:')) {
      records[path]!.linesFound += _parseInt(line.substring(3));
    } else if (line.startsWith('LH:')) {
      records[path]!.linesHit += _parseInt(line.substring(3));
    } else if (line == 'end_of_record') {
      currentPath = null;
    }
  }

  return records;
}

int _parseInt(String value) => int.tryParse(value.trim()) ?? 0;

class _LcovRecord {
  int linesFound = 0;
  int linesHit = 0;
}
