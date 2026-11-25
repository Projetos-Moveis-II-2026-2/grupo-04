import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/constants/app_constants.dart';
import 'package:olimpus/features/water/domain/water_goal_calculator.dart';

void main() {
  group('WaterGoalCalculator', () {
    group('calculateSuggestion', () {
      test('calcula 2800 ml para peso de 80 kg', () {
        final suggestion = WaterGoalCalculator.calculateSuggestion(80.0);
        expect(suggestion, equals(2800));
      });

      test('aplica limite inferior de 500 ml para pesos baixos', () {
        // 10 kg * 35 = 350 ml -> limitado a 500 ml
        final suggestion = WaterGoalCalculator.calculateSuggestion(10.0);
        expect(suggestion, equals(AppConstants.minWaterGoalMl));
        expect(suggestion, equals(500));
      });

      test('aplica limite superior de 5000 ml para pesos altos', () {
        // 160 kg * 35 = 5600 ml -> limitado a 5000 ml
        final suggestion = WaterGoalCalculator.calculateSuggestion(160.0);
        expect(suggestion, equals(AppConstants.maxWaterGoalMl));
        expect(suggestion, equals(5000));
      });

      test('arredonda o resultado para o inteiro mais próximo', () {
        // 70.3 kg * 35 = 2460.5 -> 2461 ml
        final suggestion = WaterGoalCalculator.calculateSuggestion(70.3);
        expect(suggestion, equals(2461));
      });

      test('retorna null para peso ausente (null)', () {
        final suggestion = WaterGoalCalculator.calculateSuggestion(null);
        expect(suggestion, isNull);
      });

      test('retorna null para peso zero ou negativo', () {
        expect(WaterGoalCalculator.calculateSuggestion(0.0), isNull);
        expect(WaterGoalCalculator.calculateSuggestion(-1.0), isNull);
        expect(WaterGoalCalculator.calculateSuggestion(-80.0), isNull);
      });

      test('retorna null para valores não finitos (NaN, Infinity)', () {
        expect(WaterGoalCalculator.calculateSuggestion(double.nan), isNull);
        expect(
          WaterGoalCalculator.calculateSuggestion(double.infinity),
          isNull,
        );
        expect(
          WaterGoalCalculator.calculateSuggestion(double.negativeInfinity),
          isNull,
        );
      });
    });

    group('isValidGoal', () {
      test('aceita valores dentro do limite 500..5000', () {
        expect(WaterGoalCalculator.isValidGoal(500), isTrue);
        expect(WaterGoalCalculator.isValidGoal(2000), isTrue);
        expect(WaterGoalCalculator.isValidGoal(2800), isTrue);
        expect(WaterGoalCalculator.isValidGoal(5000), isTrue);
      });

      test('rejeita valores fora do intervalo ou nulos', () {
        expect(WaterGoalCalculator.isValidGoal(null), isFalse);
        expect(WaterGoalCalculator.isValidGoal(499), isFalse);
        expect(WaterGoalCalculator.isValidGoal(0), isFalse);
        expect(WaterGoalCalculator.isValidGoal(-500), isFalse);
        expect(WaterGoalCalculator.isValidGoal(5001), isFalse);
        expect(WaterGoalCalculator.isValidGoal(10000), isFalse);
      });
    });
  });
}
