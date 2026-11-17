import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/pages/settings_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  final testUser = AppUser(
    id: 'user-123',
    email: 'atleta@olimpus.com',
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'SettingsPage exibe nome do perfil e e-mail quando profile existe',
    (tester) async {
      const testProfile = UserProfile(
        id: 'user-123',
        displayName: 'Matheus Campeão',
        bodyWeightKg: 80.0,
        dailyWaterGoalMl: 2500,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser),
            userProfileProvider.overrideWith((ref) async => testProfile),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matheus Campeão'), findsOneWidget);
      expect(find.text('atleta@olimpus.com'), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsPage exibe rótulo Conta e e-mail quando displayName não está disponível',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser),
            userProfileProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conta'), findsOneWidget);
      expect(find.text('atleta@olimpus.com'), findsOneWidget);
    },
  );
}
