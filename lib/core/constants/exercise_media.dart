import 'api_endpoints.dart';

/// URLs públicas das imagens do catálogo de exercícios.
///
/// Todas as imagens ficam no bucket público `exercise-media` do Supabase, na
/// estrutura `v1/<id>/{0,1}.jpg`, `v1/<id>/thumbnail.webp` e
/// `v1/<id>/motion.webp`.
abstract final class ExerciseMedia {
  static const String baseUrl = String.fromEnvironment(
    'EXERCISE_MEDIA_BASE_URL',
    defaultValue:
        '${ApiEndpoints.supabaseUrl}/storage/v1/object/public/exercise-media/v1',
  );

  /// Prefixos antigos do dataset que ainda podem estar gravados no Drift.
  ///
  /// Ficam centralizados aqui apenas para migrar URLs já persistidas em
  /// instalações existentes; nenhum fluxo novo deve gerá-los.
  static const String _legacyRawGithub =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
  static const String _legacyJsDelivr =
      'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/';

  /// Monta a URL de um quadro a partir do caminho relativo do dataset
  /// (por exemplo, `<id>/0.jpg`).
  static String frameUrl(String relativePath) => '$baseUrl/$relativePath';

  /// Miniatura otimizada do exercício.
  static String thumbnailUrl(String externalId) =>
      '$baseUrl/${Uri.encodeComponent(externalId)}/thumbnail.webp';

  /// Animação otimizada do exercício.
  static String motionUrl(String externalId) =>
      '$baseUrl/${Uri.encodeComponent(externalId)}/motion.webp';

  /// Normaliza qualquer URL de imagem de exercício para o bucket atual.
  ///
  /// URLs antigas do GitHub/jsDelivr são reescritas para o bucket; URLs
  /// `http(s)` de outro destino são mantidas; caminhos locais `assets/`
  /// continuam iguais; caminhos relativos viram URL do bucket.
  static String normalize(String url) {
    if (url.startsWith(_legacyRawGithub)) {
      return frameUrl(url.substring(_legacyRawGithub.length));
    }
    if (url.startsWith(_legacyJsDelivr)) {
      return frameUrl(url.substring(_legacyJsDelivr.length));
    }
    if (url.startsWith('http')) return url;
    if (url.startsWith('assets/')) return url;
    return frameUrl(url);
  }

  /// Indica se [url] aponta para o quadro [index] do catálogo do exercício.
  static bool isFrame(String url, String externalId, int index) {
    final expected = frameUrl('${Uri.encodeComponent(externalId)}/$index.jpg');
    return normalize(url) == expected;
  }
}
