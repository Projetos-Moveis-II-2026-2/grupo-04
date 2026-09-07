import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/features/workout/data/datasources/ai_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late AiDatasource datasource;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    datasource = AiDatasource(client: client);
  });

  test('parseia resposta JSON da função', () async {
    when(() => functions.invoke('suggest-load', body: any(named: 'body')))
        .thenAnswer(
          (_) async => _TestResponse(
            status: 200,
            data: {
              'suggest_increase': true,
              'recommendation': 'Suba 2kg',
              'next_weight_kg': 82.0,
              'next_reps': 10,
            },
          ),
        );

    final s = await datasource.getSuggestion('ex-1');

    expect(s.suggestIncrease, isTrue);
    expect(s.recommendation, 'Suba 2kg');
    expect(s.nextWeightKg, 82.0);
    expect(s.nextReps, 10);
  });

  test('429 vira SuggestionRateLimited com next_available_at', () async {
    when(() => functions.invoke('suggest-load', body: any(named: 'body')))
        .thenThrow(
          FunctionException(
            status: 429,
            details: {
              'error': 'rate_limited',
              'next_available_at': '2026-09-14T00:00:00.000Z',
            },
          ),
        );

    await expectLater(
      datasource.getSuggestion('ex-1'),
      throwsA(
        isA<SuggestionRateLimited>().having(
          (e) => e.nextAvailableAt,
          'nextAvailableAt',
          DateTime.utc(2026, 9, 14),
        ),
      ),
    );
  });

  test('outros FunctionException são rethrow', () async {
    when(() => functions.invoke('suggest-load', body: any(named: 'body')))
        .thenThrow(
          const FunctionException(status: 500, details: {'error': 'boom'}),
        );

    await expectLater(
      datasource.getSuggestion('ex-1'),
      throwsA(isA<FunctionException>().having((e) => e.status, 'status', 500)),
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
