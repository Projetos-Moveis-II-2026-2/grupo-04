import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/log_in.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LogIn usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = LogIn(mockRepo);
  });

  final tEmail = 'test@example.com';
  final tPassword = 'password123';
  final tUser = AppUser(
    id: 'user-1',
    email: tEmail,
    emailConfirmedAt: DateTime(2026, 9, 16),
  );

  test('should return the user from repository.signIn', () async {
    // arrange
    when(() => mockRepo.signIn(email: tEmail, password: tPassword))
        .thenAnswer((_) async => tUser);
    // act
    final result = await usecase(email: tEmail, password: tPassword);
    // assert
    expect(result, same(tUser));
    verify(() => mockRepo.signIn(email: tEmail, password: tPassword)).called(1);
    verifyNoMoreInteractions(mockRepo);
  });

  test('should propagate repository exceptions', () async {
    // arrange
    when(() => mockRepo.signIn(email: tEmail, password: tPassword))
        .thenThrow(Exception('invalid credentials'));
    // act & assert
    expect(() => usecase(email: tEmail, password: tPassword), throwsException);
    verify(() => mockRepo.signIn(email: tEmail, password: tPassword)).called(1);
  });
}
