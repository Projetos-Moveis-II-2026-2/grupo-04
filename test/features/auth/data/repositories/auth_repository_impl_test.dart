import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:olimpus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseAuthDatasource extends Mock
    implements SupabaseAuthDatasource {}

void main() {
  late AuthRepositoryImpl repository;
  late MockSupabaseAuthDatasource mockDatasource;

  setUp(() {
    mockDatasource = MockSupabaseAuthDatasource();
    repository = AuthRepositoryImpl(mockDatasource);
  });

  User buildUser({
    String id = 'user-1',
    String? email = 'test@example.com',
    String? emailConfirmedAt,
  }) {
    return User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email,
      createdAt: '2026-01-01T00:00:00.000Z',
      emailConfirmedAt: emailConfirmedAt,
    );
  }

  final tEmail = 'test@example.com';
  final tPassword = 'password123';

  group('signUp', () {
    test('should map the returned user', () async {
      // arrange
      final user = buildUser(emailConfirmedAt: '2026-09-16T10:00:00.000Z');
      when(() => mockDatasource.signUp(email: tEmail, password: tPassword))
          .thenAnswer((_) async => AuthResponse(user: user));
      // act
      final result = await repository.signUp(
        email: tEmail,
        password: tPassword,
      );
      // assert
      expect(result.id, user.id);
      expect(result.email, user.email);
      expect(result.emailConfirmedAt, DateTime.parse('2026-09-16T10:00:00Z'));
      verify(() => mockDatasource.signUp(email: tEmail, password: tPassword))
          .called(1);
    });

    test('should throw AuthException when no user is returned', () async {
      // arrange
      when(() => mockDatasource.signUp(email: tEmail, password: tPassword))
          .thenAnswer((_) async => AuthResponse());
      // act & assert
      await expectLater(
        repository.signUp(email: tEmail, password: tPassword),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Signup failed'),
          ),
        ),
      );
    });

    test('should propagate datasource exceptions', () async {
      // arrange
      when(() => mockDatasource.signUp(email: tEmail, password: tPassword))
          .thenThrow(const AuthException('signup error'));
      // act & assert
      await expectLater(
        repository.signUp(email: tEmail, password: tPassword),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('signIn', () {
    test('should map the returned user', () async {
      // arrange
      final user = buildUser();
      when(
        () => mockDatasource.signInWithPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => AuthResponse(user: user));
      // act
      final result = await repository.signIn(
        email: tEmail,
        password: tPassword,
      );
      // assert
      expect(result.id, 'user-1');
      expect(result.email, tEmail);
      expect(result.emailConfirmedAt, isNull);
      verify(
        () => mockDatasource.signInWithPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).called(1);
    });

    test('should throw AuthException when no user is returned', () async {
      // arrange
      when(
        () => mockDatasource.signInWithPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenAnswer((_) async => AuthResponse());
      // act & assert
      await expectLater(
        repository.signIn(email: tEmail, password: tPassword),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Login failed'),
          ),
        ),
      );
    });

    test('should propagate datasource exceptions', () async {
      // arrange
      when(
        () => mockDatasource.signInWithPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(const AuthException('invalid login credentials'));
      // act & assert
      await expectLater(
        repository.signIn(email: tEmail, password: tPassword),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('signOut', () {
    test('should delegate to datasource.signOut', () async {
      // arrange
      when(() => mockDatasource.signOut()).thenAnswer((_) async {});
      // act
      await repository.signOut();
      // assert
      verify(() => mockDatasource.signOut()).called(1);
    });

    test('should propagate datasource exceptions', () async {
      // arrange
      when(() => mockDatasource.signOut()).thenThrow(Exception('sign out'));
      // act & assert
      expect(repository.signOut, throwsException);
    });
  });

  group('resendConfirmationEmail', () {
    test('should delegate to datasource.resendSignUpConfirmation', () async {
      // arrange
      when(() => mockDatasource.resendSignUpConfirmation(tEmail))
          .thenAnswer((_) async {});
      // act
      await repository.resendConfirmationEmail(tEmail);
      // assert
      verify(() => mockDatasource.resendSignUpConfirmation(tEmail)).called(1);
    });

    test('should propagate datasource exceptions', () async {
      // arrange
      when(() => mockDatasource.resendSignUpConfirmation(tEmail))
          .thenThrow(Exception('resend'));
      // act & assert
      expect(() => repository.resendConfirmationEmail(tEmail), throwsException);
    });
  });

  group('sendPasswordResetEmail', () {
    test('should delegate to datasource.resetPasswordForEmail', () async {
      // arrange
      when(() => mockDatasource.resetPasswordForEmail(tEmail))
          .thenAnswer((_) async {});
      // act
      await repository.sendPasswordResetEmail(tEmail);
      // assert
      verify(() => mockDatasource.resetPasswordForEmail(tEmail)).called(1);
    });

    test('should propagate datasource exceptions', () async {
      // arrange
      when(() => mockDatasource.resetPasswordForEmail(tEmail))
          .thenThrow(Exception('reset'));
      // act & assert
      expect(() => repository.sendPasswordResetEmail(tEmail), throwsException);
    });
  });

  group('updatePassword', () {
    test('should complete when datasource returns a user', () async {
      // arrange
      final response = UserResponse.fromJson({'id': 'user-1'});
      when(() => mockDatasource.updateUser(password: tPassword))
          .thenAnswer((_) async => response);
      // act
      await repository.updatePassword(tPassword);
      // assert
      verify(() => mockDatasource.updateUser(password: tPassword)).called(1);
    });

    test('should throw AuthException when no user is returned', () async {
      // arrange
      final response = UserResponse.fromJson(const {});
      when(() => mockDatasource.updateUser(password: tPassword))
          .thenAnswer((_) async => response);
      // act & assert
      await expectLater(
        repository.updatePassword(tPassword),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Failed to update password'),
          ),
        ),
      );
    });

    test('should propagate datasource exceptions', () async {
      // arrange
      when(() => mockDatasource.updateUser(password: tPassword))
          .thenThrow(const AuthException('same password'));
      // act & assert
      await expectLater(
        repository.updatePassword(tPassword),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('authStateChanges', () {
    test(
      'should map sessions to AppUser and signed-out events to null',
      () async {
        // arrange
        final user = buildUser(emailConfirmedAt: '2026-09-16T10:00:00.000Z');
        final session = Session(
          accessToken: 'access-token',
          tokenType: 'bearer',
          user: user,
        );
        when(() => mockDatasource.onAuthStateChange()).thenAnswer(
          (_) => Stream.fromIterable([
            AuthState(AuthChangeEvent.signedIn, session),
            AuthState(AuthChangeEvent.signedOut, null),
          ]),
        );
        // act
        final result = await repository.authStateChanges().toList();
        // assert
        expect(result, hasLength(2));
        expect(result.first?.id, user.id);
        expect(result.first?.email, tEmail);
        expect(result.last, isNull);
      },
    );
  });

  group('currentUser', () {
    test('should map the datasource current user', () {
      // arrange
      when(() => mockDatasource.currentUser).thenReturn(buildUser());
      // act
      final result = repository.currentUser;
      // assert
      expect(result, isNotNull);
      expect(result!.id, 'user-1');
      expect(result.email, tEmail);
    });

    test('should return null when datasource has no current user', () {
      // arrange
      when(() => mockDatasource.currentUser).thenReturn(null);
      // act
      final result = repository.currentUser;
      // assert
      expect(result, isNull);
    });

    test('should map a missing email to an empty string', () {
      // arrange
      when(() => mockDatasource.currentUser).thenReturn(buildUser(email: null));
      // act
      final result = repository.currentUser;
      // assert
      expect(result?.email, isEmpty);
    });
  });
}
