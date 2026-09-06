import 'package:drift/drift.dart';

/// Plataforma sem implementação de banco (não deve ocorrer em runtime).
QueryExecutor connect() =>
    throw UnsupportedError('Sem implementação de banco para esta plataforma');
