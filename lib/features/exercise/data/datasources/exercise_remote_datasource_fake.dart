import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/exercise.dart';

const _defaultChunkSize = 100;

/// Faz o decode e mapeamento do JSON do catálogo em uma única passada.
///
/// Função top-level para execução em isolate separada via [compute].
List<Exercise> parseExercisesFromJson(String jsonString) {
  final now = DateTime.now();
  final decoded = jsonDecode(jsonString) as List<dynamic>;
  return decoded
      .map((item) => _mapExerciseJson(item as Map<String, dynamic>, now))
      .toList(growable: false);
}

/// Faz o decode e mapeamento do JSON em lotes, cedendo o event loop entre eles.
///
/// Usado na web, onde [compute] executa na thread principal, e também
/// reutilizável para validar processamento incremental em testes.
Future<List<Exercise>> parseExercisesInChunks(
  String jsonString, {
  int chunkSize = _defaultChunkSize,
  DateTime? updatedAt,
  Future<void> Function()? onChunkProcessed,
}) async {
  final now = updatedAt ?? DateTime.now();
  final decoded = jsonDecode(jsonString) as List<dynamic>;
  if (decoded.isEmpty) return const [];

  final effectiveChunkSize = chunkSize <= 0 ? _defaultChunkSize : chunkSize;
  final result = <Exercise>[];

  for (var i = 0; i < decoded.length; i += effectiveChunkSize) {
    final end = (i + effectiveChunkSize).clamp(0, decoded.length);
    for (var j = i; j < end; j++) {
      result.add(_mapExerciseJson(decoded[j] as Map<String, dynamic>, now));
    }
    if (end < decoded.length) {
      await (onChunkProcessed?.call() ?? Future<void>.delayed(Duration.zero));
    }
  }

  return result;
}

Exercise _mapExerciseJson(Map<String, dynamic> json, DateTime now) {
  final id =
      json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
  final name = json['name'] as String? ?? 'Exercício sem nome';
  final force = json['force'] as String?;
  final level = json['level'] as String?;
  final mechanic = json['mechanic'] as String?;
  final equipment = json['equipment'] as String?;

  final primaryMusclesList = json['primaryMuscles'] as List<dynamic>? ?? [];
  final primaryMuscles = primaryMusclesList.join(', ');

  final secondaryMusclesList = json['secondaryMuscles'] as List<dynamic>? ?? [];
  final secondaryMuscles = secondaryMusclesList.join(', ');

  final instructionsList = json['instructions'] as List<dynamic>? ?? [];
  final instructions = instructionsList.map((e) => '• $e').join('\n');

  final category = json['category'] as String?;

  final imagesList = json['images'] as List<dynamic>? ?? [];
  final imageUrls = imagesList
      .map(
        (img) =>
            'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$img',
      )
      .join(',');

  return Exercise(
    id: id,
    externalId: id, // ID original do Free-Exercise-DB
    name: name,
    force: force,
    level: level,
    mechanic: mechanic,
    equipment: equipment,
    primaryMuscles: primaryMuscles,
    secondaryMuscles: secondaryMuscles,
    instructions: instructions,
    category: category,
    imageUrls: imageUrls,
    synced: true,
    updatedAt: now,
  );
}

class ExerciseRemoteDataSourceFake {
  Future<List<Exercise>> fetchExercises() async {
    try {
      // rootBundle deve permanecer na isolate principal; apenas o parse/map sai da UI.
      final jsonString = await rootBundle.loadString(
        'assets/data/exercises.json',
      );
      if (kIsWeb) {
        return await parseExercisesInChunks(jsonString);
      }
      return await compute(parseExercisesFromJson, jsonString);
    } catch (e) {
      debugPrint('Erro ao carregar o JSON local: $e');
      return [];
    }
  }
}
