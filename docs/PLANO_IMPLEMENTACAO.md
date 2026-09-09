# **PLANO DE IMPLEMENTAÇÃO — OLIMPUS (v2.0)**

> **Disciplina:** Programação para Dispositivos Móveis II  
> **Grupo:** 4  
> **Integrantes:** Alêkson Castro, Gustavo Oliveira da Silva, Ítalo Emannuel Beckman, Matheus Alexandre Ferreira Nardi, Danilo  
> **Versão:** 2.0 (03/09/2026) — consolida `PLANO_DESENVOLVIMENTO.md` + correções de `ANALISE_REQUISITOS_GAPS.md`  
> **Status:** Aprovado em reunião — pronto para iniciar a Etapa 1

---

## Sumário

1. [Visão Geral e Decisões Aprovadas](#1-visão-geral-e-decisões-aprovadas)
2. [Stack e Dependências](#2-stack-e-dependências)
3. [Arquitetura (Feature-first + Riverpod)](#3-arquitetura-feature-first--riverpod)
4. [Funcionalidades MVP](#4-funcionalidades-mvp)
5. [Modelo de Dados (Supabase)](#5-modelo-de-dados-supabase)
6. [Estrutura de Diretórios](#6-estrutura-de-diretórios)
7. [Etapas do Desenvolvimento](#7-etapas-do-desenvolvimento)
8. [Integração de IA](#8-integração-de-ia)
9. [Publicação na Play Store](#9-publicação-na-play-store)
10. [Fluxo de Trabalho e Code Review](#10-fluxo-de-trabalho-e-code-review)
11. [Distribuição de Tarefas](#11-distribuição-de-tarefas)
12. [Cronograma](#12-cronograma)
13. [Backlog de Issues (GitHub)](#13-backlog-de-issues-github)
14. [Riscos e Mitigações](#14-riscos-e-mitigações)
15. [Decisões Pendentes](#15-decisões-pendentes)
16. [Anexo: pubspec.yaml Final](#anexo-pubspecyaml-final)

---

## 1. Visão Geral e Decisões Aprovadas

### 1.1 O Produto

Olimpus: app Flutter de saúde e fitness que centraliza **gestão de treinos de musculação** (com sobrecarga progressiva) e **monitoramento de hidratação** em interface única, com registro de baixo atrito durante o treino, painel de evolução e sugestão de carga via IA.

### 1.2 Decisões Arquiteturais Aprovadas (v2.0)

| # | Decisão | Escolha | Justificativa |
|---|---------|---------|---------------|
| D1 | Estrutura de código | **Feature-first** | Recomendado pela doc oficial Flutter; paraleliza o trabalho em grupo; cada feature é isolada |
| D2 | Injeção de Dependência | **Riverpod como DI** (elimina get_it) | Riverpod 3.x é compile-safe, testável e providers são o container nativo |
| D3 | Estratégia de IA | **Cloud: Edge Functions + OpenAI** | Modelo potente sem consumo local; definição final na Etapa 3 |
| D4 | Navegação | **go_router** | Deep links prontos para auth callback (Supabase) e notificações |
| D5 | Biblioteca de exercícios | **free-exercise-db importado no Supabase** (seed SQL) | Domínio público (Unlicense), 800+ exercícios, sem API externa/rate limit |
| D6 | Offline | **Offline-first completo** (Drift + sync queue) | Academia tem sinal fraco; robustez desde o MVP |

### 1.3 Principais Correções Aplicadas vs v1.0

| Área | v1.0 (errado) | v2.0 (correto) |
|------|---------------|----------------|
| fl_chart | `^0.70.0` | `^1.2.0` (versão atual) |
| DI | get_it + injectable | Riverpod (`ref.watch`) |
| Banco local | Hive | Drift (SQLite type-safe, offline-first) |
| Notificações | `^18.0.0` sem permissões | `^22.3.0` + permission_handler + timezone |
| RLS | só políticas | políticas + grants revogados + índices + `updated_at` |
| Exercícios | ExerciseDB API externa | free-exercise-db importado (seed) |
| Navegação | não definida | go_router |
| Play Store | só .aab | Data Safety + privacy policy + account deletion + closed testing |

---

## 2. Stack e Dependências

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Frontend | Flutter (SDK ^3.11.0) | stable |
| Estado + DI | flutter_riverpod + riverpod_annotation + riverpod_generator | 3.x |
| Navegação | go_router | ^14.0.0 |
| Backend | Supabase (Auth, Postgres, Edge Functions, Storage) | supabase_flutter ^2.8.0 |
| HTTP | dio | ^5.7.0 |
| Serialização | json_serializable + freezed | 6.8.x / 2.5.x |
| Gráficos | fl_chart | ^1.2.0 |
| Offline DB | drift + sqlite3_flutter_libs + path_provider | ^2.34.4 |
| Rede | connectivity_plus | ^7.3.1 |
| Notificações | flutter_local_notifications + permission_handler + flutter_timezone + timezone | 22.x / 13.x / 2.x / 0.9.x |
| Cache imagens | cached_network_image | ^3.4.0 |
| Testes | mocktail, flutter_test | — |

> Ver anexo (§16) para o pubspec.yaml completo.

---

## 3. Arquitetura (Feature-first + Riverpod)

### 3.1 Princípios

1. **Clean Architecture em 3 camadas POR FEATURE** (data / domain / presentation)
2. **Regra de Dependência:** UI → Domain (interfaces), nunca o inverso
3. **Repository Pattern:** interface no Domain, implementação no Data
4. **Riverpod = DI:** UseCases e Repositories são providers; datasources (Supabase, Dio, Drift) são providers singleton
5. **AsyncValue** para estados assíncronos (sem classes Either/Failure)

### 3.2 Fluxo de Dados por Feature

```
UI (Widget) → ref.watch(NotifierProvider) → UseCase (provider) → Repository (interface)
    → RepositoryImpl → DataSource (Supabase / Drift / Dio)
```

### 3.3 Exemplo Padrão (feature workout)

```dart
// features/workout/domain/repositories/i_workout_repository.dart
abstract interface class IWorkoutRepository {
  Future<void> logSet(ExerciseSet set);
}

// features/workout/domain/usecases/log_set.dart
class LogSet {
  const LogSet(this._repo);
  final IWorkoutRepository _repo;
  Future<void> call(ExerciseSet set) => _repo.logSet(set);
}

// features/workout/data/repositories/workout_repository_impl.dart
class WorkoutRepositoryImpl implements IWorkoutRepository {
  WorkoutRepositoryImpl({required this.driftDb, required this.supabase});
  final AppDatabase driftDb;
  final SupabaseClient supabase;
  @override
  Future<void> logSet(ExerciseSet set) async {
    await driftDb.into(driftDb.exerciseSets).insert(set.toCompanion(synced: false));
    await driftDb.into(driftDb.syncQueue).insert(SyncQueueCompanion.insert(
      tableName: 'exercise_sets', recordId: set.id, operation: 'upsert',
      payload: jsonEncode(set.toJson()), createdAt: DateTime.now()));
  }
}

// features/workout/data/repositories/workout_repository_provider.dart
@riverpod
IWorkoutRepository workoutRepository(Ref ref) => WorkoutRepositoryImpl(
  driftDb: ref.watch(appDatabaseProvider),
  supabase: ref.watch(supabaseClientProvider),
);

// features/workout/presentation/providers/workout_notifier.dart
@riverpod
class WorkoutNotifier extends _$WorkoutNotifier {
  @override
  AsyncValue<WorkoutState> build() => const AsyncData(WorkoutState.initial());
  Future<void> logSet(ExerciseSet set) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(logSetUseCaseProvider)(set));
  }
}
```

### 3.4 Camadas Compartilhadas (core/)

| Pasta | Conteúdo |
|-------|----------|
| `core/constants/` | URLs, timeouts, metas padrão (2000ml) |
| `core/network/` | dio_client, connectivity info |
| `core/theme/` | M3 ColorScheme, tipografia |
| `core/database/` | Drift: AppDatabase, tabelas, migrations |
| `core/utils/` | date_utils, validators |

---

## 4. Funcionalidades MVP

### 4.1 Cadastro e Autenticação (Alta)
- [ ] Signup email/senha + confirmação de email (Supabase Auth)
- [ ] Login e logout
- [ ] Recuperação de senha (deep link `olimpus://auth/reset-password`)
- [ ] Configuração inicial do perfil (peso, meta de água, nível)
- [ ] **Account deletion** (in-app + web resource) — requisito Play Store

### 4.2 Biblioteca de Exercícios (Alta)
- [ ] Seed do free-exercise-db no Supabase (800+ exercícios)
- [ ] Agrupamento por grupos musculares (`primaryMuscles`)
- [ ] Pesquisa e visualização (imagens via GitHub raw + cached_network_image)
- [ ] Cache local Drift (consulta offline)

### 4.3 Criação e Gestão de Treinos (Alta)
- [ ] Criar fichas (A, B, C) — `workout_templates`
- [ ] Adicionar exercícios da biblioteca à ficha (`template_exercises`)
- [ ] Definir séries/reps alvo

### 4.4 Registro de Execução — Core (Alta)
- [ ] Contraste da carga anterior lado a lado
- [ ] Campos rápidos peso (kg) + reps
- [ ] Checklist de série concluída (+ HapticFeedback)
- [ ] Volume total automático (Σ peso×reps)

### 4.5 Módulo de Hidratação (Alta)
- [ ] Barra de progresso (meta × consumido)
- [ ] Adição rápida (+250ml, +500ml)
- [ ] Histórico do dia (gráfico simples)

### 4.6 Painel de Evolução (Média/Alta)
- [ ] Gráfico de linha: carga máxima por exercício (fl_chart)
- [ ] Calendário de treinos no mês

### 4.7 Cronômetro de Descanso (Média)
- [ ] Timer configurável entre séries (na tela de execução)

### 4.8 Gamificação Básica (Baixa)
- [ ] Streak de hidratação e de treino (calculado local em Drift)

### 4.9 Inteligência Artificial (Alta — requisito da disciplina)
- [ ] Sugestão de carga via Edge Function + LLM
- [ ] Assistente de substituição de exercícios

---

## 5. Modelo de Dados (Supabase)

### 5.1 Migração Completa (grants + RLS + índices + updated_at)

```sql
-- ============================================================
-- MIGRATION 001 — Olimpus (aplicar via supabase CLI / SQL Editor)
-- ============================================================

-- ── TABELAS ──────────────────────────────────────────────────

CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  display_name TEXT,
  body_weight_kg DECIMAL(5,2),
  daily_water_goal_ml INTEGER DEFAULT 2000,
  experience_level TEXT CHECK (experience_level IN ('beginner','intermediate','advanced')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercise_library (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT UNIQUE NOT NULL,     -- id do free-exercise-db
  name TEXT NOT NULL,
  force TEXT,
  level TEXT,
  mechanic TEXT,
  equipment TEXT,
  primary_muscles TEXT[] NOT NULL,
  secondary_muscles TEXT[],
  instructions TEXT[],
  category TEXT,
  image_urls TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE template_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES workout_templates(id) ON DELETE CASCADE NOT NULL,
  exercise_id UUID REFERENCES exercise_library(id) NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  target_sets INTEGER NOT NULL DEFAULT 3,
  target_reps INTEGER
);

CREATE TABLE workout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  template_id UUID REFERENCES workout_templates(id),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  total_volume_kg DECIMAL(10,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercise_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES workout_sessions(id) ON DELETE CASCADE NOT NULL,
  exercise_id UUID REFERENCES exercise_library(id) NOT NULL,
  set_number INTEGER NOT NULL,
  weight_kg DECIMAL(5,2) NOT NULL,
  reps INTEGER NOT NULL,
  completed BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE water_intake (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount_ml INTEGER NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  date DATE DEFAULT CURRENT_DATE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── GRANTS: revogar defaults e conceder o mínimo ──────────────
REVOKE ALL ON exercise_library FROM anon, authenticated;
REVOKE ALL ON profiles, workout_templates, template_exercises,
            workout_sessions, exercise_sets, water_intake FROM anon;

GRANT SELECT ON exercise_library TO anon;                       -- catálogo público
GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON template_exercises TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON exercise_sets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON water_intake TO authenticated;

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_intake ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_library ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own profile" ON profiles
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "own templates" ON workout_templates
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own template exercises" ON template_exercises
  FOR ALL USING (EXISTS (SELECT 1 FROM workout_templates t
                         WHERE t.id = template_id AND t.user_id = auth.uid()));
CREATE POLICY "own sessions" ON workout_sessions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own sets" ON exercise_sets
  FOR ALL USING (EXISTS (SELECT 1 FROM workout_sessions s
                         WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY "own water" ON water_intake
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "public exercise read" ON exercise_library
  FOR SELECT USING (TRUE);

-- ── ÍNDICES ───────────────────────────────────────────────────
CREATE INDEX idx_exercise_sets_session ON exercise_sets(session_id);
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, started_at DESC);
CREATE INDEX idx_water_intake_user_date ON water_intake(user_id, date);
CREATE INDEX idx_template_exercises_template ON template_exercises(template_id);

-- ── TRIGGER: updated_at automático ────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['profiles','workout_templates','workout_sessions',
                          'exercise_sets','water_intake'] LOOP
    EXECUTE format('CREATE TRIGGER trg_%s_updated BEFORE UPDATE ON %I
                    FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
  END LOOP;
END $$;
```

### 5.2 Seed da Biblioteca de Exercícios (free-exercise-db)

**Fonte:** https://github.com/yuhonas/free-exercise-db (Unlicense, 800+ exercícios)

```bash
# 1. Baixar o dataset consolidado
curl -L https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json -o exercises.json

# 2. Gerar NDJSON (requer jq)
jq -c '.[]' exercises.json > exercises.ndjson

# 3. Importar no Supabase (via psql ou supabase db)
# Exemplo com psql:
psql "$DATABASE_URL" -c "\copy exercise_library
  (external_id, name, force, level, mechanic, equipment,
   primary_muscles, secondary_muscles, instructions, category)
  FROM 'exercises.ndjson' ..."  # campos mapeados no seed
```

> **Importante:** `primary_muscles`/`secondary_muscles`/`instructions` são arrays → no seed SQL, converter `["biceps"]` para `{biceps}` (sintaxe Postgres array).

### 5.3 Notas Críticas (gaps corrigidos)

- ⚠️ **Grants ≠ Policies:** revogar grants padrão é obrigatório (anon/authenticated têm acesso total por default)
- ⚠️ **Views:** se criar views de progresso, usar `SECURITY INVOKER` (views bypass RLS por padrão)
- ⚠️ **`updated_at`** em todas as tabelas sincronizáveis (LWW no sync)

---

## 6. Estrutura de Diretórios (Feature-first)

```
lib/
├── main.dart                        # Entry point: init timezone, Supabase, runApp
├── app.dart                         # MaterialApp (M3) + go_router router
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart       # metas padrão (2000ml), timeouts
│   │   └── api_endpoints.dart       # Supabase URL, anon key, raw image base
│   ├── network/
│   │   ├── dio_client.dart
│   │   └── connectivity_service.dart  # connectivity_plus wrapper
│   ├── database/
│   │   ├── app_database.dart        # Drift AppDatabase + migrations
│   │   ├── tables/
│   │   │   ├── exercise_sets_table.dart
│   │   │   ├── workout_sessions_table.dart
│   │   │   ├── workout_templates_table.dart
│   │   │   ├── exercise_library_table.dart
│   │   │   ├── water_intake_table.dart
│   │   │   └── sync_queue_table.dart
│   │   └── sync/
│   │       ├── sync_queue_service.dart   # processa fila quando online
│   │       └── sync_providers.dart
│   ├── theme/
│   │   ├── app_theme.dart           # ColorScheme.fromSeed, dark/light
│   │   └── app_colors.dart
│   └── utils/
│       ├── date_utils.dart
│       └── validators.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/supabase_auth_datasource.dart
│   │   │   ├── models/user_model.dart
│   │   │   └── repositories/auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/user.dart
│   │   │   ├── repositories/i_auth_repository.dart
│   │   │   └── usecases/sign_up.dart | log_in.dart | log_out.dart
│   │   │                        | reset_password.dart | delete_account.dart
│   │   └── presentation/
│   │       ├── providers/auth_notifier.dart | auth_providers.dart
│   │       ├── pages/login_page.dart | register_page.dart
│   │       │        | reset_password_page.dart | delete_account_page.dart
│   │       └── widgets/
│   ├── workout/
│   │   ├── data/
│   │   │   ├── datasources/supabase_workout_datasource.dart
│   │   │   ├── models/workout_template_model.dart | workout_session_model.dart
│   │   │   │         | exercise_set_model.dart
│   │   │   └── repositories/workout_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/workout_template.dart | workout_session.dart | exercise_set.dart
│   │   │   ├── repositories/i_workout_repository.dart
│   │   │   └── usecases/create_template.dart | start_session.dart
│   │   │            | log_set.dart | get_progress.dart | compute_volume.dart
│   │   └── presentation/
│   │       ├── providers/workout_notifier.dart | workout_providers.dart
│   │       ├── pages/workout_page.dart | templates_page.dart | create_template_page.dart
│   │       └── widgets/set_card.dart | previous_load_display.dart | rest_timer.dart
│   ├── exercise/
│   │   ├── data/
│   │   │   ├── datasources/exercise_datasource.dart   # Supabase + Drift cache
│   │   │   ├── models/exercise_model.dart
│   │   │   └── repositories/exercise_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/exercise.dart
│   │   │   ├── repositories/i_exercise_repository.dart
│   │   │   └── usecases/get_exercises.dart | search_exercises.dart
│   │   └── presentation/
│   │       ├── providers/exercise_providers.dart
│   │       ├── pages/exercises_page.dart | exercise_detail_page.dart
│   │       └── widgets/exercise_card.dart | muscle_group_chip.dart
│   ├── water/
│   │   ├── data/
│   │   │   ├── datasources/water_datasource.dart      # Drift + Supabase
│   │   │   ├── models/water_intake_model.dart
│   │   │   └── repositories/water_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/water_intake.dart
│   │   │   ├── repositories/i_water_repository.dart
│   │   │   └── usecases/log_water.dart | get_daily_water.dart
│   │   └── presentation/
│   │       ├── providers/water_notifier.dart
│   │       ├── pages/water_page.dart
│   │       └── widgets/water_progress_bar.dart | quick_add_button.dart
│   └── progress/
│       ├── data/
│       │   └── repositories/progress_repository_impl.dart
│       ├── domain/
│       │   ├── entities/progress_entry.dart
│       │   ├── repositories/i_progress_repository.dart
│       │   └── usecases/get_evolution.dart
│       └── presentation/
│           ├── providers/progress_providers.dart
│           ├── pages/progress_page.dart | home_page.dart | splash_page.dart
│           └── widgets/evolution_chart.dart | workout_calendar.dart
│
└── router/
    ├── app_router.dart              # go_router: rotas + auth redirect
    └── router_provider.dart
```

---

## 7. Etapas do Desenvolvimento

### Etapa 1 (Aulas 7-8 → Entrega A1)

**Foco:** Fundação funcional — autenticação, catálogo, fichas, execução básica.

| # | Item | Detalhe | Responsável |
|---|------|---------|-------------|
| 1.1 | Setup Flutter + pubspec final (§16) | Dependências corrigidas, flutter pub get | Ítalo |
| 1.2 | Scaffold feature-first + core/ | Pastas, Drift AppDatabase, theme M3, router | Ítalo |
| 1.3 | Supabase: projeto + migração 001 | Tabelas, grants, RLS, índices, triggers | Ítalo |
| 1.4 | Seed free-exercise-db | Importar 800+ exercícios (seed SQL) | Alêkson |
| 1.5 | Auth (signup/login/logout) | Supabase Auth + deep links nativos | Matheus |
| 1.6 | Biblioteca de exercícios | Lista, busca, cache Drift | Alêkson |
| 1.7 | Fichas de treino (CRUD) | Templates + template_exercises | Alêkson |
| 1.8 | Execução básica do treino | Registrar séries, contraste carga anterior | Ítalo |
| 1.9 | Navegação + auth guard | go_router: splash→login→home→workout | Matheus |
| 1.10 | Code Review cruzado (G1↔G2, G3↔G4) | Checklist §10.3 | Todos |

**Setup nativo (dentro da Etapa 1):**
- AndroidManifest: deep link `olimpus://auth`, receivers de notificação, permissões (§9.4)
- Info.plist: CFBundleURLTypes + UNUserNotificationCenter

**Checkpoint A1 (Aula 9):** app rodando com auth + catálogo + registro de série.

### Etapa 2 (Aulas 10-12)

**Foco:** Núcleo completo — persistência cloud, offline, hidratação, evolução.

| # | Item | Detalhe |
|---|------|---------|
| 2.1 | Sync offline-first | Drift + SyncQueue + connectivity_plus flush |
| 2.2 | Supabase persistência completa | Sessions/sets salvos na nuvem (via sync) |
| 2.3 | Módulo de hidratação | Barra, adição rápida, histórico do dia |
| 2.4 | Cronômetro de descanso | Na tela de execução |
| 2.5 | Volume total automático | Σ peso×reps por sessão |
| 2.6 | Painel de evolução | fl_chart linha (carga máx/exercício) + calendário |
| 2.7 | Tratamento global de erros | Dio interceptors + AsyncValue.guard |
| 2.8 | Notificações de hidratação | flutter_local_notifications + permissões runtime |
| 2.9 | Code Review cruzado (G2↔G1, G4↔G3) | Checklist §10.3 |

**Checkpoint:** app com dados reais + offline + segunda sessão de review.

### Etapa 3 (Aulas 13-14)

**Foco:** IA e gamificação.

| # | Item | Detalhe |
|---|------|---------|
| 3.1 | Edge Functions configuradas | CLI local, secrets (OPENAI_API_KEY), deploy |
| 3.2 | Sugestão de carga via IA | Histórico 4 semanas → LLM → recomendação |
| 3.3 | Assistente de substituição | Busca estruturada + fallback LLM |
| 3.4 | Rate limiting da IA | Máx 1 chamada/exercício/semana |
| 3.5 | Gamificação (streaks) | Drift local: dias de treino + meta de água |
| 3.6 | Code Review cruzado (todos) | Checklist §10.3 |

**Checkpoint:** IA integrada demonstrada.

### Etapa 4 (Aulas 15-16 → Entrega A2)

**Foco:** Fechamento, testes, publicação.

| # | Item | Detalhe |
|---|------|---------|
| 4.1 | Testes unitários | UseCases + Repositories (mocktail) |
| 4.2 | Testes de widget | Telas principais (ProviderScope overrides) |
| 4.3 | Testes de integração | Drift `:memory:` + Supabase local |
| 4.4 | Privacy Policy + Data Safety | URL pública, form Play Console |
| 4.5 | Account deletion completo | In-app + web resource |
| 4.6 | Keystore + .aab | key.properties, R8, `flutter build appbundle` |
| 4.7 | Credenciais de teste p/ revisor | Conta teste dedicada no Play Console |
| 4.8 | Ajustes finais UI/UX | Micro-interações, HapticFeedback |
| 4.9 | Revisão final + merge | Checklist §10.3 |
| 4.10 | Demonstração final | App completo + IA + .aab |

**Entrega A2 (Aula 17):** app completo. **Paralelo:** iniciar closed testing (12 testadores × 14 dias) assim que o .aab existir.

---

## 8. Integração de IA

### 8.1 Stack (Decisão D3 — Cloud)

- **Supabase Edge Functions** (Deno/TypeScript)
- **LLM:** OpenAI (GPT-4o-mini) — mais barato, suficiente para análise de histórico
- Chave da API **somente nas secrets do Supabase** (`supabase secrets set OPENAI_API_KEY=...`)
- Chamada do Flutter via `supabase.functions.invoke('suggest-load')`

### 8.2 Limites do plano free (importante)

| Recurso | Limite |
|---------|--------|
| Funções | 100 por projeto |
| Memória | 256MB |
| Timeout | 150s (wall clock) |
| CPU time | **2s efetivo** |
| Tamanho bundle | 20MB |
| Invocações aninhadas | 5000/min |

> **Ação:** a Edge Function só faz query + prompt + chamada HTTP (CPU leve). Sem processamento pesado.

### 8.3 Fluxo de Sugestão de Carga

```
1. Usuário finaliza treino (ou abre o próximo treino)
2. Flutter → supabase.functions.invoke('suggest-load', {exerciseId})
3. Edge Function: SELECT histórico (4 semanas) do exercise_sets
4. Monta prompt estruturado (JSON) → OpenAI (gpt-4o-mini)
5. Retorna JSON: {suggest_increase: bool, recommendation: "...", next_target: {...}}
6. App exibe badge/sugestão na tela de execução
```

### 8.4 Exemplo de Edge Function

```typescript
// supabase/functions/suggest-load/index.ts
import { serve } from "https://deno.land/std@0.210.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const { exercise_id } = await req.json()
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!)
  const auth = req.headers.get("Authorization")!
  const { data: { user }, error: userErr } = await supabase.auth.getUser(auth.replace("Bearer ", ""))
  if (userErr || !user) return new Response("unauthorized", { status: 401 })

  const { data: sets } = await supabase
    .from("exercise_sets")
    .select("weight_kg, reps, created_at")
    .eq("exercise_id", exercise_id)
    .order("created_at", { ascending: false })
    .limit(20)

  const llmResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content:
        `Histórico (últimas sessões): ${JSON.stringify(sets)}. ` +
        `Sugira se o usuário deve aumentar peso/repetições no próximo treino. ` +
        `Responda JSON: {"suggest_increase":bool,"recommendation":"...","next_weight_kg":number|null,"next_reps":number|null}` }]
    })
  })
  const data = await llmResponse.json()
  return new Response(JSON.stringify(data.choices[0].message.content), {
    headers: { "Content-Type": "application/json" }
  })
})
```

### 8.5 Custos estimados

- GPT-4o-mini: ~$0.15/1M input, ~$0.60/1M output
- 1 sugestão/dia × 100 usuários ≈ $0.10–0.30/dia — aceitável
- Mitigação: rate limit (1/exercício/semana) no app + Edge Function

---

## 9. Publicação na Play Store

### 9.1 Pré-requisitos (checklist)

- [ ] Conta de desenvolvedor Google Play (USD 25)
- [ ] Keystore de assinatura (`.jks`) — **nunca commitar**
- [ ] Privacy policy em URL pública (sem PDF/geofencing)
- [ ] Data Safety form preenchido (obrigatório mesmo sem coleta)
- [ ] Account deletion in-app + web resource
- [ ] Closed testing: **12 testadores × 14 dias contínuos**
- [ ] Credenciais de teste para o revisor

### 9.2 Data Safety Form — o que declarar

| Dado | Categoria |
|------|-----------|
| Nome, email, data de nascimento | Personal info |
| User ID | Personal info → User IDs |
| Peso, treinos, consumo de água | Health and fitness → **Fitness info** |
| Interações | App activity |
| Crash logs | App info and performance |

Propósitos: App functionality, Account management, Developer communications.  
Criptografia em trânsito: **Yes (HTTPS)**. Mecanismo de exclusão: **Yes**.

### 9.3 Permissões Android (confirmadas)

**Necessárias:**
| Permissão | Motivo |
|-----------|--------|
| INTERNET | Padrão Flutter |
| POST_NOTIFICATIONS (13+) | Lembretes — runtime via permission_handler |
| SCHEDULE_EXACT_ALARM (12+) | Lembretes agendados — runtime, não restricted |
| RECEIVE_BOOT_COMPLETED | Reagendar após reboot |

**NÃO necessárias (confirmado na pesquisa):** BODY_SENSORS, ACTIVITY_RECOGNITION, localização, Health Connect.

### 9.4 Configuração nativa Android

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>

<!-- Deep link para auth (supabase_flutter) -->
<activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="olimpus" android:host="auth"/>
    </intent-filter>
</activity>

<!-- Receivers de notificação agendada -->
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
```

### 9.5 Configuração iOS

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>olimpus</string></array>
    </dict>
</array>
```
`AppDelegate.swift`: delegar `UNUserNotificationCenter.current().delegate`.

### 9.6 Keystore + .aab

```bash
# 1. Gerar keystore (fora do repo!)
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 2. android/key.properties (gitignored)
# storePassword=..., keyPassword=..., keyAlias=upload, storeFile=.../upload-keystore.jks

# 3. Build
flutter build appbundle --release   # R8 já ativo por padrão
```

- versionCode/versionName vêm do `pubspec.yaml` (`version: 0.1.0+1`)
- **Play App Signing recomendado** (Google gerencia a chave de assinatura)
- Registrar fingerprint da app signing key se usar APIs Google (Maps, OAuth)

### 9.7 Closed Testing (contas pós-13/11/2023)

1. Criar **Google Group** com os emails dos testadores
2. Play Console → Testing → Closed testing → adicionar grupo
3. Enviar .aab e ativar faixa
4. Manter **12 testadores opt-in por 14 dias contínuos**
5. Aplicar para produção (questionário de readiness + resumo do feedback)
6. Revisão ~7 dias → produção

> **Estratégia:** iniciar o closed testing assim que o .aab da Etapa 2 existir (roda em paralelo com Etapa 3-4).

### 9.8 Armadilhas de rejeição

| Causa | Prevenção |
|-------|-----------|
| Crash na inicialização | Testar exaustivamente antes do envio |
| Login quebrado | Credenciais de teste válidas no Play Console |
| Funcionalidade insuficiente | App com valor real, sem placeholder |
| Dados de saúde sem privacy policy | PP pública + Data Safety coerente |
| Account deletion ausente | Fluxo in-app + web resource |
| Data Safety inexato | Declarar exatamente o que o app faz |
| Teste fechado insuficiente | 12 testadores ativos por 14 dias |

---

## 10. Fluxo de Trabalho e Code Review

### 10.1 Fluxo Git

```
main ←── merge de PRs com aprovação
  └── feat/<n>-<descricao>  (ex: feat/5-auth-signup)
  └── fix/<n>-<descricao>
  └── chore/<descricao>
```

### 10.2 Convenções

| Elemento | Convenção |
|----------|-----------|
| Branch | `feat/<numero>-<slug>`, `fix/<numero>-<slug>` |
| Commit | `feat:`, `fix:`, `docs:`, `refactor:`, `chore:` |
| PR | ≥1 aprovação de outro membro |
| Labels | `🔱 olimpus`, `⌛ todo`, `🚧 feat/fix/refactoring/docs/maintenance` |

### 10.3 Code Review Checklist (aplicar em todo PR)

- [ ] Feature isolada (nada de código de outra feature no PR)
- [ ] Camadas respeitadas (UI não acessa DataSource)
- [ ] Interface de Repository no Domain, impl no Data
- [ ] Providers Riverpod usados para DI (`ref.watch`), sem get_it
- [ ] `AsyncValue` para operações assíncronas (sem `catch` solto)
- [ ] Erros tratados (`AsyncValue.guard`), sem exceções vazando pra UI
- [ ] Drift usado para offline; `synced`/`SyncQueue` corretos
- [ ] Supabase: RLS + grants considerados (nada de service_role no client)
- [ ] Sem segredos (chaves) no código — só em secrets/vars de ambiente
- [ ] flutter_lints limpo, testes incluídos quando aplicável

---

## 11. Distribuição de Tarefas

| Membro | Features / Áreas |
|--------|------------------|
| **Ítalo** | Arquitetura (core/, Drift, sync), Supabase (migração, RLS, seed), IA (Edge Functions), revisão |
| **Matheus** | Feature auth (toda), Riverpod providers, router + auth guard |
| **Alêkson** | Features exercise + workout (catálogo, fichas, execução) |
| **Gustavo** | Feature water (hidratação), notificações, cronômetro, tema |
| **Danilo** | Feature progress (gráficos, calendário, streaks), testes |

> ⚠️ Cada membro commita regularmente em suas branches — a nota individual considera o histórico de commits.

---

## 12. Cronograma

| Aula | Data | Atividade | Etapa |
|------|------|-----------|-------|
| 1-5 | 05/08–02/09 | Disciplina, proposta, seminários G1-G3 | ✅ |
| 6 | 09/09 | **Seminário Grupo 4 — Arquitetura** (nosso) | 📅 |
| 7-8 | pós 09/09 | Etapa 1 + Code Review cruzado | 🔴 |
| 9 | TBD | **Entrega A1** | 🔴 |
| 10-12 | pós A1 | Etapa 2 (offline, água, gráficos) + seminários IA | 🔴 |
| 13-14 | pós Etapa 2 | Etapa 3 (IA) | 🔴 |
| 15-16 | pós Etapa 3 | Etapa 4 (testes, .aab, publicação) | 🔴 |
| 17 | TBD | **Entrega A2** | 🔴 |

---

## 13. Backlog de Issues (GitHub)

### Etapa 1 (A1)

| # | Issue | Tipo | Resp. |
|---|-------|------|-------|
| 1 | Setup Flutter + pubspec final + scaffold feature-first | chore | Ítalo |
| 2 | Supabase: migração 001 (tabelas, grants, RLS, índices, triggers) | feat | Ítalo |
| 3 | Seed free-exercise-db no Supabase | feat | Alêkson |
| 4 | Auth: signup/login/logout + confirmação de email | feat | Matheus |
| 5 | Auth: deep links nativos (AndroidManifest + Info.plist) | feat | Matheus |
| 6 | Auth: recuperação de senha | feat | Matheus |
| 7 | Biblioteca de exercícios (lista + busca + cache Drift) | feat | Alêkson |
| 8 | CRUD de fichas de treino | feat | Alêkson |
| 9 | Execução de treino: registro de séries + contraste anterior | feat | Ítalo |
| 10 | Router go_router + auth guard | feat | Matheus |
| 11 | Tema M3 + dark/light | chore | Gustavo |
| 12 | Setup Drift (AppDatabase, tabelas, migrations) | chore | Ítalo |
| 13 | Code Review cruzado Etapa 1 | chore | Todos |

### Etapa 2

| # | Issue | Tipo | Resp. |
|---|-------|------|-------|
| 14 | Sync offline-first (SyncQueue + connectivity flush) | feat | Ítalo |
| 15 | Persistência cloud completa (sessions/sets) | feat | Ítalo |
| 16 | Módulo de hidratação (barra + adição rápida) | feat | Gustavo |
| 17 | Histórico diário de hidratação | feat | Gustavo |
| 18 | Cronômetro de descanso | feat | Gustavo |
| 19 | Volume total automático | feat | Alêkson |
| 20 | Gráfico de evolução (fl_chart) | feat | Danilo |
| 21 | Calendário de treinos | feat | Danilo |
| 22 | Tratamento global de erros (Dio + AsyncValue) | feat | Matheus |
| 23 | Notificações de hidratação + permissões runtime | feat | Gustavo |
| 24 | Code Review cruzado Etapa 2 | chore | Todos |

### Etapa 3

| # | Issue | Tipo | Resp. |
|---|-------|------|-------|
| 25 | Edge Functions: setup + secrets + deploy | feat | Ítalo |
| 26 | Sugestão de carga via IA + rate limit | feat | Ítalo |
| 27 | Assistente de substituição de exercícios | feat | Ítalo |
| 28 | Streaks de treino e hidratação | feat | Danilo |
| 29 | Code Review cruzado Etapa 3 | chore | Todos |

### Etapa 4

| # | Issue | Tipo | Resp. |
|---|-------|------|-------|
| 30 | Testes unitários (UseCases/Repositories) | feat | Danilo |
| 31 | Testes de widget (telas principais) | feat | Danilo |
| 32 | Testes de integração (Drift :memory: + Supabase local) | feat | Danilo |
| 33 | Privacy Policy + Data Safety form | docs | Ítalo |
| 34 | Account deletion (in-app + web resource) | feat | Matheus |
| 35 | Keystore + .aab release | chore | Ítalo |
| 36 | Credenciais de teste p/ revisor no Play Console | chore | Todos |
| 37 | Ajustes finais UI/UX | feat | Gustavo |
| 38 | Revisão final + merge | chore | Todos |

### Manutenção

| # | Issue | Tipo |
|---|-------|------|
| 39 | Limpar issues de teste (#1, #2 do repo) | chore |
| 40 | CI/CD GitHub Actions (lint + test + analyze) | chore |
| 41 | Documentar setup do projeto (README) | docs |

---

## 14. Riscos e Mitigações

| Risco | Prob. | Impacto | Mitigação |
|-------|-------|---------|-----------|
| Commit gigante no final | Alta | Crítico | Commits frequentes por feature desde o início |
| Ambiente Flutter não configurado em membros | Média | Alto | Workshop de setup no início da Etapa 1 |
| Offline-first complexo atrasa MVP | Média | Alto | SyncQueue simples (LWW); iterar na Etapa 2 |
| Rate limit de email Supabase (2/h) | Média | Médio | SMTP próprio (SendGrid/SES) ou ambiente local CLI |
| Closed testing 14 dias atrasa A2 | Média | Alto | Iniciar na Etapa 2, em paralelo com Etapa 3-4 |
| Custo de LLM descontrolado | Baixa | Médio | Rate limit 1/exercício/semana + GPT-4o-mini |
| Notificações bloqueadas por OEMs chineses | Média | Baixo | Usar AlarmManager exato + documentar limitações |
| Divergência arquitetural entre membros | Média | Alto | Code Review frequente + template feature definido |
| WSL/Qdrant (dev tooling) parar | Média | Baixo | Keep-alive WSL; restart rápido documentado |

---

## 15. Decisões Pendentes

| # | Decisão | Opções | Prazo |
|---|---------|--------|-------|
| D7 | SMTP para emails de auth | SendGrid vs AWS SES vs Supabase default (2/h) | Início Etapa 1 |
| D8 | Cor primária do tema | Definir com base nas referências de design (imagens) | Início Etapa 1 |
| D9 | Horário dos lembretes de água | Fixo (ex: 8h-22h) vs configurável | Etapa 2 |
| D10 | Gamificação: local ou remoto | Drift local (recomendado) vs Supabase + pg_cron | Etapa 3 |
| D11 | Análise das referências de design | Trocar para modelo com visão e descrever as 3 imagens | Antes do tema |

---

## Anexo: pubspec.yaml Final

```yaml
name: olimpus
description: "App de saúde e fitness: treinos de musculação + hidratação"
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter

  # Estado + DI (Riverpod é o container de DI — sem get_it)
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^2.6.0

  # Navegação
  go_router: ^14.0.0

  # Backend
  supabase_flutter: ^2.8.0

  # HTTP
  dio: ^5.7.0

  # Serialização
  json_annotation: ^4.9.0
  freezed_annotation: ^2.4.0

  # Gráficos
  fl_chart: ^1.2.0

  # Offline database
  drift: ^2.34.4
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0

  # Rede
  connectivity_plus: ^7.3.1

  # Notificações
  flutter_local_notifications: ^22.3.0
  permission_handler: ^13.0.1
  flutter_timezone: ^2.0.0
  timezone: ^0.9.4

  # Cache de imagens
  cached_network_image: ^3.4.0

  # Utilitários
  intl: ^0.19.0
  equatable: ^2.0.0
  shimmer: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
  freezed: ^2.5.0
  riverpod_generator: ^2.6.0
  riverpod_lint: ^3.0.0
  drift_dev: ^2.34.4
  mocktail: ^1.0.0

flutter:
  uses-material-design: true
```

---

> **Este é o documento de implementação canônico.** Substitui o `PLANO_DESENVOLVIMENTO.md` como guia de execução.  
> **Próximo passo:** (1) revisão em grupo, (2) fechar D7-D11, (3) iniciar Etapa 1 — issues 1-4.