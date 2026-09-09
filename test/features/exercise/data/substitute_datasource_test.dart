import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/exercise/data/datasources/substitute_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockBuilder extends Mock
    implements PostgrestFilterBuilder<List<dynamic>> {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late SubstituteDatasource datasource;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<dynamic>[]);
    registerFallbackValue(_MockBuilder());
  });

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    datasource = SubstituteDatasource(client);
  });

  // O datasource dá await no builder do rpc — o mock expõe .then que
  // entrega as linhas ao callback do await.
  void stubRpc(List<dynamic> rows) {
    final builder = _MockBuilder();
    when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
        .thenAnswer((inv) {
          final onValue = inv.positionalArguments[0] as Function;
          return Future.sync(() => onValue(rows));
        });
    when(() => client.rpc('find_substitutes', params: any(named: 'params')))
        .thenAnswer((_) => builder);
  }

  test('RPC com resultado: camada 1 usada, sem fallback', () async {
    stubRpc([
      {
        'id': 'alt-1',
        'name': 'Supino com Halteres',
        'equipment': 'dumbbell',
        'image_url': 'https://x/img.jpg',
      },
    ]);

    final result = await datasource.getSubstitutes('ex-1');

    expect(result, hasLength(1));
    expect(result.single.id, 'alt-1');
    expect(result.single.name, 'Supino com Halteres');
    expect(result.single.imageUrl, 'https://x/img.jpg');
    verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
  });

  test('RPC vazia: cai no fallback LLM (camada 2)', () async {
    stubRpc(<dynamic>[]);
    when(() => functions.invoke('suggest-substitute', body: any(named: 'body')))
        .thenAnswer(
          (_) async => _TestResponse(
            status: 200,
            data: {
              'substitutes': [
                {
                  'name': 'Flexão de Braço',
                  'equipment': 'body only',
                  'reason': 'Trabalha peitoral sem equipamento.',
                  'matched_id': 'fb-1',
                  'matched_name': 'Flexão de Braço',
                  'image_url': 'https://x/flexao.jpg',
                },
                {
                  'name': 'Exercicio Desconhecido',
                  'reason': 'sem match no catalogo.',
                },
              ],
            },
          ),
        );

    final result = await datasource.getSubstitutes('ex-1');

    expect(result, hasLength(2));
    expect(result[0].id, 'fb-1');
    expect(result[0].name, 'Flexão de Braço');
    expect(result[0].reason, isNotNull);
    // item sem match no catálogo não é selecionável (id vazio)
    expect(result[1].id, isEmpty);
    expect(result[1].name, 'Exercicio Desconhecido');
  });

  test('429 do fallback vira SubstituteRateLimited', () async {
    stubRpc(<dynamic>[]);
    when(() => functions.invoke('suggest-substitute', body: any(named: 'body')))
        .thenThrow(
          FunctionException(
            status: 429,
            details: {'next_available_at': '2026-09-14T00:00:00.000Z'},
          ),
        );

    await expectLater(
      datasource.getSubstitutes('ex-1'),
      throwsA(
        isA<SubstituteRateLimited>().having(
          (e) => e.nextAvailableAt,
          'nextAvailableAt',
          DateTime.utc(2026, 9, 14),
        ),
      ),
    );
  });
}

class _TestResponse implements FunctionResponse {
  const _TestResponse({required this.status, required this.data});

  @override
  final Map<String, dynamic> data;

  @override
  final int status;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
