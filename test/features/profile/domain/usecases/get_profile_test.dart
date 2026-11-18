import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:olimpus/features/profile/domain/usecases/get_profile.dart';

class MockProfileRepository extends Mock implements IProfileRepository {}

void main() {
  late GetProfile usecase;
  late MockProfileRepository mockRepo;

  setUp(() {
    mockRepo = MockProfileRepository();
    usecase = GetProfile(mockRepo);
  });

  const tProfile = UserProfile(
    id: 'user-1',
    displayName: 'Teste',
    bodyWeightKg: 70.0,
  );

  test('deve chamar getProfile do repositório e retornar o perfil', () async {
    when(() => mockRepo.getProfile('user-1')).thenAnswer((_) async => tProfile);

    final result = await usecase('user-1');

    expect(result, equals(tProfile));
    verify(() => mockRepo.getProfile('user-1')).called(1);
    verifyNoMoreInteractions(mockRepo);
  });

  test('deve propagar exceções lançadas pelo repositório', () async {
    when(() => mockRepo.getProfile('user-1'))
        .thenThrow(Exception('Falha no banco'));

    expect(() => usecase('user-1'), throwsException);
    verify(() => mockRepo.getProfile('user-1')).called(1);
  });
}
