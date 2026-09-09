/// Providers globais de infraestrutura do app.
///
/// Importar este arquivo dá acesso a todos os providers base:
/// - [supabaseClientProvider]
/// - [appDatabaseProvider]
/// - [themeProvider] / [sharedPreferencesProvider]
/// - [connectivityProvider] / [connectivityServiceProvider]
library;

export 'database/providers/database_providers.dart';
export 'providers/connectivity_providers.dart';
export 'providers/supabase_providers.dart';
export 'providers/theme_provider.dart';
