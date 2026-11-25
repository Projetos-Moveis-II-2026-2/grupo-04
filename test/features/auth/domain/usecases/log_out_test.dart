import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:olimpus/features/auth/domain/usecases/log_out.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LogOut usecase;
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    usecase = LogOut(mockRepo);
  });

  test('should call signOut from repository', () async {
    // arrange
    when(() => mockRepo.signOut()).thenAnswer((_) async {});
    // act
    await usecase();
    // assert
    verify(() => mockRepo.signOut()).called(1);
    verifyNoMoreInteractions(mockRepo);
  });

  test('should propagate repository exceptions', () async {
    // arrange
    when(() => mockRepo.signOut()).thenThrow(Exception('sign out failed'));
    // act & assert
    expect(() => usecase(), throwsException);
  });
}
