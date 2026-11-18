import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/data/datasources/exercise_remote_datasource_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String buildSampleJson(int count) {
    final items = List.generate(
      count,
      (i) => {
        'id': 'ex-$i',
        'name': 'Exercicio $i',
        'force': 'push',
        'level': 'beginner',
        'mechanic': 'compound',
        'equipment': 'barbell',
        'primaryMuscles': ['chest', 'triceps'],
        'secondaryMuscles': ['shoulders'],
        'instructions': ['Passo 1', 'Passo 2'],
        'category': 'strength',
        'images': ['Ex_$i/0.jpg'],
      },
    );
    return jsonEncode(items);
  }

  group('parseExercisesFromJson', () {
    test('mapeia corretamente campos completos e valores padrão', () {
      final json = jsonEncode([
        {
          'id': 'bench-press',
          'name': 'Bench Press',
          'force': 'push',
          'level': 'intermediate',
          'mechanic': 'compound',
          'equipment': 'barbell',
          'primaryMuscles': ['chest'],
          'secondaryMuscles': ['shoulders', 'triceps'],
          'instructions': ['Deite no banco', 'Empurre a barra'],
          'category': 'strength',
          'images': ['Bench_Press/0.jpg'],
        },
        {'id': 'minimal'},
      ]);

      final result = parseExercisesFromJson(json);

      expect(result, hasLength(2));
      expect(result.first.id, 'bench-press');
      expect(result.first.externalId, 'bench-press');
      expect(result.first.name, 'Bench Press');
      expect(result.first.primaryMuscles, 'chest');
      expect(result.first.secondaryMuscles, 'shoulders, triceps');
      expect(result.first.instructions, '• Deite no banco\n• Empurre a barra');
      expect(
        result.first.imageUrls,
        'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Press/0.jpg',
      );
      expect(result.first.synced, isTrue);

      expect(result.last.id, 'minimal');
      expect(result.last.name, 'Exercício sem nome');
    });

    test('processa o catálogo completo real de 876 exercícios', () async {
      final raw = await rootBundle.loadString('assets/data/exercises.json');
      final exercises = parseExercisesFromJson(raw);

      expect(exercises, hasLength(876));
      expect(exercises.first.name, isNotEmpty);
    });
  });

  group('parseExercisesInChunks', () {
    test(
      'processa em lotes cedendo entre chunks e mantém equivalência',
      () async {
        final json = buildSampleJson(250);
        final fixedTime = DateTime(2026, 9, 16);
        var yieldCount = 0;

        final chunked = await parseExercisesInChunks(
          json,
          chunkSize: 100,
          updatedAt: fixedTime,
          onChunkProcessed: () async {
            yieldCount++;
          },
        );

        expect(chunked, hasLength(250));
        expect(yieldCount, 2); // 0..99, 100..199, 200..249 -> 2 yields
        expect(chunked.first.id, 'ex-0');
        expect(chunked.last.id, 'ex-249');
        expect(chunked.every((e) => e.updatedAt == fixedTime), isTrue);
      },
    );

    test('retorna vazio para JSON de lista vazia sem ceder frame', () async {
      var yieldCount = 0;
      final result = await parseExercisesInChunks(
        '[]',
        onChunkProcessed: () async {
          yieldCount++;
        },
      );

      expect(result, isEmpty);
      expect(yieldCount, 0);
    });
  });
}
