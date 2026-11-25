import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olimpus/features/workout/data/datasources/exercise_catalog_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'aguarda a migração pt-BR antes de substituir o catálogo local',
    () async {
      final row = <String, dynamic>{
        'id': '00000000-0000-4000-8000-000000000001',
        'external_id': '3_4_Sit-Up',
        'name': '3/4 Sit-Up',
      };
      final client = SupabaseClient(
        'https://example.com',
        'public-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([row]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final datasource = SupabaseExerciseCatalogRemoteDataSource(client);

      expect(await datasource.fetchCatalog(), isEmpty);

      row['name_en'] = row['name'];
      row['name'] = 'Abdominal 3/4';
      row['instructions'] = ['Deite-se com os joelhos flexionados.'];

      final entries = await datasource.fetchCatalog();
      expect(entries.single.name.value, 'Abdominal 3/4');
      expect(
        entries.single.instructions.value,
        'Deite-se com os joelhos flexionados.',
      );
    },
  );
}
