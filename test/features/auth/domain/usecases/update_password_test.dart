import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/update_password.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late UpdatePassword usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = UpdatePassword(mockRepo);
  });

  final tPassword = 'newPassword123';

  test('should call updatePassword from repository', () async {
    // arrange
    when(() => mockRepo.updatePassword(any())).thenAnswer((_) async {});
    // act
    await usecase(tPassword);
    // assert
    verify(() => mockRepo.updatePassword(tPassword)).called(1);
    verifyNoMoreInteractions(mockRepo);
  });
}
