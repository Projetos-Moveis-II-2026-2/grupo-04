import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'overlay pt-BR cobre todos os 876 exercícios sem campos vazios',
    () async {
      final originalRaw = await rootBundle.loadString(
        'assets/data/exercises.json',
      );
      final overlayRaw = await rootBundle.loadString(
        'assets/data/exercises_pt.json',
      );

      final originalList = (jsonDecode(originalRaw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final overlayMap = jsonDecode(overlayRaw) as Map<String, dynamic>;

      expect(originalList, hasLength(876));
      expect(overlayMap, hasLength(876));

      final originalById = {
        for (final item in originalList) item['id'] as String: item,
      };

      expect(overlayMap.keys.toSet(), equals(originalById.keys.toSet()));

      for (final entry in overlayMap.entries) {
        final id = entry.key;
        final translated = entry.value as Map<String, dynamic>;
        final original = originalById[id]!;

        final name = translated['name'];
        expect(name, isA<String>(), reason: 'Nome inválido em $id');
        expect(
          (name as String).trim(),
          isNotEmpty,
          reason: 'Nome vazio em $id',
        );

        final instructions = translated['instructions'];
        final origInstructions = original['instructions'] as List<dynamic>;
        expect(
          instructions,
          isA<List<dynamic>>(),
          reason: 'Instruções inválidas em $id',
        );
        expect(
          (instructions as List<dynamic>).length,
          origInstructions.length,
          reason: 'Contagem de instruções divergente em $id',
        );

        for (var i = 0; i < instructions.length; i++) {
          final step = instructions[i];
          expect(step, isA<String>(), reason: 'Passo $i inválido em $id');
          expect(
            (step as String).trim(),
            isNotEmpty,
            reason: 'Passo $i vazio em $id',
          );
        }
      }
    },
  );
}
