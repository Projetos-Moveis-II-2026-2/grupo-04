import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';

void main() {
  group('UserProfile Entity', () {
    test('isCompleted retorna true quando displayName e bodyWeightKg estão preenchidos', () {
      const profile = UserProfile(
        id: 'user-1',
        displayName: 'Atleta Olímpico',
        bodyWeightKg: 75.5,
        dailyWaterGoalMl: 2500,
        experienceLevel: ExperienceLevel.intermediate,
      );

      expect(profile.isCompleted, isTrue);
    });

    test('isCompleted retorna false quando displayName está nulo ou vazio', () {
      const profile1 = UserProfile(
        id: 'user-1',
        displayName: null,
        bodyWeightKg: 75.5,
      );
      const profile2 = UserProfile(
        id: 'user-1',
        displayName: '   ',
        bodyWeightKg: 75.5,
      );

      expect(profile1.isCompleted, isFalse);
      expect(profile2.isCompleted, isFalse);
    });

    test('isCompleted retorna false quando bodyWeightKg é nulo ou <= 0', () {
      const profile1 = UserProfile(
        id: 'user-1',
        displayName: 'Atleta',
        bodyWeightKg: null,
      );
      const profile2 = UserProfile(
        id: 'user-1',
        displayName: 'Atleta',
        bodyWeightKg: 0,
      );
      const profile3 = UserProfile(
        id: 'user-1',
        displayName: 'Atleta',
        bodyWeightKg: -10,
      );

      expect(profile1.isCompleted, isFalse);
      expect(profile2.isCompleted, isFalse);
      expect(profile3.isCompleted, isFalse);
    });

    test(
      'ExperienceLevel.fromString faz o parse correto dos valores suportados',
      () {
        expect(
          ExperienceLevel.fromString('beginner'),
          ExperienceLevel.beginner,
        );
        expect(
          ExperienceLevel.fromString('intermediate'),
          ExperienceLevel.intermediate,
        );
        expect(
          ExperienceLevel.fromString('advanced'),
          ExperienceLevel.advanced,
        );
        expect(ExperienceLevel.fromString('invalid'), isNull);
        expect(ExperienceLevel.fromString(null), isNull);
      },
    );

    test('fromMap e toMap serializam e desserializam corretamente', () {
      final map = {
        'id': 'user-123',
        'display_name': 'Hércules',
        'body_weight_kg': 82.0,
        'daily_water_goal_ml': 3000,
        'experience_level': 'advanced',
        'avatar_url': 'https://example.com/avatar.png',
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.id, 'user-123');
      expect(profile.displayName, 'Hércules');
      expect(profile.bodyWeightKg, 82.0);
      expect(profile.dailyWaterGoalMl, 3000);
      expect(profile.experienceLevel, ExperienceLevel.advanced);
      expect(profile.avatarUrl, 'https://example.com/avatar.png');

      final serialized = profile.toMap();
      expect(serialized['id'], 'user-123');
      expect(serialized['display_name'], 'Hércules');
      expect(serialized['body_weight_kg'], 82.0);
      expect(serialized['daily_water_goal_ml'], 3000);
      expect(serialized['experience_level'], 'advanced');
    });
  });
}
