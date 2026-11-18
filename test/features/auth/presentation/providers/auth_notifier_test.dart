import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MockAuthRepository mockRepo;
  late MockAppDatabase mockDb;

  final tEmail = 'test@example.com';
  final tPassword = 'password123';
  final tUser = AppUser(
    id: 'user-1',
    email: tEmail,
    emailConfirmedAt: DateTime(2026, 9, 16),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockAuthRepository();
    mockDb = MockAppDatabase();
    when(() => mockRepo.currentUser).thenReturn(null);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
        appDatabaseProvider.overrideWithValue(mockDb),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build', () {
    test('should expose the repository current user', () {
      // arrange
      when(() => mockRepo.currentUser).thenReturn(tUser);
      // act
      final container = createContainer();
      final state = container.read(authNotifierProvider);
      // assert
      expect(state.value, tUser);
      expect(state.hasError, isFalse);
    });

    test('should expose null when there is no authenticated user', () {
      // act
      final container = createContainer();
      final state = container.read(authNotifierProvider);
      // assert
      expect(state.value, isNull);
      expect(state.hasError, isFalse);
    });
  });

  group('signIn', () {
    test('should set AsyncData with the user on success', () async {
      // arrange
      when(() => mockRepo.signIn(email: tEmail, password: tPassword))
          .thenAnswer((_) async => tUser);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.signIn(email: tEmail, password: tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.value, tUser);
      expect(state.hasError, isFalse);
      verify(() => mockRepo.signIn(email: tEmail, password: tPassword))
          .called(1);
    });

    test('should set AsyncError and keep the exception on failure', () async {
      // arrange
      final error = const AuthException('Invalid login credentials');
      when(() => mockRepo.signIn(email: tEmail, password: tPassword))
          .thenThrow(error);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.signIn(email: tEmail, password: tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, error);
    });
  });

  group('signUp', () {
    test('should set AsyncData with the new user on success', () async {
      // arrange
      when(() => mockRepo.signUp(email: tEmail, password: tPassword))
          .thenAnswer((_) async => tUser);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.signUp(email: tEmail, password: tPassword);
      // assert
      expect(container.read(authNotifierProvider).value, tUser);
    });

    test('should set AsyncError on failure', () async {
      // arrange
      final error = const AuthException('user already registered');
      when(() => mockRepo.signUp(email: tEmail, password: tPassword))
          .thenThrow(error);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.signUp(email: tEmail, password: tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, error);
    });
  });

  group('signOut', () {
    test('should call repository.signOut and clear the user', () async {
      // arrange
      when(() => mockRepo.signOut()).thenAnswer((_) async {});
      when(() => mockRepo.currentUser).thenReturn(tUser);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      expect(container.read(authNotifierProvider).value, tUser);
      // act
      await notifier.signOut();
      // assert
      expect(container.read(authNotifierProvider).value, isNull);
      verify(() => mockRepo.signOut()).called(1);
    });
  });

  group('resendConfirmation', () {
    test('should delegate to the repository', () async {
      // arrange
      when(() => mockRepo.resendConfirmationEmail(tEmail))
          .thenAnswer((_) async {});
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.resendConfirmation(tEmail);
      // assert
      verify(() => mockRepo.resendConfirmationEmail(tEmail)).called(1);
    });

    test('should propagate repository exceptions', () async {
      // arrange
      when(() => mockRepo.resendConfirmationEmail(tEmail))
          .thenThrow(Exception('resend failed'));
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act & assert
      await expectLater(notifier.resendConfirmation(tEmail), throwsException);
    });
  });

  group('sendPasswordReset', () {
    test('should request the reset and finish without error', () async {
      // arrange
      when(() => mockRepo.sendPasswordResetEmail(tEmail))
          .thenAnswer((_) async {});
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.sendPasswordReset(tEmail);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isFalse);
      verify(() => mockRepo.sendPasswordResetEmail(tEmail)).called(1);
    });

    test('should set AsyncError on failure', () async {
      // arrange
      final error = const AuthException('rate limit exceeded');
      when(() => mockRepo.sendPasswordResetEmail(tEmail)).thenThrow(error);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.sendPasswordReset(tEmail);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, error);
    });
  });

  group('updatePassword', () {
    test('should update the password, sign out and clear the user', () async {
      // arrange
      when(() => mockRepo.updatePassword(tPassword)).thenAnswer((_) async {});
      when(() => mockRepo.signOut()).thenAnswer((_) async {});
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.updatePassword(tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.value, isNull);
      expect(state.hasError, isFalse);
      verify(() => mockRepo.updatePassword(tPassword)).called(1);
      verify(() => mockRepo.signOut()).called(1);
    });

    test('should set AsyncError when update fails', () async {
      // arrange
      final error = const AuthException('same password');
      when(() => mockRepo.updatePassword(tPassword)).thenThrow(error);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.updatePassword(tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, error);
      verifyNever(() => mockRepo.signOut());
    });
  });

  group('deleteAccount', () {
    test('should reauthenticate, delete data and sign out', () async {
      // arrange
      when(() => mockRepo.signIn(email: tEmail, password: tPassword))
          .thenAnswer((_) async => tUser);
      when(() => mockRepo.deleteAccount()).thenAnswer((_) async {});
      when(() => mockRepo.signOut()).thenAnswer((_) async {});
      when(() => mockDb.deleteAllUserData()).thenAnswer((_) async {});
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.deleteAccount(email: tEmail, password: tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.value, isNull);
      expect(state.hasError, isFalse);
      verify(() => mockRepo.signIn(email: tEmail, password: tPassword))
          .called(1);
      verify(() => mockRepo.deleteAccount()).called(1);
      verify(() => mockDb.deleteAllUserData()).called(1);
      verify(() => mockRepo.signOut()).called(1);
    });

    test('should set AsyncError and skip deletion on wrong password', () async {
      // arrange
      final error = const AuthException('Invalid login credentials');
      when(() => mockRepo.signIn(email: tEmail, password: tPassword))
          .thenThrow(error);
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      // act
      await notifier.deleteAccount(email: tEmail, password: tPassword);
      // assert
      final state = container.read(authNotifierProvider);
      expect(state.hasError, isTrue);
      expect(state.error, error);
      verifyNever(() => mockRepo.deleteAccount());
      verifyNever(() => mockDb.deleteAllUserData());
      verifyNever(() => mockRepo.signOut());
    });
  });
}
