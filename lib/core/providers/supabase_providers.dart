import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase singleton — centraliza o acesso que antes era
/// espalhado via `Supabase.instance.client`.
///
/// Em testes, basta fazer override deste provider com um mock/fake.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
