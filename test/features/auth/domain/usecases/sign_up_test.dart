import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/sign_up.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late SignUp usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = SignUp(mockRepo);
  });

  final tEmail = 'new@example.com';
  final tPassword = 'password123';
  final tUser = AppUser(id: 'user-2', email: tEmail, emailConfirmedAt: null);

  test('should return the user from repository.signUp', () async {
    // arrange
    when(() => mockRepo.signUp(email: tEmail, password: tPassword))
        .thenAnswer((_) async => tUser);
    // act
    final result = await usecase(email: tEmail, password: tPassword);
    // assert
    expect(result, same(tUser));
    verify(() => mockRepo.signUp(email: tEmail, password: tPassword)).called(1);
    verifyNoMoreInteractions(mockRepo);
  });

  test('should propagate repository exceptions', () async {
    // arrange
    when(() => mockRepo.signUp(email: tEmail, password: tPassword))
        .thenThrow(Exception('email already registered'));
    // act & assert
    expect(() => usecase(email: tEmail, password: tPassword), throwsException);
  });
}
