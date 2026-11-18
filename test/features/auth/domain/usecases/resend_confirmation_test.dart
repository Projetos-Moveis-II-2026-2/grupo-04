import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/resend_confirmation.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late ResendConfirmation usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = ResendConfirmation(mockRepo);
  });

  final tEmail = 'test@example.com';

  test('should call resendConfirmationEmail from repository', () async {
    // arrange
    when(() => mockRepo.resendConfirmationEmail(tEmail))
        .thenAnswer((_) async {});
    // act
    await usecase(tEmail);
    // assert
    verify(() => mockRepo.resendConfirmationEmail(tEmail)).called(1);
    verifyNoMoreInteractions(mockRepo);
  });

  test('should propagate repository exceptions', () async {
    // arrange
    when(() => mockRepo.resendConfirmationEmail(tEmail))
        .thenThrow(Exception('resend failed'));
    // act & assert
    expect(() => usecase(tEmail), throwsException);
  });
}
