import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/profile/data/datasources/supabase_profile_datasource.dart';
import 'package:olimpus/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSupabaseProfileDatasource extends Mock
    implements SupabaseProfileDatasource {}

void main() {
  late ProfileRepositoryImpl repository;
  late MockSupabaseProfileDatasource mockDatasource;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockDatasource = MockSupabaseProfileDatasource();
    repository = ProfileRepositoryImpl(
      datasource: mockDatasource,
      prefs: prefs,
    );
  });

  group('ProfileRepositoryImpl - getProfile', () {
    test('retorna UserProfile quando datasource retorna dados', () async {
      final remoteData = {
        'id': 'user-123',
        'display_name': 'Atleta Olímpico',
        'body_weight_kg': 80.5,
        'daily_water_goal_ml': 2500,
        'experience_level': 'intermediate',
        'avatar_url': null,
      };

      when(() => mockDatasource.getProfile('user-123'))
          .thenAnswer((_) async => remoteData);

      final result = await repository.getProfile('user-123');

      expect(result, isNotNull);
      expect(result!.id, 'user-123');
      expect(result.displayName, 'Atleta Olímpico');
      expect(result.bodyWeightKg, 80.5);
      expect(result.dailyWaterGoalMl, 2500);
      expect(result.experienceLevel, ExperienceLevel.intermediate);
      verify(() => mockDatasource.getProfile('user-123')).called(1);
    });

    test('retorna null quando datasource retorna null', () async {
      when(() => mockDatasource.getProfile('user-unknown'))
          .thenAnswer((_) async => null);

      final result = await repository.getProfile('user-unknown');

      expect(result, isNull);
      verify(() => mockDatasource.getProfile('user-unknown')).called(1);
    });

    test('propaga exceção do datasource', () async {
      when(() => mockDatasource.getProfile('user-error'))
          .thenThrow(Exception('Supabase connection error'));

      expect(() => repository.getProfile('user-error'), throwsException);
    });
  });

  group('ProfileRepositoryImpl - saveProfile', () {
    test(
      'converte UserProfile para mapa correto e chama updateProfile',
      () async {
        const profile = UserProfile(
          id: 'user-123',
          displayName: 'Atleta Teste',
          bodyWeightKg: 72.3,
          dailyWaterGoalMl: 2200,
          experienceLevel: ExperienceLevel.beginner,
        );

        when(() => mockDatasource.updateProfile('user-123', any()))
            .thenAnswer((_) async {});

        await repository.saveProfile(profile);

        verify(
          () => mockDatasource.updateProfile('user-123', {
            'display_name': 'Atleta Teste',
            'body_weight_kg': 72.3,
            'daily_water_goal_ml': 2200,
            'experience_level': 'beginner',
          }),
        ).called(1);
      },
    );

    test('propaga exceções ao salvar', () async {
      const profile = UserProfile(
        id: 'user-123',
        displayName: 'Atleta Teste',
        bodyWeightKg: 72.3,
      );

      when(() => mockDatasource.updateProfile('user-123', any()))
          .thenThrow(Exception('Falha de escrita'));

      expect(() => repository.saveProfile(profile), throwsException);
    });
  });

  group('ProfileRepositoryImpl - Local onboarding flag', () {
    test('isOnboardingCompletedLocally retorna false se não gravado', () {
      expect(repository.isOnboardingCompletedLocally('user-123'), isFalse);
    });

    test('setOnboardingCompletedLocally grava a flag e isOnboardingCompletedLocally retorna true', () async {
      await repository.setOnboardingCompletedLocally(
        'user-123',
        completed: true,
      );

      expect(repository.isOnboardingCompletedLocally('user-123'), isTrue);
      // Garante que o isolamento por usuário funciona
      expect(repository.isOnboardingCompletedLocally('user-other'), isFalse);
    });
  });
}
