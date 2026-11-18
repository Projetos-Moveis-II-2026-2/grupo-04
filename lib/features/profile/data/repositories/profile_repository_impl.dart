import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../datasources/supabase_profile_datasource.dart';

/// Implementação padrão de [IProfileRepository] com Supabase e SharedPreferences.
class ProfileRepositoryImpl implements IProfileRepository {
  final SupabaseProfileDatasource datasource;
  final SharedPreferences prefs;

  const ProfileRepositoryImpl({required this.datasource, required this.prefs});

  static const String _onboardingKeyPrefix = 'onboarding_completed_';

  String _onboardingKey(String userId) => '$_onboardingKeyPrefix$userId';

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final data = await datasource.getProfile(userId);
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final data = <String, dynamic>{
      'display_name': profile.displayName,
      'body_weight_kg': profile.bodyWeightKg,
      'daily_water_goal_ml': profile.dailyWaterGoalMl,
      'experience_level': profile.experienceLevel?.value,
      if (profile.avatarUrl != null) 'avatar_url': profile.avatarUrl,
    };

    await datasource.updateProfile(profile.id, data);
  }

  @override
  bool isOnboardingCompletedLocally(String userId) {
    return prefs.getBool(_onboardingKey(userId)) ?? false;
  }

  @override
  Future<void> setOnboardingCompletedLocally(
    String userId, {
    bool completed = true,
  }) async {
    await prefs.setBool(_onboardingKey(userId), completed);
  }
}
