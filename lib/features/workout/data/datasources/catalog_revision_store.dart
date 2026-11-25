import 'package:shared_preferences/shared_preferences.dart';

/// Persiste qual revisão do catálogo remoto de exercícios já foi aplicada
/// localmente.
///
/// A interface mantém o repositório testável sem depender diretamente de
/// `SharedPreferences`.
abstract interface class CatalogRevisionStore {
  /// Revisão já aplicada; `0` quando nenhuma revisão foi registrada.
  int read();

  /// Grava a revisão aplicada.
  Future<void> write(int revision);
}

/// Implementação com `SharedPreferences`, na chave
/// `exercise_catalog_revision`.
class SharedPreferencesCatalogRevisionStore implements CatalogRevisionStore {
  SharedPreferencesCatalogRevisionStore(
    this._prefs, {
    this.key = 'exercise_catalog_revision',
  });

  final SharedPreferences _prefs;
  final String key;

  @override
  int read() => _prefs.getInt(key) ?? 0;

  @override
  Future<void> write(int revision) => _prefs.setInt(key, revision);
}
