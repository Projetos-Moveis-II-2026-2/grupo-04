import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/exercise/domain/entities/exercise_option.dart';

void main() {
  group('ExerciseOption', () {
    test('deve considerar iguais instâncias com mesmo id e name', () {
      const a = ExerciseOption(id: 'ex-1', name: 'Supino Reto');
      const b = ExerciseOption(id: 'ex-1', name: 'Supino Reto');

      expect(a, equals(b));
      expect(a.props, ['ex-1', 'Supino Reto']);
    });

    test('deve diferenciar instâncias quando id ou name mudam', () {
      const base = ExerciseOption(id: 'ex-1', name: 'Supino Reto');

      expect(
        base,
        isNot(equals(const ExerciseOption(id: 'ex-2', name: 'Supino Reto'))),
      );
      expect(
        base,
        isNot(equals(const ExerciseOption(id: 'ex-1', name: 'Agachamento'))),
      );
    });
  });
}
