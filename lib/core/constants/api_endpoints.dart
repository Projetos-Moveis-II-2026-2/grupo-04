/// Endpoints e chaves públicas do backend.
///
/// Contém apenas valores públicos (URL do projeto e publishable key).
/// A service_role key e qualquer segredo NUNCA devem ficar aqui.
abstract final class ApiEndpoints {
  static const String supabaseUrl = 'https://sgcgvyywidwvybfxllkj.supabase.co';

  /// Publishable key (nova geração da antiga anon key), pública por design.
  static const String supabasePublishableKey =
      'sb_publishable_87H5WQCgu4YPXsPIh82hVQ_E7dgmD-A';
}
