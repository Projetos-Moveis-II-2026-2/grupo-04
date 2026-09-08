import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/reset_password.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late ResetPassword usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = ResetPassword(mockRepo);
  });

  final tEmail = 'test@example.com';

  test('should call sendPasswordResetEmail from repository', () async {
    // arrange
    when(() => mockRepo.sendPasswordResetEmail(any())).thenAnswer((_) async {});
    // act
    await usecase(tEmail);
    // assert
    verify(() => mockRepo.sendPasswordResetEmail(tEmail)).called(1);
    verifyNoMoreInteractions(mockRepo);
  });
}
