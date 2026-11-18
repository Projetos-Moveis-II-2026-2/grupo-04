import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/profile/domain/entities/user_profile.dart';
import 'package:olimpus/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:olimpus/features/profile/domain/usecases/save_profile.dart';

class MockProfileRepository extends Mock implements IProfileRepository {}

void main() {
  late SaveProfile usecase;
  late MockProfileRepository mockRepo;

  setUp(() {
    mockRepo = MockProfileRepository();
    usecase = SaveProfile(mockRepo);
  });

  const tProfile = UserProfile(
    id: 'user-1',
    displayName: 'Teste',
    bodyWeightKg: 70.0,
    dailyWaterGoalMl: 2500,
    experienceLevel: ExperienceLevel.beginner,
  );

  test(
    'deve chamar saveProfile do repositório com o perfil fornecido',
    () async {
      when(() => mockRepo.saveProfile(tProfile)).thenAnswer((_) async {});

      await usecase(tProfile);

      verify(() => mockRepo.saveProfile(tProfile)).called(1);
      verifyNoMoreInteractions(mockRepo);
    },
  );

  test('deve propagar exceções lançadas pelo repositório ao salvar', () async {
    when(() => mockRepo.saveProfile(tProfile))
        .thenThrow(Exception('Falha de rede'));

    expect(() => usecase(tProfile), throwsException);
    verify(() => mockRepo.saveProfile(tProfile)).called(1);
  });
}
