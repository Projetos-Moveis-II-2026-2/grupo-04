import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_env.dart';

/// Usuário autenticado criado no Supabase local para um teste de integração.
class TestUser {
  const TestUser({
    required this.client,
    required this.id,
    required this.email,
    required this.password,
  });

  final SupabaseClient client;
  final String id;
  final String email;
  final String password;
}

/// Cliente Supabase "puro" (sem `Supabase.initialize`) apontando para o stack
/// local. Cada usuário recebe seu próprio [SupabaseClient] para que o teste
/// possa alternar entre sessões sem misturar tokens.
class LocalSupabase {
  LocalSupabase() {
    final url = supabaseTestUrl;
    final anonKey = supabaseTestAnonKey;
    if (url == null || anonKey == null) {
      throw StateError(
        'LocalSupabase exige SUPABASE_TEST_URL e SUPABASE_TEST_ANON_KEY.',
      );
    }
    _url = url;
    _anonKey = anonKey;
  }

  late final String _url;
  late final String _anonKey;
  final List<SupabaseClient> _clients = [];

  static const _testPassword = 'OlimpusTest#56';

  SupabaseClient newClient() {
    // PKCE (padrão) exige asyncStorage; em testes usamos o fluxo implicit.
    final client = SupabaseClient(
      _url,
      _anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    _clients.add(client);
    return client;
  }

  /// Cria e autentica um usuário com e-mail aleatório.
  Future<TestUser> createUser({String prefix = 'user'}) async {
    final client = newClient();
    final email = randomTestEmail(prefix);

    final signUp = await client.auth.signUp(
      email: email,
      password: _testPassword,
    );

    // O stack local usa `enable_confirmations = false`, então o signUp já
    // devolve sessão. O fallback cobre ambientes com confirmação habilitada.
    if (signUp.session == null) {
      final signIn = await client.auth.signInWithPassword(
        email: email,
        password: _testPassword,
      );
      if (signIn.session == null) {
        throw StateError(
          'Não foi possível autenticar $email. Verifique se a confirmação de '
          'e-mail está desativada no Supabase local.',
        );
      }
    }

    final user = client.auth.currentUser ?? signUp.user;
    if (user == null) {
      throw StateError('Signup de $email não retornou usuário.');
    }

    return TestUser(
      client: client,
      id: user.id,
      email: email,
      password: _testPassword,
    );
  }

  /// Busca um exercício do catálogo público (FK obrigatória em exercise_sets).
  Future<String> firstExerciseId() async {
    final rows = await newClient()
        .from('exercise_library')
        .select('id')
        .limit(1);
    if (rows.isEmpty) {
      throw StateError(
        'exercise_library vazia: aplique as migrations/seed do Supabase local.',
      );
    }
    return rows.first['id'] as String;
  }

  Future<void> dispose() async {
    for (final client in _clients) {
      await client.dispose();
    }
    _clients.clear();
  }
}
