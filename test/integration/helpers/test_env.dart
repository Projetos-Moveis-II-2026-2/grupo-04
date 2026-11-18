import 'dart:io';
import 'dart:math';

/// Variáveis de ambiente que apontam para o Supabase local.
const supabaseTestUrlVariable = 'SUPABASE_TEST_URL';
const supabaseTestAnonKeyVariable = 'SUPABASE_TEST_ANON_KEY';

String? get _supabaseTestUrl {
  final value = Platform.environment[supabaseTestUrlVariable]?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

String? get _supabaseTestAnonKey {
  final value = Platform.environment[supabaseTestAnonKeyVariable]?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

/// URL do Supabase local, ou `null` quando não configurada.
String? get supabaseTestUrl => _supabaseTestUrl;

/// Chave anônima/publicável do Supabase local, ou `null` quando ausente.
String? get supabaseTestAnonKey => _supabaseTestAnonKey;

/// `true` quando o ambiente permite rodar os testes contra o Supabase local.
bool get supabaseAvailable =>
    _supabaseTestUrl != null && _supabaseTestAnonKey != null;

const supabaseSkipReason =
    'Supabase local indisponível: defina SUPABASE_TEST_URL e '
    'SUPABASE_TEST_ANON_KEY (ex.: `supabase start` e exporte os valores de '
    '`supabase status -o env`).';

/// Motivo de skip pronto para `group(..., skip: ...)`; `null` quando há
/// Supabase configurado.
String? get supabaseSkipReasonOrNull =>
    supabaseAvailable ? null : supabaseSkipReason;

/// Gera um e-mail único para evitar colisão entre execuções e usuários.
String randomTestEmail(String prefix) {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final salt = Random.secure().nextInt(1 << 20).toRadixString(16);
  return '$prefix.$timestamp.$salt@olimpus.test';
}

/// Gera um UUID v4 aleatório para isolar os registros criados no Postgres.
String randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
