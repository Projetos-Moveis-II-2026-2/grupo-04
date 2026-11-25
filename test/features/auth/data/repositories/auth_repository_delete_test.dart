import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:olimpus/features/auth/data/repositories/auth_repository_impl.dart';

class MockSupabaseAuthDatasource extends Mock
    implements SupabaseAuthDatasource {}

void main() {
  late AuthRepositoryImpl repository;
  late MockSupabaseAuthDatasource mockDatasource;

  setUp(() {
    mockDatasource = MockSupabaseAuthDatasource();
    repository = AuthRepositoryImpl(mockDatasource);
  });

  group('deleteAccount', () {
    test('should delegate to datasource.deleteAccount', () async {
      // arrange
      when(() => mockDatasource.deleteAccount()).thenAnswer((_) async {});
      // act
      await repository.deleteAccount();
      // assert
      verify(() => mockDatasource.deleteAccount()).called(1);
    });

    test('should rethrow datasource exceptions', () async {
      // arrange
      when(() => mockDatasource.deleteAccount())
          .thenThrow(Exception('edge function error'));
      // act & assert
      expect(() => repository.deleteAccount(), throwsException);
    });
  });
}
