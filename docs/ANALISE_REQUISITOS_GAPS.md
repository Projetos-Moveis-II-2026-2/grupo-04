# **ANÁLISE DE REQUISITOS E GAPS — OLIMPUS**

> **Versão:** 1.0 (03/09/2026)  
> **Base:** docs/PLANO_DESENVOLVIMENTO.md + docs/Proposta-Projeto-Olimpus.md + docs/Projeto-Disciplina.md  
> **Fontes consultadas:** Documentações oficiais (Supabase, Flutter, Riverpod, Google Play, pub.dev, GitHub)

---

## Sumário

- [Gaps de Stack e Dependências](#1-gaps-de-stack-e-dependências)
- [Gaps Arquiteturais](#2-gaps-arquiteturais)
- [Gaps de Autenticação](#3-gaps-de-autenticação)
- [Gaps de Banco de Dados e RLS](#4-gaps-de-banco-de-dados-e-rls)
- [Gaps de Offline e Sincronização](#5-gaps-de-offline-e-sincronização)
- [Gaps de Notificações](#6-gaps-de-notificações)
- [Gaps de API de Exercícios](#7-gaps-de-api-de-exercícios)
- [Gaps de IA e Edge Functions](#8-gaps-de-ia-e-edge-functions)
- [Gaps de Publicação Play Store](#9-gaps-de-publicação-play-store)
- [Gaps de Testes](#10-gaps-de-testes)
- [Gaps de Design e UI/UX](#11-gaps-de-design-e-uiux)
- [Decisões Pendentes (Backlog Arquitetural)](#12-decisões-pendentes-backlog-arquitetural)
- [Anexo: Versões Corretas das Dependências](#anexo-versões-corretas-das-dependências)

---

## 1. Gaps de Stack e Dependências

### 1.1 ❌ Versão do fl_chart incorreta no plano

**Problema:** O plano cita `fl_chart: ^0.70.0` mas a versão atual é **1.2.0** (pub.dev, 5 meses atrás). A versão 0.70.x é obsoleta e pode ter breaking changes para 1.x.

**Fonte:** https://pub.dev/packages/fl_chart

**Ação:** Atualizar para `fl_chart: ^1.2.0`. Verificar changelog de breaking changes 0.x → 1.x.

### 1.2 ❌ Riverpod vs get_it — redundância de DI

**Problema:** O plano atual lista **get_it + injectable** para injeção de dependência E **Riverpod** para gerenciamento de estado. O Riverpod (especialmente com codegen) **já é um sistema de injeção de dependência completo** — `ref.watch(provider)` substitui `get_it.get<T>()`. Usar ambos é redundante e aumenta a complexidade.

**Fonte:** https://riverpod.dev/docs/root/do_dont — "Providers are global, testable, and composable. Use them as your DI container."

**Recomendação:** Abandonar get_it + injectable. UseCases e Repositories viram providers Riverpod. Apenas datasources (Dio, Supabase client) podem ser singletons globais (injetados via `Provider`).

**Gap:** A decisão precisa ser tomada pelo grupo antes de iniciar a Etapa 1, pois a estrutura de pastas (injection_container.dart) e o scaffolding mudam.

### 1.3 ❌ Riverpod versão: 2.x ou 3.x?

**Problema:** O plano menciona Riverpod genericamente. O Riverpod 2.x e 3.x (pré-lançamento) têm diferenças na API sem codegen. A sintaxe codegen (`@riverpod`, `Notifier`, `AsyncNotifier`) é idêntica, mas a API sem codegen mudou (ProviderContainer.test() vs ProviderScope). 

**Fonte:** https://riverpod.dev/docs/introduction/getting_started

**Recomendação:** Usar Riverpod 3.x (com codegen). A versão 3.x é backward-compatible com codegen 2.x. `riverpod_generator`, `riverpod_annotation`, `riverpod_lint` são as dependências. Benefício: autoDispose é padrão, `@Riverpod(keepAlive: true)` para manter vivo.

### 1.4 ❌ flutter_lints desatualizado

**Problema:** `pubspec.yaml` atual usa `flutter_lints: ^6.0.0`. A versão estável atual é bastante avançada, e pode ser preferível usar o `flutter_lints` diretamente ou migrar para `dart_flutter_style_lints` mais recente.

**Fonte:** https://pub.dev/packages/flutter_lints

**Ação:** Verificar e atualizar. Adicionar `riverpod_lint` para validação de providers.

### 1.5 ⚠️ Dependências faltando (não listadas no plano)

| Dependência | Para quê | Versão sugerida |
|------------|----------|-----------------|
| `supabase_flutter` | Cliente Supabase (auth, db, functions, storage) | ^2.8.0 |
| `flutter_riverpod` | Gerenciamento de estado | ^3.0.0 |
| `riverpod_annotation` | Codegen de providers | ^2.6.0 |
| `riverpod_generator` | Codegen (dev) | ^2.6.0 |
| `riverpod_lint` | Lint de providers (dev) | ^3.0.0 |
| `dio` | HTTP client (ExerciseDB) | ^5.7.0 |
| `json_annotation` | Serialização | ^4.9.0 |
| `json_serializable` | Codegen (dev) | ^6.8.0 |
| `freezed_annotation` | Imutabilidade/mock | ^2.4.0 |
| `freezed` | Codegen (dev) | ^2.5.0 |
| `go_router` | Navegação declarativa | ^14.0.0 |
| `fl_chart` | Gráficos | ^1.2.0 |
| `flutter_local_notifications` | Notificações locais | ^22.3.0 |
| `permission_handler` | Permissões runtime | ^13.0.1 |
| `flutter_timezone` | Timezone para agendamento | ^2.0.0 |
| `timezone` | Zonas horárias | ^0.9.4 |
| `drift` | SQLite type-safe (offline) | ^2.34.4 |
| `sqlite3_flutter_libs` | SQLite nativo para drift | ^0.5.0 |
| `path_provider` | Caminho do banco drift | ^2.1.0 |
| `connectivity_plus` | Detecção de rede | ^7.3.1 |
| `cached_network_image` | Cache de imagens (exercícios) | ^3.4.0 |
| `intl` | Internacionalização/formatação | ^0.19.0 |
| `shimmer` | Loading skeleton | ^3.0.0 |
| `mocktail` | Mocks para testes | ^1.0.0 |
| `build_runner` | Codegen runner (dev) | ^2.4.0 |

---

## 2. Gaps Arquiteturais

### 2.1 ❌ Feature-first vs Layer-first: decisão necessária

**Problema:** O plano define uma estrutura de diretórios `layer-first` (core/data/domain/presentation) com subpastas globais. Para um app com funcionalidades isoladas (auth, workout, exercise, water, progress), **feature-first** pode ser mais organizado.

**Fonte:** https://docs.flutter.dev/app-architecture/guide — A documentação oficial do Flutter recomenda organização por feature para apps de médio porte.

**Recomendação:** Feature-first com layers dentro de cada feature:
```
lib/
├── core/           (shared: theme, constants, network, utils)
├── features/
│   ├── auth/
│   │   ├── data/   (datasources, models, repos_impl)
│   │   ├── domain/ (entities, usecases, repo_interfaces)
│   │   └── presentation/ (providers, pages, widgets)
│   ├── workout/
│   ├── exercise/
│   ├── water/
│   └── progress/
├── app.dart        # MaterialApp + rotas
└── main.dart       # Entry point
```

**Gap:** Decisão precisa ser tomada antes de iniciar o scaffolding. Feature-first facilita code review e parallélismo (cada membro trabalha uma feature).

### 2.2 ❌ Riverpod como DI elimina get_it — impacto na estrutura

**Problema:** O plano tem `injection_container.dart` com get_it. Se adotar Riverpod como DI, precisa de providers registrados perto de cada feature, não de um container central.

**Fonte:** https://riverpod.dev/docs/concepts/about_code_generation — "Providers são globais, auto-registrados, sem container central."

**Recomendação:** Substituir `injection_container.dart` por providers Riverpod. Exemplo:
```dart
// features/workout/data/repositories/workout_repository_impl.dart
@riverpod
IWorkoutRepository workoutRepository(Ref ref) {
  return WorkoutRepositoryImpl(
    supabase: ref.watch(supabaseClientProvider),
    driftDb: ref.watch(appDatabaseProvider),
  );
}

// features/workout/domain/usecases/log_set.dart
@riverpod
LogSet logSetUseCase(Ref ref) {
  return LogSet(repo: ref.watch(workoutRepositoryProvider));
}
```

### 2.3 ❌ Tratamento de erros: AsyncValue vs Either/Failure classes

**Problema:** O plano usa `Failures` e `Exceptions` na camada core. O Riverpod 3.x tem `AsyncValue` que encapsula Data/Error/Loading. Usar Either (dartz) ou classes Failure separadas é overengineering quando o Riverpod já trata estados assíncronos.

**Fonte:** https://riverpod.dev/docs/concepts/understanding_async — "AsyncValue is the preferred way to handle async states."

**Recomendação:** 
- Em vez de `Failure` classes, usar `AsyncValue.guard()` e tratar erros com `when(data:, error:, loading:)`.
- Exceções específicas de domínio podem ser classes de erro, mas não precisa de Either.
- Repository pattern mantém interface que retorna `Future<T>`, não `Future<Either<Failure, T>>`.

### 2.4 ❌ Navegação: go_router vs Navigator 2.0?

**Problema:** O plano cita `go_router`. O Flutter 3.27+ melhorou o Navigator 2.0 nativo. go_router tem dependência extra, breaking changes frequentes. Para um app com 6-8 telas, Navigator 1.0 (push/pop) pode ser suficiente.

**Fonte:** https://docs.flutter.dev/ui/navigation

**Recomendação:** Começar com Navigator 1.0. Se houver necessidade de rotas nomeadas complexas (deep links, autenticação), migrar para go_router ou auto_route depois. Simplifica o MVP.

### 2.5 ❌ Material Design 3 (M3) obrigatório

**Problema:** O plano menciona tema Material Design mas não especifica M3. Flutter 3.11+ tem suporte nativo a Material 3 com `useMaterial3: true`. Os componentes M3 (NavigationBar, FilledButton, Card) são o padrão da Play Store.

**Fonte:** https://docs.flutter.dev/ui/widgets/material

**Recomendação:** Usar `MaterialApp(useMaterial3: true, colorScheme: ColorScheme.fromSeed(...))` desde o dia 1. M3 é requisito implícito para publicação na Play Store (apps com visual moderno).

---

## 3. Gaps de Autenticação

### 3.1 ❌ Fluxo de confirmação de email

**Problema:** O plano menciona "cadastro de usuário" mas não detalha o fluxo de confirmação de email. O Supabase, por padrão, **exige** confirmação de email em projetos hosted (true). No projeto local, o padrão é false. O app precisa lidar com:
- Usuário que não recebeu email de confirmação
- Deep link para abrir o app após clicar no link de confirmação
- Reenvio de email de confirmação
- Validação de senha forte (mínimo 6 caracteres, padrão Supabase)

**Fonte:** https://supabase.com/docs/guides/auth/passwords — "Email authentication is enabled by default. On hosted Supabase projects, email confirmations are true by default."

**Ação:** 
- Configurar `emailRedirectTo` no signUp para um deep link custom scheme (ex: `olimpus://auth/callback`)
- Implementar tela de "confirmação pendente" após cadastro
- Configurar redirect URLs no Supabase Dashboard (`olimpus://**`)

### 3.2 ❌ Deep linking para mobile (AndroidManifest + Info.plist)

**Problema:** O Supabase requer **deep linking nativo** para o fluxo de confirmação de email e recuperação de senha funcionar em mobile. Sem isso, o usuário fica preso no navegador.

**Fonte:** https://supabase.com/docs/guides/auth/native-mobile-deep-linking

**Configuração Android (AndroidManifest.xml):**
```xml
<activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="olimpus" android:host="auth"/>
    </intent-filter>
</activity>
```

**Configuração iOS (Info.plist):**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>olimpus</string>
        </array>
    </dict>
</array>
```

**Ação:** Adicionar essas configurações nas plataformas antes de implementar auth.

### 3.3 ⚠️ Recuperação de senha: fluxo completo

**Problema:** O plano lista "recuperação de acesso (se viável no tempo)". O Supabase oferece `resetPasswordForEmail()` que envia email com link de redefinição. Mas no mobile, o link precisa abrir o app e exibir um formulário de nova senha. Sem deep link, o fluxo quebra.

**Fonte:** https://supabase.com/docs/guides/auth/passwords#resetting-a-password

**Ação:** 
- `supabase.auth.resetPasswordForEmail(email, redirectTo: 'olimpus://auth/reset-password')`
- Configurar rota no app para receber o token e chamar `supabase.auth.updateUser(password: newPassword)`

### 3.4 ❌ Persistência de sessão e auto-refresh

**Problema:** O plano não menciona como a sessão persiste. O `supabase_flutter` integra com `flutter_secure_storage` para persistir o JWT. O auto-refresh do token (refresh token rotation) é automático, mas precisa ser configurado.

**Fonte:** https://pub.dev/packages/supabase_flutter

**Ação:** 
```dart
await Supabase.initialize(
  url: 'https://...',
  anonKey: '...',
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce, // PKCE para mobile
  ),
);
```

### 3.5 ❌ Rate limiting

**Problema:** O Supabase limita a 2 emails/hora para signup/recover sem custom SMTP. Para testes com vários membros do grupo, pode ser necessário configurar SMTP personalizado.

**Fonte:** https://supabase.com/docs/guides/platform/going-into-prod — "2 emails per hour. You can only change this with your own custom SMTP setup."

**Ação:** Configurar SMTP (SendGrid, AWS SES) no Supabase Dashboard para desenvolvimento. Ou, em ambiente local (CLI), as confirmações são false por padrão.

---

## 4. Gaps de Banco de Dados e RLS

### 4.1 ❌ Grants + Policies: ambos são necessários

**Problema:** O plano lista as políticas RLS mas não menciona os **grants**. No Supabase, uma tabela em `public` já tem todos os privilégios (`select`, `insert`, `update`, `delete`) concedidos a `anon` e `authenticated` por padrão. **Adicionar políticas não revoga os grants** — a permissão bruta continua existindo. Se o grant permite `insert` para `anon`, a política pode até bloquear, mas o grant precisa ser revogado para defesa em profundidade.

**Fonte:** https://supabase.com/docs/guides/database/postgres/row-level-security — "A table in an exposed schema without RLS is readable and writable by any role with a grant on it. Enable RLS on every table in an exposed schema. On projects that still grant anon and authenticated by default, revoke those grants. Adding policies doesn't remove them."

**Ação:** Adicionar ao script de migração:
```sql
-- Revogar grants padrão (apenas service_role mantém tudo)
REVOKE ALL ON exercise_library FROM anon, authenticated;
REVOKE ALL ON workout_templates FROM anon;
REVOKE ALL ON workout_sessions FROM anon;
REVOKE ALL ON exercise_sets FROM anon;
REVOKE ALL ON water_intake FROM anon;

-- Conceder apenas o necessário
GRANT SELECT ON exercise_library TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON exercise_sets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON water_intake TO authenticated;
```

### 4.2 ❌ Views bypass RLS (security definer)

**Problema:** Se o app criar **views** no banco (ex: view de progresso que agrega dados de várias tabelas), elas **ignoram RLS** por padrão (são criadas como `security definer`). Uma view sobre uma tabela protegida expõe todos os dados que a política deveria esconder.

**Fonte:** https://supabase.com/docs/guides/database/postgres/row-level-security — "Views bypass RLS by default because they are usually created with the postgres user."

**Ação:** Se criar views, usar `security invoker`:
```sql
CREATE VIEW monthly_progress AS
SELECT ... FROM workout_sessions
WHERE ...  -- filtro manual por user_id
SECURITY INVOKER;  -- ← respeita RLS da tabela base
```

### 4.3 ⚠️ Índices para performance

**Problema:** O modelo de dados atual não tem índices. Para queries comuns:
- `SELECT * FROM exercise_sets WHERE session_id = ?` — precisa de índice em `session_id`
- `SELECT * FROM workout_sessions WHERE user_id = ? ORDER BY started_at DESC` — precisa de índice composto em `(user_id, started_at)`
- `SELECT * FROM water_intake WHERE user_id = ? AND date = ?` — precisa de índice em `(user_id, date)`

**Fonte:** https://supabase.com/docs/guides/database/query-optimization

**Ação:** Adicionar índices na migração:
```sql
CREATE INDEX idx_exercise_sets_session ON exercise_sets(session_id);
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, started_at DESC);
CREATE INDEX idx_water_intake_user_date ON water_intake(user_id, date);
```

### 4.4 ❌ Importação da biblioteca de exercícios

**Problema:** O plano cita consumo de API REST para a biblioteca de exercícios. O **free-exercise-db** (Unlicense, público) tem 800+ exercícios em JSON. **Importar diretamente no PostgreSQL** do Supabase é mais eficiente que chamar uma API externa (que pode ficar indisponível, ter rate limits, etc.).

**Fonte:** https://github.com/yuhonas/free-exercise-db — "Open Public Domain Exercise Dataset in JSON format, over 800 exercises."

**Ação:** Usar o NDJSON do free-exercise-db para popular a tabela `exercise_library` via `supabase db import` (ou função SQL com `COPY`). O app então consulta direto o banco (via RLS pública). Cache local com Drift para acesso offline.

### 4.5 ❌ Colunas `created_at` e `updated_at`

**Problema:** O modelo de dados atual tem `created_at` mas não `updated_at` em várias tabelas. Para sync offline, cada registro precisa de um timestamp de última modificação para resolução de conflitos LWW.

**Ação:** Adicionar `updated_at TIMESTAMPTZ DEFAULT NOW()` em todas as tabelas que serão sincronizadas:
```sql
ALTER TABLE workout_sessions ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE exercise_sets ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE water_intake ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
```

---

## 5. Gaps de Offline e Sincronização

### 5.1 ❌ Ausência total de estratégia offline no plano

**Problema:** O plano atual não menciona cache local nem sincronização. Academias frequentemente têm sinal de celular fraco (subsolo, concreto). O usuário pode ficar sem internet durante o treino.

**Fonte:** https://pub.dev/packages/drift — Drift (SQLite type-safe) com coluna `synced` + `connectivity_plus` para detecção de rede.

**Recomendação:** Implementar offline-first desde a Etapa 1:

**Arquitetura de dados:**
```
Usuário opera → Drift (local) → marca como synced:false
                               → fila SyncQueue
                               → connectivity_plus detecta online
                               → Worker processa fila (FIFO)
                               → Remove da fila + synced:true
                               → UI ouve watch() da query local
```

**Modelo de dados:**
```dart
// Tabela de sync
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get tableName => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // 'upsert', 'delete'
  TextColumn get payload => text()();   // JSON
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

// Tabela de dados com metadados
class ExerciseSet extends Table {
  TextColumn get localId => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
}
```

**Estratégia de merge:** "Last Write Wins" (LWW) é suficiente para séries de treino — cada série é atômica e auto-contida.

### 5.2 ❌ Não usar shared_preferences para dados de treino

**Problema:** O plano atual cita `SharedPreferences / Hive` para local storage. `shared_preferences` é apenas para configurações (tema, unidade, meta de água). **NÃO serve** para dados de treino (exercise_sets, sessions).

**Fonte:** https://pub.dev/packages/shared_preferences — "Wraps platform-specific persistent storage for simple data. Only supports int, double, bool, String, List<String>."

**Recomendação:** 
- **Drift** para dados de treino (relacional, streams reativos, migrations versionadas)
- **shared_preferences** para configurações (tema, onboarding, unidade de peso)
- **Hive** não é recomendado (sem queries, sem manutenção ativa — Isar é o sucessor mas está em v4.0.0-dev)

### 5.3 ❌ Sync de dados de hidratação

**Problema:** O módulo de hidratação (water_intake) também precisa de sync offline. O usuário registra água durante o dia, pode estar sem internet.

**Recomendação:** Mesmo padrão do workout: Drift local + sync queue.

---

## 6. Gaps de Notificações

### 6.1 ❌ Configuração nativa Android (permissões + receivers)

**Problema:** O plano cita `flutter_local_notifications` mas não detalha as configurações de AndroidManifest. Sem elas, o app não dispara notificações após reboot, nem pede permissão no Android 13+.

**Fonte:** https://pub.dev/packages/flutter_local_notifications

**AndroidManifest.xml necessário:**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.VIBRATE"/>

<application ...>
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        </intent-filter>
    </receiver>
</application>
```

### 6.2 ❌ Permissão runtime no Android 13+

**Problema:** Android 13+ exige solicitar permissão de notificação em runtime. Sem isso, o app não pode disparar lembretes de hidratação.

**Fonte:** https://pub.dev/packages/permission_handler

**Ação:** Usar `permission_handler` para solicitar `Permission.notification` e `Permission.scheduleExactAlarm`:
```dart
// Após o onboarding, na primeira vez que agenda lembrete
if (await Permission.notification.isDenied) {
  await Permission.notification.request();
}
if (await Permission.scheduleExactAlarm.isDenied) {
  await Permission.scheduleExactAlarm.request();
}
```

### 6.3 ❌ iOS: máximo 64 notificações agendadas

**Problema:** iOS limita a 64 notificações agendadas pendentes. Para lembretes de hidratação diários, usar `matchDateTimeComponents: DateTimeComponents.time` (uma única notificação recorrente), não agendar 30 notificações individuais.

**Fonte:** https://developer.apple.com/documentation/usernotifications

### 6.4 ❌ Timezone-aware scheduling

**Problema:** O `flutter_local_notifications` requer `zonedSchedule` para agendamento correto (timezone-aware). O app precisa do pacote `timezone` e `flutter_timezone`.

**Ação:** Inicializar timezone no `main()`:
```dart
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz.initializeTimeZones();
  // ... runApp
}
```

---

## 7. Gaps de API de Exercícios

### 7.1 ❌ free-exercise-db (Unlicense) é melhor que API externa

**Problema:** O plano menciona ExerciseDB API (API REST externa). O **free-exercise-db** é domínio público (Unlicense), 800+ exercícios em JSON, com imagens, e pode ser importado diretamente no PostgreSQL do Supabase. Sem dependência de API externa, sem rate limits, sem custo, sem indisponibilidade.

**Fonte:** https://github.com/yuhonas/free-exercise-db — "Open Public Domain Exercise Dataset. Unlicense."

**Recomendação:** 
- Importar `exercises.json` (NDJSON) no Supabase (seed initial)
- Tabela `exercise_library` populada via SQL (`COPY` ou função)
- Acesso via RLS (SELECT para todos)
- Cache local com Drift
- Se precisar de mais exercícios, o ExerciseDB API (se existir) pode ser complemento, mas não dependência primária

### 7.2 ❌ Formato do free-exercise-db

**Estrutura do JSON de cada exercício:**
```json
{
  "id": "Alternate_Incline_Dumbbell_Curl",
  "name": "Alternate Incline Dumbbell Curl",
  "force": "pull",
  "level": "beginner",
  "mechanic": "isolation",
  "equipment": "dumbbell",
  "primaryMuscles": ["biceps"],
  "secondaryMuscles": ["forearms"],
  "instructions": ["Sit down...", "Keep elbows..."],
  "category": "strength",
  "images": ["Alternate_Incline_Dumbbell_Curl/0.jpg", "Alternate_Incline_Dumbbell_Curl/1.jpg"]
}
```

As imagens são acessíveis via `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/` + caminho da imagem.

### 7.3 ⚠️ Moderar expectativa de UI

**Problema:** O free-exercise-db tem imagens GIF/JPEG dos exercícios, mas a qualidade pode variar. O plano deve prever cache de imagens (`cached_network_image` + fallback placeholder).

---

## 8. Gaps de IA e Edge Functions

### 8.1 ❌ Edge Functions: limites do plano free

**Problema:** O plano planeja Edge Functions no Supabase para chamar LLM. O plano free tem:
- 100 funções por projeto
- 256MB de memória
- 150s de timeout (wall clock)
- 2s de CPU time efetivo
- 20MB de tamanho máximo (bundle local)
- 5000 chamadas aninhadas/min

**Fonte:** https://supabase.com/docs/guides/functions/limits

**Impacto:** A IA de sugestão de carga envolve chamar OpenAI/Gemini. A latência da API externa (2-5s) conta no timeout de 150s (ok). O CPU time de 2s pode ser consumido rápido se a função fizer processamento pesado do histórico.

**Ação:** 
- Edge Function faz query no PostgreSQL (via Supabase client), monta prompt, chama LLM, retorna JSON
- Sem processamento pesado (CPU time 2s é suficiente para JSON + HTTP)
- Usar `supabase functions deploy` via CLI

### 8.2 ❌ Segurança da chave da API de LLM

**Problema:** A chave da OpenAI (ou Gemini) deve estar nas **secrets** do Supabase (Edge Functions), nunca no cliente Flutter.

**Fonte:** https://supabase.com/docs/guides/functions/secrets

**Ação:** 
```bash
supabase secrets set OPENAI_API_KEY=sk-xxxxx
```
No código da Edge Function:
```typescript
const apiKey = Deno.env.get('OPENAI_API_KEY')!;
```

### 8.3 ❌ Custo da API de LLM

**Problema:** Cada chamada de sugestão de carga custa ~$0.01-0.03 (GPT-4o-mini: $0.15/1M input tokens, $0.60/1M output tokens). Se 100 usuários ativos fizerem 1 sugestão/dia, ~$0.10-0.30/dia. Aceitável para MVP, mas precisa ser monitorado.

**Fonte:** https://openai.com/api/pricing

**Recomendação:** Usar GPT-4o-mini (mais barato, suficiente para análise de histórico de treino). Impor rate limiting (max 1 chamada/exercício/semana) para evitar abuso.

### 8.4 ❌ Chatbot assistente: escopo indefinido

**Problema:** "Como substituir o exercício X se a máquina estiver ocupada?" — requer conhecimento do equipamento disponível, grupos musculares, e exercícios similares. O free-exercise-db tem campos `equipment` e `primaryMuscles` que permitem consulta estruturada, reduzindo a necessidade de LLM.

**Recomendação:** O chatbot pode ser implementado como uma busca estruturada + fallback para LLM se o usuário não encontrar substituto. Exemplo:
1. Procurar exercícios no mesmo `primaryMuscles` com equipamento diferente
2. Se não achar, consultar LLM como fallback

---

## 9. Gaps de Publicação Play Store

### 9.1 ❌ Data Safety Form — declaração de dados de saúde

**Problema:** O Olimpus coleta peso corporal, dados de treino (cargas, séries, repetições) e consumo de água. O Google Play requer **Data Safety Form** declarando:
- **Personal info:** Name, Email (coletados pelo Supabase Auth)
- **Health & fitness:** Body weight, workout data, water intake (dados de saúde)
- **App activity:** Workout logs

**Fonte:** https://support.google.com/googleplay/android-developer/answer/10787469

**Ação:** Preparar a privacy policy e o Data Safety form. O app precisa de privacy policy pública (URL) que declare explicitamente o tratamento de dados de saúde e treino.

### 9.2 ❌ Privacy policy para dados de saúde

**Problema:** Apps que coletam dados de saúde/fitness precisam de privacy policy que:
- Informe quais dados de saúde são coletados
- Como são usados (exclusivamente para o funcionamento do app)
- Se são compartilhados com terceiros (não, exceto Supabase como processador)
- Como o usuário pode solicitar exclusão dos dados

**Fonte:** https://support.google.com/googleplay/android-developer/answer/9888170

### 9.3 ❌ Teste fechado: 12 testadores por 14 dias

**Problema:** O Google Play exige teste fechado com no mínimo **12 testadores** por **14 dias contínuos** antes de liberar a faixa de produção. O grupo precisa identificar 12 pessoas dispostas (colegas de classe, família, amigos) e criar um Google Group.

**Fonte:** https://play.google.com/console/about/ — política de closed testing (conhecimento geral, confirmado pela documentação do Flutter)

**Ação:** 
- Criar Google Group (ex: `olimpus-testers@googlegroups.com`)
- Adicionar testadores
- Iniciar teste fechado assim que o .aab da Etapa 2 estiver pronto (não esperar a Etapa 4)
- O teste de 14 dias corre em paralelo com o desenvolvimento

### 9.4 ❌ Play App Signing vs self-managed keystore

**Problema:** O Google Play App Signing (recomendado) gerencia a chave de assinatura. O desenvolvedor envia o .aab assinado com a "upload key" e o Google assina com a "app signing key". A "upload key" precisa ser guardada com segurança.

**Fonte:** https://support.google.com/googleplay/android-developer/answer/9842756

**Ação:** Configurar keystore para upload key no Flutter (android/key.properties + gradle) e optar pelo Google Play App Signing no Console.

### 9.5 ❌ Build .aab — ProGuard/R8

**Problema:** O plano cita geração .aab mas não menciona configuração de minificação. ProGuard/R8 reduz o tamanho do APK/AAB em ~40-60%. Para um app Flutter com várias dependências, o .aab sem minificação pode exceder 150MB.

**Fonte:** https://docs.flutter.dev/deployment/android

**Ação:** Configurar `android/app/build.gradle.kts`:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```

### 9.6 ❌ Permissão SCHEDULE_EXACT_ALARM e política do Google

**Problema:** Android 12+ exige que apps que usam `SCHEDULE_EXACT_ALARM` (notificações de hidratação) solicitem permissão e justifiquem no Play Console. O Google Play revisa essa permissão. Importante: `SCHEDULE_EXACT_ALARM` **não é restricted permission** (diferente de `USE_EXACT_ALARM`, que exige aprovação da loja) — é uma dangerous permission normal que se solicita em runtime.

**Fonte:** https://developer.android.com/develop/background-work/background-tasks/alarms + https://developer.android.com/reference/android/Manifest.permission

**Ação:** Declarar no manifest e solicitar em runtime com `permission_handler` (`Permission.scheduleExactAlarm`). Justificar o uso para lembretes de saúde.

### 9.7 ❌ Account deletion é obrigatório

**Problema:** O Google Play exige que apps com criação de conta **dentro do app** ofereçam ao usuário meios de solicitar a **exclusão da conta** — in-app E via web resource. "Temporary account deactivation, disabling, or freezing the app account does not qualify as account deletion." (User Data policy)

**Fonte:** https://support.google.com/googleplay/android-developer/answer/10144311 (User Data policy — a antiga 10260305 retorna 404; conteúdo migrou para cá)

**Ação:** Implementar tela "Excluir conta" no app + fluxo de exclusão no Supabase (chamada a Edge Function admin para apagar auth user + dados via cascade). Registrar URL de exclusão web no Play Console (ex: endpoint de Edge Function ou página estática com instruções). Adicionar como item da Etapa 4.

### 9.8 ❌ Data Safety form: declaração obrigatória para TODOS os apps

**Problema:** "Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy." O form também pergunta: criptografia em trânsito, mecanismo de exclusão de dados (Yes), SDKs de terceiros (Supabase, Firebase Analytics se usado).

**Fonte:** https://support.google.com/googleplay/android-developer/answer/10787469

**Classificação dos dados do Olimpus no form:**

| Dado | Categoria no form |
|------|-------------------|
| Nome, email, data de nascimento | Personal info |
| User ID | Personal info → User IDs |
| Peso, treinos, consumo de água | Health and fitness → Fitness info |
| Interações | App activity |
| Crash logs | App info and performance |
| Firebase ID (se usar analytics) | Device or other IDs |

### 9.9 ✅ Confirmado: nenhuma permissão de sensor necessária

**Confirmado pela pesquisa:** Para registro manual de treinos (sem sensor automático):
- **BODY_SENSORS** — NÃO necessária (cobre apenas heart rate, SpO2, skin temperature)
- **ACTIVITY_RECOGNITION** — NÃO necessária (é para detecção automática de atividade via sensor)
- **Health Connect** — não se aplica (só se integrar a API do Health Connect)

**Fonte:** https://support.google.com/googleplay/android-developer/answer/16558241 (redirecionada da antiga 9888170)

### 9.10 ❌ URLs de referência desatualizadas no plano

**Correções de URLs (várias retornavam 404):**

| URL antiga no plano | Status | URL correta |
|---------------------|--------|-------------|
| 9888170 (health apps) | 404 | https://support.google.com/googleplay/android-developer/answer/16558241 |
| 10791585 (closed testing) | 404 | https://support.google.com/googleplay/android-developer/answer/14151465 |
| 10260305 (account deletion) | 404 | https://support.google.com/googleplay/android-developer/answer/10144311 (User Data policy) |
| 9842756 (privacy policy) | Não é PP | Redireciona para "Use Play App Signing" — privacy policy está em 10144311 |

### 9.11 ❌ Credenciais de teste para o revisor

**Problema:** Apps com login obrigatório devem fornecer credenciais de teste funcionais no Play Console (seção "Sign-in details" do App content, até 5 conjuntos) para o revisor testar todas as funcionalidades. Sem isso, rejeição garantida.

**Fonte:** https://support.google.com/googleplay/android-developer/answer/14151465 — "provide valid, working login credentials in Play Console so reviewers can fully test your app's features"

**Ação:** Criar uma conta de teste dedicada (ex: `teste.olimpus@gmail.com`) e registrar credenciais no Play Console antes do envio para revisão.

---

## 10. Gaps de Testes

### 10.1 ❌ Estratégia de testes incompleta

**Problema:** O plano lista "testes unitários" e "testes de widget" mas não detalha como testar com Riverpod + Supabase + Drift.

**Fonte:** https://riverpod.dev/docs/how_to/testing — "ProviderContainer.test() sem widget tree."

**Ação por tipo de teste:**

| Tipo | O que testar | Como |
|------|-------------|------|
| **Unitário** | UseCases (regras de negócio) | Mockar Repository (mocktail) + testar casos de sucesso/falha |
| **Provider** | Lógica de estado (Notifier) | `ProviderContainer.test(overrides: [useCaseProvider.overrideWith(...)])` |
| **Widget** | Telas completas | `ProviderScope(overrides: [...])` + `pumpWidget` |
| **Integração** | Fluxo completo (auth → treino → gráfico) | Supabase local (CLI) + Drift em memória |
| **Snapshot/Golden** | UI consistência | `golden_toolkit` ou `alchemist` |

### 10.2 ❌ Testes de mock do Supabase

**Problema:** O Supabase client é difícil de mockar. A estratégia de usar Repository Pattern (interface no Domain) resolve — o teste mocka a interface, não o Supabase diretamente.

**Exemplo:**
```dart
class MockWorkoutRepository extends Mock implements IWorkoutRepository {}

void main() {
  test('LogSet deve salvar série', () async {
    final repo = MockWorkoutRepository();
    when(() => repo.logSet(any())).thenAnswer((_) async {});
    final useCase = LogSet(repo);
    await useCase(ExerciseSet(weightKg: 50, reps: 10));
    verify(() => repo.logSet(any())).called(1);
  });
}
```

### 10.3 ❌ Testes de integração com Drift em memória

**Problema:** Testes de integração precisam de banco real. Drift suporta `NativeDatabase.memory()` para testes em memória, sem arquivo físico.

**Ação:**
```dart
@Setup
void setUp() {
  db = AppDatabase(NativeDatabase.memory());
  // ou
  db = AppDatabase(NativeDatabase(':memory:'));
}
```

---

## 11. Gaps de Design e UI/UX

### 11.1 ❌ Referências de design não analisadas

**Problema:** O modelo atual (deepseek-v4-flash) não suporta imagens. As 3 referências de design em `docs/design-references/` não foram analisadas. Elas são essenciais para definir o visual do app.

**Ação:** Analisar as imagens com um modelo que suporte visão (ex: trocar o modelo da sessão) ou descrever manualmente o que cada referência contém.

### 11.2 ❌ Tema M3 não detalhado

**Problema:** O plano não especifica cores, tipografia, ou componentes do Material Design 3. O app precisa de um `ColorScheme` definido.

**Recomendação:** Usar `ColorScheme.fromSeed(seedColor: Color(0xFF...))` com uma cor primária inspirada nas referências de design. Sugestão: azul ou verde (associado a saúde/fitness).

### 11.3 ❌ Micro-interações e feedback tátil

**Problema:** O app de academia precisa de feedback tátil durante o treino (vibração ao completar série, som ao bater meta). O plano não menciona `HapticFeedback` ou `AudioFeedback`.

**Fonte:** https://api.flutter.dev/flutter/services/HapticFeedback-class.html

**Ação:** Adicionar `HapticFeedback.mediumImpact()` ou `HapticFeedback.heavyImpact()` ao completar cada série.

---

## 12. Decisões Pendentes (Backlog Arquitetural)

| # | Decisão | Opções | Impacto | Prazo |
|---|---------|--------|---------|-------|
| D1 | Organização de diretórios | Feature-first vs Layer-first | Estrutura do projeto, escalabilidade | Antes da Etapa 1 |
| D2 | Riverpod + get_it? | Riverpod como DI vs get_it + Riverpod | Quantidade de boilerplate, testabilidade | Antes da Etapa 1 |
| D3 | IA: cloud vs embarcada | Edge Functions + OpenAI vs TFLite local | Custo, desempenho, conectividade | Até Etapa 3 |
| D4 | Navegação | Navigator 1.0 vs go_router vs auto_route | Complexidade de rotas, deep links | Antes da Etapa 1 |
| D5 | Cache de exercícios: API vs DB | free-exercise-db importado vs ExerciseDB API | Dependência externa, disponibilidade | Antes da Etapa 1 |
| D6 | Offline-first priority | Drift sync queue vs Supabase realtime sync | Complexidade do MVP | Até Etapa 2 |
| D7 | SMTP para auth | SendGrid vs AWS SES vs Supabase default | Rate limit de 2 emails/hora | Antes da Etapa 1 |
| D8 | Cor primária do tema | Azul, verde, ou das referências de design | Identidade visual | Antes da Etapa 1 |
| D9 | Notificações de hidratação: horário fixo vs configurável | Fixo (8h-22h) vs configurável pelo usuário | UX, complexidade de implementação | Até Etapa 2 |
| D10 | Gamificação: streaks calculados local ou remoto | Drift (local) vs Supabase (remoto) via pg_cron | Persistência, complexidade | Até Etapa 3 |

---

## Anexo: Versões Corretas das Dependências

```yaml
# pubspec.yaml correto (após fechar as decisões)
dependencies:
  flutter:
    sdk: flutter
  # Gerenciamento de Estado + DI (Riverpod substitui get_it)
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^2.6.0
  # Supabase
  supabase_flutter: ^2.8.0
  # HTTP
  dio: ^5.7.0
  # Serialização
  json_annotation: ^4.9.0
  freezed_annotation: ^2.4.0
  # Navegação (a definir: Navigator 1.0 ou go_router)
  # go_router: ^14.0.0
  # Gráficos
  fl_chart: ^1.2.0
  # Notificações
  flutter_local_notifications: ^22.3.0
  permission_handler: ^13.0.1
  flutter_timezone: ^2.0.0
  timezone: ^0.9.4
  # Offline database
  drift: ^2.34.4
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  # Rede
  connectivity_plus: ^7.3.1
  # Cache de imagens
  cached_network_image: ^3.4.0
  # Utilitários
  intl: ^0.19.0
  shimmer: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  # Codegen
  json_serializable: ^6.8.0
  freezed: ^2.5.0
  riverpod_generator: ^2.6.0
  drift_dev: ^2.34.4
  # Testes
  mocktail: ^1.0.0
  drift_test: ^0.1.0
```

---

> **Este documento identifica 40+ gaps entre o plano atual e os requisitos reais de implementação.**  
> **Prioridade imediata:** Fechar as decisões D1-D8 (backlog arquitetural) antes de iniciar o código da Etapa 1.  
> **Próximo passo sugerido:** Revisão em grupo do documento + votação nas decisões D1-D8 + criação das issues de correção.