import 'dart:math';

/// Utilitário leve para geração e validação de UUID v4 (RFC 4122),
/// compatível com colunas `UUID` do Postgres/Supabase sem dependências extras.
abstract final class UuidV4 {
  static final Random _random = Random.secure();

  static final RegExp _uuidRegExp = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  /// Gera um novo UUID v4 em formato canônico lowercase.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Ajusta versão (4) e variante RFC 4122 (10xx)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).toList(growable: false);

    return '${h.sublist(0, 4).join()}-'
        '${h.sublist(4, 6).join()}-'
        '${h.sublist(6, 8).join()}-'
        '${h.sublist(8, 10).join()}-'
        '${h.sublist(10, 16).join()}';
  }

  /// Verifica se [value] possui formato válido de UUID.
  static bool isValid(String value) => _uuidRegExp.hasMatch(value);
}
