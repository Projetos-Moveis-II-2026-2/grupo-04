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

    test('aplica overlay pt-BR e faz fallback ao original quando falta id', () {
      final json = jsonEncode([
        {
          'id': 'bench-press',
          'name': 'Bench Press',
          'instructions': ['Lie down', 'Press bar'],
        },
        {
          'id': 'squat',
          'name': 'Barbell Squat',
          'instructions': ['Stand under bar', 'Squat down'],
        },
      ]);

      final overlay = jsonEncode({
        'bench-press': {
          'name': 'Supino Reto',
          'instructions': ['Deite-se no banco', 'Empurre a barra'],
        },
      });

      final result = parseExercisesFromJson(json, overlayJsonString: overlay);

      expect(result, hasLength(2));
      expect(result[0].name, 'Supino Reto');
      expect(result[0].instructions, '• Deite-se no banco\n• Empurre a barra');
      // Fallback para o texto original quando o id não está no overlay
      expect(result[1].name, 'Barbell Squat');
      expect(result[1].instructions, '• Stand under bar\n• Squat down');
    });

    test(
      'parseExercisesWithOverlay aplica tradução real do catálogo completo',
      () async {
        final raw = await rootBundle.loadString('assets/data/exercises.json');
        final overlay = await rootBundle.loadString(
          'assets/data/exercises_pt.json',
        );

        final exercises = parseExercisesWithOverlay((
          jsonString: raw,
          overlayJsonString: overlay,
        ));

        expect(exercises, hasLength(876));
        final sitUp = exercises.firstWhere((e) => e.id == '3_4_Sit-Up');
        expect(sitUp.name, 'Abdominal 3/4');
        expect(sitUp.instructions, contains('• Deite-se no chão'));
      },
    );
  });

  group('parseExercisesInChunks', () {
    test('aplica overlay pt-BR e faz fallback ao original em chunks', () async {
      final json = jsonEncode([
        {
          'id': 'ex-1',
          'name': 'Original 1',
          'instructions': ['Step 1'],
        },
        {
          'id': 'ex-2',
          'name': 'Original 2',
          'instructions': ['Step 2'],
        },
      ]);
      final overlay = jsonEncode({
        'ex-1': {
          'name': 'Traduzido 1',
          'instructions': ['Passo 1'],
        },
      });

      final result = await parseExercisesInChunks(
        json,
        overlayJsonString: overlay,
        chunkSize: 1,
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'Traduzido 1');
      expect(result[0].instructions, '• Passo 1');
      expect(result[1].name, 'Original 2');
      expect(result[1].instructions, '• Step 2');
    });
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
