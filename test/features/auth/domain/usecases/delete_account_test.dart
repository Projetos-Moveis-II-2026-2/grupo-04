import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/delete_account.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late DeleteAccount usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = DeleteAccount(mockRepo);
  });

  test('should call deleteAccount from repository', () async {
    // arrange
    when(() => mockRepo.deleteAccount()).thenAnswer((_) async {});
    // act
    await usecase();
    // assert
    verify(() => mockRepo.deleteAccount()).called(1);
    verifyNoMoreInteractions(mockRepo);
  });

  test('should propagate repository exceptions', () async {
    // arrange
    when(() => mockRepo.deleteAccount())
        .thenThrow(Exception('delete failed'));
    // act & assert
    expect(() => usecase(), throwsException);
  });
}
