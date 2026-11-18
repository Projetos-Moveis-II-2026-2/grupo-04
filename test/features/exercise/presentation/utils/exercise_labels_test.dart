import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/presentation/utils/exercise_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('exercise_labels', () {
    test(
      'todos os valores distintos do dataset possuem rótulo mapeado',
      () async {
        final raw = await rootBundle.loadString('assets/data/exercises.json');
        final items = (jsonDecode(raw) as List<dynamic>)
            .cast<Map<String, dynamic>>();

        final forces = <String>{};
        final levels = <String>{};
        final mechanics = <String>{};
        final equipment = <String>{};
        final categories = <String>{};
        final muscles = <String>{};

        for (final item in items) {
          if (item['force'] is String) forces.add(item['force'] as String);
          if (item['level'] is String) levels.add(item['level'] as String);
          if (item['mechanic'] is String) {
            mechanics.add(item['mechanic'] as String);
          }
          if (item['equipment'] is String) {
            equipment.add(item['equipment'] as String);
          }
          if (item['category'] is String) {
            categories.add(item['category'] as String);
          }
          for (final m
              in (item['primaryMuscles'] as List<dynamic>? ?? const [])) {
            muscles.add(m as String);
          }
          for (final m
              in (item['secondaryMuscles'] as List<dynamic>? ?? const [])) {
            muscles.add(m as String);
          }
        }

        expect(muscles, hasLength(17));
        for (final f in forces) {
          expect(forceLabels.containsKey(f.toLowerCase()), isTrue, reason: f);
          expect(forceLabel(f), forceLabels[f.toLowerCase()]);
        }
        for (final l in levels) {
          expect(levelLabels.containsKey(l.toLowerCase()), isTrue, reason: l);
          expect(levelLabel(l), levelLabels[l.toLowerCase()]);
        }
        for (final m in mechanics) {
          expect(
            mechanicLabels.containsKey(m.toLowerCase()),
            isTrue,
            reason: m,
          );
          expect(mechanicLabel(m), mechanicLabels[m.toLowerCase()]);
        }
        for (final eq in equipment) {
          expect(
            equipmentLabels.containsKey(eq.toLowerCase()),
            isTrue,
            reason: eq,
          );
          expect(equipmentLabel(eq), equipmentLabels[eq.toLowerCase()]);
        }
        for (final c in categories) {
          expect(
            categoryLabels.containsKey(c.toLowerCase()),
            isTrue,
            reason: c,
          );
          expect(categoryLabel(c), categoryLabels[c.toLowerCase()]);
        }
        for (final mu in muscles) {
          expect(
            muscleLabels.containsKey(mu.toLowerCase()),
            isTrue,
            reason: mu,
          );
          expect(muscleLabel(mu), muscleLabels[mu.toLowerCase()]);
        }
      },
    );

    test('chaves de muscleGroupTranslation existem em muscleLabels', () {
      for (final keys in muscleGroupTranslation.values) {
        for (final key in keys) {
          expect(muscleLabels.containsKey(key), isTrue, reason: key);
        }
      }
    });

    test(
      'devolve valor capitalizado para chave desconhecida e traço para vazio',
      () {
        expect(muscleLabel('unknown muscle'), 'Unknown muscle');
        expect(equipmentLabel('sled'), 'Sled');
        expect(levelLabel('custom'), 'Custom');
        expect(mechanicLabel('hybrid'), 'Hybrid');
        expect(forceLabel('isometric'), 'Isometric');
        expect(categoryLabel('mobility'), 'Mobility');

        expect(muscleLabel(null), '—');
        expect(muscleLabel('   '), '—');
        expect(
          equipmentLabel(null, emptyFallback: 'Não informado'),
          'Não informado',
        );
      },
    );

    test('traduz listas de músculos separadas por vírgula', () {
      expect(muscleListLabel('chest, triceps'), 'Peito, Tríceps');
      expect(
        muscleListLabel('quadriceps, hamstrings, glutes'),
        'Quadríceps, Posteriores de coxa, Glúteos',
      );
      expect(muscleListLabel(''), '—');
      expect(muscleListLabel(null), '—');
    });
  });
}
