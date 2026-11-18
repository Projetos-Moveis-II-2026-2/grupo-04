import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:olimpus/features/profile/domain/usecases/get_profile.dart';
import 'package:olimpus/features/profile/domain/usecases/save_profile.dart';
import 'package:olimpus/features/profile/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProfileRepository extends Mock implements IProfileRepository {}

class MockGetProfile extends Mock implements GetProfile {}

class MockSaveProfile extends Mock implements SaveProfile {}

void main() {
  late SharedPreferences prefs;
  late MockProfileRepository mockRepo;
  late MockGetProfile mockGetProfile;
  late MockSaveProfile mockSaveProfile;

  final testUser = AppUser(
    id: 'user-123',
    email: 'user@olimpus.com',
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockRepo = MockProfileRepository();
    mockGetProfile = MockGetProfile();
    mockSaveProfile = MockSaveProfile();

    registerFallbackValue(
      const UserProfile(
        id: 'user-fallback',
        displayName: 'Fallback',
        bodyWeightKg: 70,
      ),
    );
  });

  ProviderContainer createContainer({AppUser? user}) {
    final effectiveUser = user ?? testUser;
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(effectiveUser),
        profileRepositoryProvider.overrideWithValue(mockRepo),
        getProfileUseCaseProvider.overrideWithValue(mockGetProfile),
        saveProfileUseCaseProvider.overrideWithValue(mockSaveProfile),
      ],
    );
  }

  group('onboardingStatusProvider', () {
    test(
      'retorna true imediatamente se a flag local estiver gravada',
      () async {
        when(() => mockRepo.isOnboardingCompletedLocally('user-123'))
            .thenReturn(true);

        final container = createContainer();
        addTearDown(container.dispose);

        final status = await container.read(onboardingStatusProvider.future);

        expect(status, isTrue);
        verify(() => mockRepo.isOnboardingCompletedLocally('user-123'))
            .called(1);
        verifyZeroInteractions(mockGetProfile);
      },
    );

    test('consulta perfil remoto se flag local for false; se completo, grava local e retorna true', () async {
      when(() => mockRepo.isOnboardingCompletedLocally('user-123'))
          .thenReturn(false);
      when(
        () =>
            mockRepo.setOnboardingCompletedLocally('user-123', completed: true),
      ).thenAnswer((_) async {});

      const remoteProfile = UserProfile(
        id: 'user-123',
        displayName: 'Atleta',
        bodyWeightKg: 80.0,
      );
      when(() => mockGetProfile.call('user-123'))
          .thenAnswer((_) async => remoteProfile);

      final container = createContainer();
      addTearDown(container.dispose);

      final status = await container.read(onboardingStatusProvider.future);

      expect(status, isTrue);
      verify(
        () =>
            mockRepo.setOnboardingCompletedLocally('user-123', completed: true),
      ).called(1);
    });

    test('retorna false se perfil remoto estiver incompleto (sem nome/peso preenchidos)', () async {
      when(() => mockRepo.isOnboardingCompletedLocally('user-123'))
          .thenReturn(false);

      const remoteProfile = UserProfile(
        id: 'user-123',
        displayName: null,
        bodyWeightKg: null,
      );
      when(() => mockGetProfile.call('user-123'))
          .thenAnswer((_) async => remoteProfile);

      final container = createContainer();
      addTearDown(container.dispose);

      final status = await container.read(onboardingStatusProvider.future);

      expect(status, isFalse);
      verifyNever(
        () => mockRepo.setOnboardingCompletedLocally(
          any(),
          completed: any(named: 'completed'),
        ),
      );
    });
  });

  group('OnboardingNotifier', () {
    test('completeOnboarding salva perfil, marca flag local e retorna true em caso de sucesso', () async {
      when(() => mockSaveProfile.call(any())).thenAnswer((_) async {});
      when(
        () =>
            mockRepo.setOnboardingCompletedLocally('user-123', completed: true),
      ).thenAnswer((_) async {});

      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      final success = await notifier.completeOnboarding(
        displayName: 'Matheus',
        bodyWeightKg: 78.5,
        dailyWaterGoalMl: 2600,
        experienceLevel: ExperienceLevel.intermediate,
      );

      expect(success, isTrue);
      expect(
        container.read(onboardingNotifierProvider),
        const AsyncData<void>(null),
      );
      verify(
        () => mockSaveProfile.call(
          any(
            that: isA<UserProfile>()
                .having((p) => p.displayName, 'displayName', 'Matheus')
                .having((p) => p.bodyWeightKg, 'bodyWeightKg', 78.5)
                .having((p) => p.dailyWaterGoalMl, 'dailyWaterGoalMl', 2600)
                .having(
                  (p) => p.experienceLevel,
                  'experienceLevel',
                  ExperienceLevel.intermediate,
                ),
          ),
        ),
      ).called(1);
      verify(
        () =>
            mockRepo.setOnboardingCompletedLocally('user-123', completed: true),
      ).called(1);
    });

    test('completeOnboarding define estado AsyncError, NÃO marca flag local e retorna false em caso de falha', () async {
      when(() => mockSaveProfile.call(any()))
          .thenThrow(Exception('Falha de rede ao salvar no Supabase'));

      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingNotifierProvider.notifier);
      final success = await notifier.completeOnboarding(
        displayName: 'Matheus',
        bodyWeightKg: 78.5,
        dailyWaterGoalMl: 2600,
        experienceLevel: ExperienceLevel.intermediate,
      );

      expect(success, isFalse);
      expect(container.read(onboardingNotifierProvider).hasError, isTrue);
      verifyNever(
        () => mockRepo.setOnboardingCompletedLocally(
          any(),
          completed: any(named: 'completed'),
        ),
      );
    });
  });
}
