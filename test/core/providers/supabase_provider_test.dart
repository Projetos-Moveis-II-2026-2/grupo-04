import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/providers/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test('supabaseClientProvider can be overridden with mock', () {
    final mock = MockSupabaseClient();
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);

    expect(container.read(supabaseClientProvider), same(mock));
  });
}
