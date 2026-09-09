# Proposta de Backlog — Issues Olimpus

> **Status:** ✅ CRIADO no GitHub (46 issues: #20–#65). Números do GitHub ≠ números deste documento (backlog), porque o repositório já tinha issues #1–#19 fechadas.
> **Formato de issue:** título em conventional commits `tipo(escopo): descrição` + seções Objetivo / Contexto / Critérios de Aceite / Comando de Verificação / Arquivos Prováveis
> **Fluxo:** cada issue pertence a uma branch agrupada (uma branch pode resolver várias issues correlatas). Ao resolver, comentar na issue o bloco padrão (template no fim).
> **Dependências:** indicadas como `Depende de: #N` (texto simples, sem formalismo). A regra é: não inicia issue da Onda N+1 antes de mergear a issue da Onda N que ela depende. Não há grafo de dependências no GitHub.

### Mapa backlog → GitHub

| Backlog | GitHub | | Backlog | GitHub | | Backlog | GitHub |
|---------|--------|-|---------|--------|-|---------|--------|
| #1 | #20 | | #15 | #34 | | #29 | #48 |
| #2 | #21 | | #16 | #35 | | #30 | #49 |
| #3 | #22 | | #17 | #36 | | #31 | #50 |
| #4 | #23 | | #18 | #37 | | #32 | #51 |
| #5 | #24 | | #19 | #38 | | #33 | #52 |
| #6 | #25 | | #20 | #39 | | #34 | #53 |
| #7 | #26 | | #21 | #40 | | #35 | #54 |
| #8 | #27 | | #22 | #41 | | #36 | #55 |
| #9 | #28 | | #23 | #42 | | #37 | #56 |
| #10 | #29 | | #24 | #43 | | #38 | #57 |
| #11 | #30 | | #25 | #44 | | #39 | #58 |
| #12 | #31 | | #26 | #45 | | #40 | #59 |
| #13 | #32 | | #27 | #46 | | C1–C6 | #60–#65 |
| #14 | #33 | | #28 | #47 | | | |

---

## 0. Legenda de Streams e Correlação

| Dev | GitHub | Stream (correlação) | Issues | Branches agrupadas |
|-----|--------|---------------------|--------|--------------------|
| **Ítalo** | `italobeckman` | Core/Backend/IA — fundação do app, banco, sync, Supabase, inteligência | 1–9 | 4 branches |
| **Matheus** | `Matheus-Nardi` | Auth/Estado — identidade, permissões, navegação, erros globais | 10–17 | 3 branches |
| **Alêkson** | `aleksoncastro` | Exercícios/Treino — catálogo, fichas, execução, cronômetro | 18–24 | 3 branches |
| **Gustavo** | `gustavo-oli-silva` | Hidratação/UX — água, notificações, tema, micro-interações | 25–31 | 3 branches |
| **Danilo** | *(sem assignee)* | Progresso/QA/Publicação — gráficos, gamificação, testes, release | 32–40 | 3 branches |

> **Assignees (03/09/2026):** Ítalo, Matheus, Alêkson e Gustavo recebem as issues dos seus streams. **As issues do Danilo (#32–#40) ficam SEM assignee por enquanto** — o stream (gráficos, streaks, testes, CI, release) será distribuído ou assumido quando ele entrar.

---

## 1. Mapa de Branches (agrupamento por correlação)

| Branch | Issues | Dev | Sprint provável |
|--------|--------|-----|-----------------|
| `feat/1-2-fundacao-scaffold-drift` | #1, #2 | Ítalo | Sprint 1 |
| `feat/3-4-supabase-migracao-seed` | #3, #4 | Ítalo | Sprint 1 |
| `feat/5-6-sync-offline-cloud` | #5, #6 | Ítalo | Sprint 2 |
| `feat/7-9-ia-edge-functions` | #7, #8, #9 | Ítalo | Sprint 3 |
| `feat/10-13-auth-fluxo-completo` | #10, #11, #12, #13 | Matheus | Sprint 1 |
| `feat/14-15-router-erros-globais` | #14, #15 | Matheus | Sprint 1 |
| `feat/16-17-providers-perfil-onboarding` | #16, #17 | Matheus | Sprint 2 |
| `feat/18-19-biblioteca-fichas` | #18, #19 | Alêkson | Sprint 1 |
| `feat/20-22-execucao-treino` | #20, #21, #22 | Alêkson | Sprint 2 |
| `feat/23-24-detalhe-filtros-exercicios` | #23, #24 | Alêkson | Sprint 2 |
| `feat/25-26-hidratacao` | #25, #26 | Gustavo | Sprint 2 |
| `feat/27-28-notificacoes-tema` | #27, #28 | Gustavo | Sprint 2 |
| `feat/29-31-microinteracoes-meta-skeletons` | #29, #30, #31 | Gustavo | Sprint 3 |
| `feat/32-34-evolucao-gamificacao` | #32, #33, #34 | Danilo | Sprint 2–3 |
| `test/35-37-suite-de-testes` | #35, #36, #37 | Danilo | Sprint 4 |
| `chore/38-40-release-ci-docs` | #38, #39, #40 | Danilo | Sprint 4 |

---

## 2. Issues por Stream

### Stream Ítalo — Core/Backend/IA

#### #1 — `chore(core): scaffold do projeto Flutter com pubspec final e estrutura feature-first`

## Objetivo
Criar o projeto Flutter Olimpus com o pubspec corrigido (v2.0) e a estrutura de pastas feature-first (`lib/features/`).

## Contexto
- Base atual é o template Hello World (`lib/main.dart`), sem dependências além de `flutter`.
- O pubspec final (Anexo do `docs/PLANO_IMPLEMENTACAO.md`) corrige versões obsoletas (fl_chart ^1.2.0, flutter_local_notifications ^22.3.0, etc.) e adota Riverpod como DI (sem get_it).
- Decisões aprovadas: D1 feature-first, D2 Riverpod, D4 go_router, D6 offline (Drift).
- **Depende de:** — (fundação, sem dependências)

## Critérios de Aceite
- [ ] `pubspec.yaml` substituído pelo anexo do plano (todas as dependências corrigidas)
- [ ] `lib/features/` com auth, workout, exercise, water, progress (data/domain/presentation)
- [ ] `lib/core/` com constants, network, theme, utils
- [ ] `flutter pub get` sem conflito de versões
- [ ] `flutter analyze` sem erros

## Comando de Verificação
`flutter pub get && flutter analyze`

## Arquivos Prováveis
- `pubspec.yaml`
- `lib/` (estrutura completa)
- `analysis_options.yaml`

---

#### #2 — `chore(core): setup do Drift (AppDatabase, tabelas, migrations e SyncQueue)`

## Objetivo
Configurar o banco local SQLite type-safe (Drift) como base do offline-first, com as tabelas espelhando o modelo do Supabase e a fila de sincronização.

## Contexto
- Decisão D6: offline-first completo desde o MVP.
- Tabelas: exercise_sets, workout_sessions, workout_templates, exercise_library, water_intake + SyncQueue.
- Cada registro precisa de metadados (`synced`, `updatedAt`, `localId`/`remoteId`) para LWW e deduplicação.
- **Depende de:** #1 (scaffold do projeto)

## Critérios de Aceite
- [ ] `AppDatabase` com as 6 tabelas e colunas de metadados
- [ ] `MigrationStrategy` com versões (`schemaVersion`)
- [ ] Provider `appDatabaseProvider` (singleton Riverpod)
- [ ] `dart run build_runner build` gera as classes drift sem erro
- [ ] Banco abre em app e em testes (`NativeDatabase.memory()`)

## Comando de Verificação
`dart run build_runner build && flutter test`

## Arquivos Prováveis
- `lib/core/database/app_database.dart`
- `lib/core/database/tables/*.dart`
- `lib/core/database/app_database.g.dart` (gerado)

---

#### #3 — `feat(supabase): migração 001 — tabelas, grants, RLS, índices e triggers`

## Objetivo
Criar e aplicar a migração inicial no Supabase com tabelas, revogação de grants padrão, políticas RLS por operação, índices e trigger de `updated_at`.

## Contexto
- Gap crítico corrigido (§4 da análise): grants `anon`/`authenticated` padrão dão acesso total — é preciso REVOKE + grants mínimos além das policies.
- Tabelas: profiles, exercise_library, workout_templates, template_exercises, workout_sessions, exercise_sets, water_intake.
- Índices em FK e `(user_id, started_at)`, `(user_id, date)` para as queries do app.
- **Depende de:** #1 (scaffold do projeto)

## Critérios de Aceite
- [ ] Migração aplicada no projeto Supabase (`supabase db push`)
- [ ] Grants revogados e reaplicados conforme §5.1 do plano
- [ ] RLS habilitado em todas as tabelas com policies por operação
- [ ] Índices e trigger `set_updated_at()` criados
- [ ] `supabase test db` passa

## Comando de Verificação
`supabase db push && supabase test db`

## Arquivos Prováveis
- `supabase/migrations/001_init.sql`

---

#### #4 — `feat(supabase): seed da biblioteca de exercícios via free-exercise-db`

## Objetivo
Importar os 800+ exercícios do dataset público free-exercise-db (Unlicense) na tabela `exercise_library`.

## Contexto
- Decisão D5: importar o dataset no Postgres em vez de consumir API externa (sem key, sem rate limit, sem indisponibilidade).
- Campos a mapear: external_id, name, force, level, mechanic, equipment, primary_muscles[], secondary_muscles[], instructions[], category.
- Imagens ficam acessíveis via `raw.githubusercontent.com`.
- **Depende de:** #3 (migração Supabase — tabela exercise_library)

## Critérios de Aceite
- [ ] Script de seed criado e executável (NDJSON → `\copy`/psql ou função)
- [ ] Contagem ~800+ validada
- [ ] Amostra de registros com arrays corretos
- [ ] `SELECT` público funciona (policy de leitura pública)

## Comando de Verificação
`SELECT count(*) FROM exercise_library; -- esperado >= 800`

## Arquivos Prováveis
- `supabase/seed/exercises_import.sql` (ou script auxiliar)
- `supabase/seed/exercises.ndjson`

---

#### #5 — `feat(core): sync offline-first com SyncQueue e detecção de conexão`

## Objetivo
Implementar a fila de sincronização: operações locais marcadas `synced: false` são enfileiradas e enviadas ao Supabase quando a conexão retorna.

## Contexto
- Academia tem sinal fraco — escrita local imediata é obrigatória (D6).
- Padrão LWW: última escrita vence via `updated_at`.
- `connectivity_plus` detecta reconexão para flush automático com retry/backoff.
- **Depende de:** #2 (Drift com SyncQueue)

## Critérios de Aceite
- [ ] Escrita offline persiste no Drift e entra na SyncQueue
- [ ] Flush automático ao reconectar (FIFO, por tabela: upsert/delete)
- [ ] Retry com `retryCount` e backoff
- [ ] Registro marcado `synced: true` após sucesso
- [ ] Sem perda de dados ao matar o app durante o flush

## Comando de Verificação
Teste manual: modo avião → registrar série → reconectar → verificar registro no Supabase.

## Arquivos Prováveis
- `lib/core/database/sync/sync_queue_service.dart`
- `lib/core/network/connectivity_service.dart`

---

#### #6 — `feat(core): persistência cloud completa com pull inicial e deduplicação`

## Objetivo
Garantir que sessions/sets sincronizados voltem a um novo dispositivo (pull inicial) sem duplicar registros.

## Contexto
- Após reinstalar ou logar em outro aparelho, o app deve baixar o histórico do usuário.
- Deduplicação por `remoteId`; conflito LWW na direção remoto→local.
- **Depende de:** #3 (migração), #5 (sync engine)

## Critérios de Aceite
- [ ] Pull inicial baixa sessions/sets/água do Supabase para o Drift
- [ ] Nenhum registro duplicado após re-sync (idempotência)
- [ ] Sessão criada no aparelho A aparece no aparelho B após login
- [ ] Indicador de "sincronizando" na UI

## Comando de Verificação
Fluxo em 2 emuladores com a mesma conta → criar treino em um, validar no outro.

## Arquivos Prováveis
- `lib/core/database/sync/sync_queue_service.dart`
- Repositórios de workout/water

---

#### #7 — `chore(infra): configurar Edge Functions com secrets e deploy`

## Objetivo
Habilitar o ambiente de Edge Functions do Supabase (Deno/TypeScript) com secrets protegidas e pipeline de deploy.

## Contexto
- A chave do LLM **nunca** vai no cliente Flutter — vive nas secrets do Supabase.
- Limites do plano free: 150s timeout, 2s CPU time efetivo, 256MB memória — a função deve ser leve.
- **Depende de:** #1 (scaffold), #3 (migração — base de dados)

## Critérios de Aceite
- [ ] `supabase functions` funcionando localmente (CLI)
- [ ] Secrets configuradas (`supabase secrets set OPENAI_API_KEY=...`)
- [ ] Função de exemplo deployada e invocável pelo app (`supabase.functions.invoke`)
- [ ] Auth JWT validado na função (usuário não autenticado → 401)

## Comando de Verificação
`supabase functions deploy suggest-load && curl -X POST ...` (com token de usuário)

## Arquivos Prováveis
- `supabase/functions/`
- `supabase/config.toml`

---

#### #8 — `feat(ia): sugestão de carga baseada em histórico via LLM`

## Objetivo
Implementar a Edge Function `suggest-load`: analisa o histórico do exercício e recomenda peso/reps do próximo treino.

## Contexto
- Requisito da disciplina (Etapa 3). O plano prevê GPT-4o-mini para custo baixo.
- A função lê `exercise_sets` das últimas 4 semanas, monta prompt estruturado e devolve JSON.
- Rate limit: máx. 1 chamada/exercício/semana para conter custo.
- **Depende de:** #6 (persistência cloud), #7 (Edge Functions)

## Critérios de Aceite
- [ ] Edge Function consulta histórico com RLS respeitada (auth.uid)
- [ ] Resposta JSON tipada: `{suggest_increase, recommendation, next_weight_kg, next_reps}`
- [ ] Rate limit implementado (client + server)
- [ ] Fallback gracioso se o LLM falhar/timeout
- [ ] UI exibe a sugestão na tela de execução do treino

## Comando de Verificação
`supabase functions serve` + teste no app com histórico real de 2+ treinos.

## Arquivos Prováveis
- `supabase/functions/suggest-load/index.ts`
- `lib/features/workout/presentation/` (badge de sugestão)

---

#### #9 — `feat(ia): assistente de substituição de exercícios`

## Objetivo
Permitir ao usuário perguntar "como substituir o exercício X?" e receber alternativas com equipamento compatível.

## Contexto
- Substituição = mesmo grupo muscular (`primaryMuscles`) com equipamento diferente.
- Estratégia em camadas: consulta estruturada primeiro; LLM como fallback se não houver match (reduz custo).
- **Depende de:** #4 (seed de exercícios), #7 (Edge Functions)

## Critérios de Aceite
- [ ] Busca estruturada por grupo muscular + equipamento alternativo
- [ ] Fallback LLM quando a busca estruturada não retorna resultados
- [ ] Resposta mostra exercícios substitutos com imagens
- [ ] Rate limit compartilhado com a sugestão de carga

## Comando de Verificação
Selecionar exercício "supino com barra" → sugerir alternativas com halteres.

## Arquivos Prováveis
- `supabase/functions/substitute-exercise/index.ts`
- `lib/features/exercise/presentation/`

---

### Stream Matheus — Auth/Estado

#### #10 — `feat(auth): signup/login/logout com confirmação de email no Supabase`

## Objetivo
Implementar o fluxo completo de autenticação por email/senha (cadastro, login, logout) com confirmação de email.

## Contexto
- Supabase Auth exige confirmação de email em projetos hosted — o app precisa tratar o estado "confirmação pendente".
- PKCE obrigatório para mobile (`AuthFlowType.pkce`); sessão persiste via secure storage.
- Estado da sessão via provider Riverpod escutando `authStateChanges`.
- **Depende de:** #1 (scaffold), #16 (providers base)
- **Estratégia:** pode começar com mock de `IAuthRepository` antes do Supabase ficar pronto

## Critérios de Aceite
- [ ] `signUp(email, password, emailRedirectTo: 'olimpus://auth/callback')`
- [ ] `signInWithPassword` e logout funcionando
- [ ] Tela de "confirmação pendente" + reenvio de email
- [ ] Sessão persiste entre aberturas do app
- [ ] Tela de login e registro com validação e estados de erro

## Comando de Verificação
Fluxo manual: cadastrar → confirmar email → logar → deslogar → relogar (emulador).

## Arquivos Prováveis
- `lib/features/auth/data/`, `domain/`, `presentation/`
- `lib/main.dart` (inicialização Supabase)

---

#### #11 — `feat(auth): deep links nativos para o fluxo de auth`

## Objetivo
Configurar deep linking nativo (Android + iOS) para que os links de confirmação de email e reset de senha abram o app.

## Contexto
- Sem deep link, o usuário fica preso no navegador (gap §3.2 da análise).
- Android: `CallbackActivity` com scheme `olimpus://auth`; iOS: `CFBundleURLTypes`.
- **Depende de:** #10 (auth — valida o fluxo completo com deep link)

## Critérios de Aceite
- [ ] AndroidManifest com intent-filter `olimpus://auth`
- [ ] Info.plist com `CFBundleURLSchemes = [olimpus]`
- [ ] Link de confirmação abre o app e conclui o fluxo
- [ ] Link de reset abre o fluxo de nova senha

## Comando de Verificação
`adb shell am start -a android.intent.action.VIEW -d "olimpus://auth/callback?code=..."` (emulador).

## Arquivos Prováveis
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

---

#### #12 — `feat(auth): recuperação de senha por email`

## Objetivo
Implementar o fluxo "esqueci minha senha": email → link → formulário de nova senha.

## Contexto
- `resetPasswordForEmail(email, redirectTo: 'olimpus://auth/reset-password')`; o link carrega o token que autoriza `updateUser(password)`.
- Mensagens anti-enumeração (não revelar se o email existe).
- **Depende de:** #10 (auth base), #11 (deep links)

## Critérios de Aceite
- [ ] Tela de solicitação de reset
- [ ] Deep link `reset-password` abre formulário de nova senha
- [ ] `updateUser` aplica a nova senha e redireciona ao login
- [ ] Feedback de sucesso/erro sem vazar existência de conta

## Comando de Verificação
Solicitar reset → abrir link no emulador → definir nova senha → logar com ela.

## Arquivos Prováveis
- `lib/features/auth/presentation/pages/reset_password_page.dart`
- `lib/features/auth/domain/usecases/`

---

#### #13 — `feat(auth): exclusão de conta com confirmação (in-app)`

## Objetivo
Permitir ao usuário excluir sua conta e dados de forma definitiva, direto no app.

## Contexto
- **Requisito Google Play**: app com criação de conta in-app precisa oferecer exclusão in-app + web resource (§9.7 do plano).
- A exclusão remove o `auth.users` e cascateia para profiles/sessions/sets/água (on delete cascade).
- **Depende de:** #10 (auth base), #7 (Edge Functions — função admin)

## Critérios de Aceite
- [ ] Tela "Excluir conta" com confirmação (digitar senha ou diálogo de confirmação)
- [ ] Chamada à Edge Function admin que deleta o auth user
- [ ] Dados locais (Drift) limpos após exclusão
- [ ] Logout forçado e redirecionamento ao splash
- [ ] Feedback claro do que será apagado

## Comando de Verificação
Criar conta de teste → excluir → verificar no Supabase que o user e dados sumiram.

## Arquivos Prováveis
- `lib/features/auth/presentation/pages/delete_account_page.dart`
- `supabase/functions/delete-account/index.ts`

---

#### #14 — `feat(nav): rotas go_router com redirect por autenticação`

## Objetivo
Implementar a navegação com go_router: splash → login/register → home (aba) e telas internas, com guarda de autenticação.

## Contexto
- Decisão D4: go_router (deep links prontos para auth e notificações).
- Router como provider Riverpod reagindo a `authStateChanges`.
- **Depende de:** #1 (scaffold), #10 (auth — estado de sessão)

## Critérios de Aceite
- [ ] Rotas: `/splash`, `/login`, `/register`, `/home`, `/workout`, `/exercises`, `/progress`, `/settings`
- [ ] Redirect: não autenticado → `/login`; autenticado → `/home`
- [ ] Bottom navigation (home) com abas
- [ ] Parâmetros de rota para id de treino/exercício

## Comando de Verificação
Sem token → abre login; com token → abre home. Deep links de auth caem nas rotas certas.

## Arquivos Prováveis
- `lib/router/app_router.dart`
- `lib/router/router_provider.dart`

---

#### #15 — `feat(core): tratamento global de erros (Dio interceptors + AsyncValue)`

## Objetivo
Padronizar o tratamento de erros em toda a app: erros de rede/API viram mensagens amigáveis com opção de retry.

## Contexto
- Riverpod 3.x expõe `AsyncValue` — usar `AsyncValue.guard` em vez de exceções soltas vazando pra UI.
- Dio interceptors centralizam timeout/retry/mapeamento de status HTTP.
- Widget de erro reutilizável com botão de tentar novamente.
- **Depende de:** #1 (scaffold) — pode começar em paralelo
- **Estratégia:** implementar contra `Dio` e `AsyncValue` padronizado; independente das features

## Critérios de Aceite
- [ ] Dio com interceptors (timeout, retry, mensagens por código HTTP)
- [ ] Todos os usecases assíncronos usam `AsyncValue.guard`
- [ ] Widget de erro padrão (mensagem + retry) nas telas com fetch
- [ ] Sem `catch` solto em widgets

## Comando de Verificação
Derruber a rede → abrir biblioteca de exercícios → ver mensagem amigável + retry funcionando.

## Arquivos Prováveis
- `lib/core/network/dio_client.dart`
- Widgets comuns de erro/loading

---

#### #16 — `feat(core): providers Riverpod base (auth, tema, conectividade)`

## Objetivo
Criar os providers globais de infraestrutura: Supabase client, Drift DB, tema (claro/escuro) e conectividade.

## Contexto
- Riverpod é o container de DI (D2) — datasources e serviços são providers singleton.
- Providers de app-wide: `supabaseClientProvider`, `appDatabaseProvider`, `themeProvider`, `connectivityProvider`.
- **Depende de:** #1 (scaffold), #2 (Drift — provider do banco)

## Critérios de Aceite
- [ ] `supabaseClientProvider` inicializado uma única vez
- [ ] `appDatabaseProvider` singleton com close correto
- [ ] `themeProvider` expõe ThemeMode claro/escuro
- [ ] `connectivityProvider` emite estado de rede (Stream)

## Comando de Verificação
`flutter test` com `ProviderContainer` criando e lendo os providers.

## Arquivos Prováveis
- `lib/core/providers.dart` (ou por pasta em core/)
- `lib/main.dart`

---

#### #17 — `feat(auth): onboarding e configuração inicial do perfil`

## Objetivo
Após o primeiro login, coletar dados iniciais do perfil: nome, peso, meta de água e nível de experiência.

## Contexto
- `profiles` estende `auth.users`; cria-se o registro na primeira configuração.
- Nível (`beginner|intermediate|advanced`) influencia sugestões da IA e metas padrão.
- **Depende de:** #10 (auth base), #16 (providers base)

## Critérios de Aceite
- [ ] Onboarding de 2–3 passos após primeiro login
- [ ] Criação/atualização de `profiles` no Supabase
- [ ] Campos validados (peso > 0, meta entre 500–5000ml)
- [ ] Pular onboarding só depois de concluído (flag local)

## Comando de Verificação
Novo usuário → onboarding → verificar registro em `profiles`.

## Arquivos Prováveis
- `lib/features/auth/presentation/pages/onboarding_page.dart`
- `lib/features/auth/data/`

---

### Stream Alêkson — Exercícios/Treino

#### #18 — `feat(exercise): listagem da biblioteca com busca e cache local`

## Objetivo
Tela da biblioteca de exercícios com agrupamento por grupo muscular, busca por nome e cache offline.

## Contexto
- Dados vêm da tabela `exercise_library` (seed do free-exercise-db) via Supabase; cache em Drift para leitura offline.
- Imagens via `cached_network_image` (base raw.githubusercontent).
- **Depende de:** #4 (seed de exercícios), #2 (cache Drift)
- **Estratégia:** começar contra mock/fake de `IExerciseRepository`; integrar com seed depois

## Critérios de Aceite
- [ ] Lista com filtro por grupo muscular (chips)
- [ ] Busca por nome (debounce)
- [ ] Cache Drift atualizado e lido offline
- [ ] Card com imagem + fallback placeholder
- [ ] Estado vazio e de erro tratados

## Comando de Verificação
Abrir biblioteca offline após primeiro uso → lista continua acessível.

## Arquivos Prováveis
- `lib/features/exercise/presentation/pages/exercises_page.dart`
- `lib/features/exercise/data/`

---

#### #19 — `feat(workout): CRUD de fichas de treino (templates)`

## Objetivo
Criar, listar, editar e excluir fichas de treino (`workout_templates` + `template_exercises`).

## Contexto
- Ficha = nome + exercícios ordenados com séries/reps alvo.
- RLS: apenas o dono manipula (política por `user_id`).
- **Depende de:** #18 (biblioteca de exercícios — para adicionar à ficha)

## Critérios de Aceite
- [ ] Criar ficha com nome/descrição
- [ ] Adicionar exercícios com sort_order, target_sets, target_reps
- [ ] Reordenar e remover exercícios da ficha
- [ ] Listar fichas do usuário (home)
- [ ] Exclusão com confirmação

## Comando de Verificação
Criar "Treino A" com 5 exercícios → editar → excluir; conferir no Supabase.

## Arquivos Prováveis
- `lib/features/workout/domain/`, `data/`, `presentation/pages/templates_page.dart`

---

#### #20 — `feat(workout): execução do treino — registro de séries com contraste da carga anterior`

## Objetivo
Tela principal de execução: iniciar sessão a partir de ficha, registrar séries (peso/reps/concluída) e mostrar a carga da última sessão lado a lado.

## Contexto
- Coração do app e da sobrecarga progressiva (requisito da proposta).
- Persistência local imediata (Drift, synced: false) + fila de sync; HapticFeedback ao concluir série.
- **Depende de:** #2 (Drift), #19 (fichas — para iniciar sessão), #3 (migração Supabase)
- **Estratégia:** UI contra `IWorkoutRepository` mock; troca pelo real quando #5/#6 mergearem

## Critérios de Aceite
- [ ] Iniciar sessão a partir de uma ficha
- [ ] Registrar séries com peso, reps e checkbox de conclusão
- [ ] Contraste: carga anterior do mesmo exercício lado a lado
- [ ] Ajuste rápido de peso/reps (+/-)
- [ ] Concluir sessão gera `workout_sessions.completed_at`

## Comando de Verificação
Treinar o mesmo exercício em 2 sessões → validar contraste e histórico.

## Arquivos Prováveis
- `lib/features/workout/presentation/pages/workout_page.dart`
- `lib/features/workout/presentation/widgets/set_card.dart`

---

#### #21 — `feat(workout): cálculo automático de volume total`

## Objetivo
Calcular e exibir o volume total da sessão (Σ peso × reps) por exercício e por treino.

## Contexto
- Volume alimenta o painel de evolução e a sugestão da IA.
- Persistir `total_volume_kg` na sessão ao concluir.
- **Depende de:** #20 (execução do treino — fonte dos dados)

## Critérios de Aceite
- [ ] Volume por exercício e total exibidos em tempo real na execução
- [ ] `total_volume_kg` salvo no fechamento da sessão
- [ ] Consistência com o histórico (somas corretas)

## Comando de Verificação
Treino com 3 exercícios → validar somatórios na tela e no banco.

## Arquivos Prováveis
- `lib/features/workout/domain/usecases/compute_volume.dart`

---

#### #22 — `feat(workout): cronômetro de descanso entre séries`

## Objetivo
Cronômetro configurável (30–180s) entre séries na tela de execução, com alerta ao finalizar.

## Contexto
- Feedback por vibração/som; sugestão: iniciar automaticamente ao concluir série (opcional via config).
- Barra de progresso visível; segue rodando se a tela sair de foco (timestamps, não `Timer` puro).
- **Depende de:** #20 (tela de execução do treino)

## Critérios de Aceite
- [ ] Iniciar/pausar/parar timer de descanso
- [ ] Alertas visuais + sonoros ao fim
- [ ] Configuração do tempo padrão nos settings

## Comando de Verificação
Concluir série → timer inicia → zerar mostra alerta.

## Arquivos Prováveis
- `lib/features/workout/presentation/widgets/rest_timer.dart`

---

#### #23 — `feat(exercise): tela de detalhe do exercício (instruções e equipamento)`

## Objetivo
Tela de detalhe com instruções passo a passo, músculos primários/secundários, equipamento, nível e imagens.

## Contexto
- `instructions[]` do dataset lista passos; imagens 0/1 do repositório raw.
- Permite "ver como faz" antes de executar — essencial para iniciantes.
- **Depende de:** #18 (biblioteca de exercícios — navegação e dados)

## Critérios de Aceite
- [ ] Exibir instruções numeradas
- [ ] Chips de músculos primários e equipamento
- [ ] Galeria simples de imagens com cache
- [ ] Botão "usar no treino" (adiciona à ficha ativa)

## Comando de Verificação
Abrir 3 exercícios distintos → campos corretos.

## Arquivos Prováveis
- `lib/features/exercise/presentation/pages/exercise_detail_page.dart`

---

#### #24 — `feat(exercise): filtros por grupo muscular, equipamento e nível`

## Objetivo
Refinar a biblioteca com filtros combináveis: grupo muscular, equipamento e nível de dificuldade.

## Contexto
- Campos do dataset: `primaryMuscles`, `equipment`, `level`. Filtro via query no Supabase ou local no cache.
- **Depende de:** #18 (biblioteca — lista base para filtrar)

## Critérios de Aceite
- [ ] Filtros combináveis e reset
- [ ] Contador de resultados
- [ ] Consulta eficiente (índice em `primary_muscles` se necessário)

## Comando de Verificação
Filtrar "peitoral + halter + iniciante" → lista coerente.

## Arquivos Prováveis
- `lib/features/exercise/data/`, `presentation/widgets/filter_sheet.dart`

---

### Stream Gustavo — Hidratação/UX

#### #25 — `feat(water): barra de progresso de hidratação com adição rápida`

## Objetivo
Widget da meta diária de água: barra de progresso, botões de adição rápida (+250/+500ml) e meta configurável.

## Contexto
- Meta padrão 2000ml (vem de `profiles.daily_water_goal_ml`).
- Escrita local imediata (Drift) + sync; consumo do dia agrupado por `date`.
- **Depende de:** #2 (Drift — tabela water_intake), #3 (migração), #16 (providers base)
- **Estratégia:** começar com `IWaterRepository` mock; integrar com sync depois

## Critérios de Aceite
- [ ] Barra de progresso (meta × consumido) atualizada em tempo real
- [ ] Botões +250ml / +500ml
- [ ] Meta configurável na tela de settings/perfil
- [ ] Reset diário correto por data local

## Comando de Verificação
Adicionar 1L → barra em 50% (meta 2L). Mudar meta → recalcular.

## Arquivos Prováveis
- `lib/features/water/presentation/widgets/water_progress_bar.dart`

---

#### #26 — `feat(water): histórico diário de consumo`

## Objetivo
Visualizar o consumo do dia (registros com hora) e resumo da última semana.

## Contexto
- Tabela `water_intake` com `recorded_at` e `date`. Dados locais primeiro, sincronizados depois.
- Base para o streak de hidratação (Danilo).
- **Depende de:** #25 (barra de hidratação — dados do dia)

## Critérios de Aceite
- [ ] Lista de registros do dia (hora + volume)
- [ ] Total diário + comparativo da semana (mini gráfico)
- [ ] Correto entre dias e com fuso local

## Comando de Verificação
Registrar em horários distintos → histórico coerente.

## Arquivos Prováveis
- `lib/features/water/presentation/pages/water_history_page.dart`

---

#### #27 — `feat(water): notificações de lembrete com permissões runtime`

## Objetivo
Lembretes locais periódicos de hidratação usando flutter_local_notifications com permissões Android 13+ tratadas.

## Contexto
- Android: POST_NOTIFICATIONS (13+), SCHEDULE_EXACT_ALARM (12+), RECEIVE_BOOT_COMPLETED + receivers no manifest.
- iOS: limite de 64 notificações agendadas → usar recorrência diária (`matchDateTimeComponents: time`).
- Timezone inicializada (flutter_timezone + timezone) para `zonedSchedule`.
- **Depende de:** #1 (scaffold — manifest configurado)

## Critérios de Aceite
- [ ] AndroidManifest com permissões e receivers (§9.4 do plano)
- [ ] Solicitação de permissão via permission_handler com estado tratado (negada → explicação)
- [ ] Lembrete recorrente diário (intervalo configurável, ex.: a cada 2h das 8h às 22h)
- [ ] Sobrevive a reboot (boot receiver)
- [ ] Ativar/desativar nos settings

## Comando de Verificação
Agendar lembrete → aguardar disparo (ou adiantar relógio no emulador) → reboot → lembrete persiste.

## Arquivos Prováveis
- `android/app/src/main/AndroidManifest.xml`
- `lib/features/water/data/notification_service.dart`

---

#### #28 — `chore(theme): tema Material 3 com claro/escuro`

## Objetivo
Tema M3 (`ColorScheme.fromSeed`) com modo claro/escuro persistido e tipografia definida.

## Contexto
- Flutter 3.11+ tem M3 nativo; apps modernos da Play Store usam M3 (gap §2.5 da análise).
- Cor primária: decidir com as referências de design (D8 pendente — analisar imagens).
- **Depende de:** — (100% independente; pode começar no dia 1)

## Critérios de Aceite
- [ ] `useMaterial3: true` + ColorScheme claro e escuro
- [ ] Alternância persistida (shared_preferences via themeProvider)
- [ ] Tipografia com escala definida
- [ ] Componentes M3 (NavigationBar, FilledButton, Card) nos fluxos principais

## Comando de Verificação
Alternar tema → reiniciar app → tema mantido.

## Arquivos Prováveis
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/app_colors.dart`

---

#### #29 — `feat(workout): micro-interações e feedback tátil`

## Objetivo
Feedback tátil/sonoro em ações-chave: concluir série (vibração), bater meta de água, iniciar timer.

## Contexto
- HapticFeedback nativo do Flutter (impact leve/médio) + opção de som.
- Melhora percepção de progresso durante o treino com as mãos ocupadas.
- **Depende de:** #20 (set_card), #25 (meta de água — feedback)

## Critérios de Aceite
- [ ] Vibração ao concluir série
- [ ] Feedback ao atingir 100% da meta de água
- [ ] Preferência "vibração on/off" nos settings

## Comando de Verificação
Concluir série em device físico → vibração perceptível.

## Arquivos Prováveis
- `lib/features/workout/presentation/widgets/set_card.dart`
- `lib/features/water/presentation/widgets/`

---

#### #30 — `feat(water): meta de água configurável com sugestão automática`

## Objetivo
Configuração da meta diária no perfil com sugestão automática baseada no peso corporal.

## Contexto
- Recomendação comum: ~35ml/kg. O app sugere ao informar o peso, permitindo ajuste manual.
- Meta persistida em `profiles.daily_water_goal_ml`.
- **Depende de:** #17 (onboarding/perfil), #25 (barra de hidratação)

## Critérios de Aceite
- [ ] Campo de meta manual (500–5000ml)
- [ ] Sugestão automática ao preencher peso (35ml/kg, arredondado)
- [ ] Valor sincronizado com o Supabase

## Comando de Verificação
Peso 80kg → sugestão 2800ml; aceitar e validar no perfil.

## Arquivos Prováveis
- `lib/features/auth/presentation/pages/onboarding_page.dart` (etapa de água)
- `lib/features/water/domain/usecases/`

---

#### #31 — `feat(core): estados de carregamento e skeleton`

## Objetivo
Padronizar feedback de carregamento: skeletons (shimmer) nas listas e overlays de progresso em ações.

## Contexto
- Telas que leem rede/Supabase precisam de estados visuais consistentes com AsyncValue.
- `shimmer` para listas; `AsyncValue.when` com loading padrão.
- **Depende de:** #1 (scaffold) — widgets compartilhados em core/

## Critérios de Aceite
- [ ] Skeleton nas listas (biblioteca, fichas, histórico)
- [ ] Overlay de progresso em ações de escrita (salvar treino, excluir conta)
- [ ] Sem flashes de tela branca entre navegações

## Comando de Verificação
Navegar entre telas com rede lenta (throttle) → skeletons visíveis.

## Arquivos Prováveis
- `lib/core/widgets/skeleton_list.dart`
- Widgets por feature

---

### Stream Danilo — Progresso/QA/Publicação

#### #32 — `feat(progress): gráfico de evolução de carga por exercício (fl_chart)`

## Objetivo
Gráfico de linha mostrando a evolução da carga máxima por exercício ao longo do tempo.

## Contexto
- fl_chart ^1.2.0 (versão corrigida — não 0.70).
- Carga máxima por sessão para o exercício selecionado; dados do Drift/Supabase.
- **Depende de:** #20 (dados de sets), #6 (persistência cloud — histórico multi-dispositivo)

## Critérios de Aceite
- [ ] Seleção de exercício → série temporal da carga máxima
- [ ] LineChart com tooltip (data/valor)
- [ ] Disposal correto (sem vazamento ao trocar de tela)
- [ ] Dados corretos após 2+ sessões do mesmo exercício

## Comando de Verificação
Treinar 3 vezes o supino com cargas crescentes → curva ascendente visível.

## Arquivos Prováveis
- `lib/features/progress/presentation/widgets/evolution_chart.dart`

---

#### #33 — `feat(progress): calendário de treinos realizados no mês`

## Objetivo
Calendário mensal destacando dias com treino concluído e resumo do mês.

## Contexto
- Dados de `workout_sessions.completed_at` por mês; navegação entre meses.
- Base visual para streaks e hábito.
- **Depende de:** #20 (sessões concluídas), #6 (persistência cloud)

## Critérios de Aceite
- [ ] Grade mensal com dias de treino marcados
- [ ] Navegação entre meses
- [ ] Contador de treinos do mês + volume total
- [ ] Estado vazio (nenhum treino no mês)

## Comando de Verificação
Concluir treinos em dias distintos → dias marcados no calendário.

## Arquivos Prováveis
- `lib/features/progress/presentation/widgets/workout_calendar.dart`

---

#### #34 — `feat(progress): streaks de treino e hidratação (gamificação)`

## Objetivo
Streak de dias consecutivos com treino concluído e com meta de água batida.

## Contexto
- Decisão D10 sugerida: calcular localmente em Drift (sem pg_cron no MVP).
- Regra de tolerância (ex.: streak não quebra com 1 dia de folga) a definir.
- **Depende de:** #33 (calendário de treinos), #26 (histórico de água)

## Critérios de Aceite
- [ ] Streak de treino (dias consecutivos com sessão concluída)
- [ ] Streak de hidratação (meta diária batida)
- [ ] Exibição no painel/home com recorde
- [ ] Cálculo local correto ao abrir o app em dias diferentes

## Comando de Verificação
Registrar treinos em dias consecutivos (ajustar data no emulador) → streak cresce.

## Arquivos Prováveis
- `lib/features/progress/domain/usecases/compute_streaks.dart`

---

#### #35 — `test: testes unitários de usecases e repositórios`

## Objetivo
Cobertura unitária das regras de negócio: usecases de auth/workout/water e cálculos (volume, streaks, meta).

## Contexto
- Mockar interfaces de repositório com mocktail; `ProviderContainer` para providers.
- Estratégia de testes por camada definida na análise de gaps (§10).
- **Depende de:** #1 (scaffold) — **começa primeiro (TDD), não por último**: testes escritos contra as interfaces quando as features mergearem

## Critérios de Aceite
- [ ] Usecases testados (sucesso + falha)
- [ ] Cálculos puros cobertos (volume, sugestão de meta, streaks)
- [ ] Providers testados com overrides
- [ ] Cobertura mínima definida no `lcov` (ex.: >60% em domain)

## Comando de Verificação
`flutter test --coverage && genhtml coverage/lcov.info`

## Arquivos Prováveis
- `test/` por feature

---

#### #36 — `test: testes de widget das telas principais`

## Objetivo
Testes de widget das telas críticas: login, biblioteca, execução de treino, hidratação, evolução.

## Contexto
- Usar `ProviderScope(overrides: ...)` para isolar dependências reais.
- Foco em fluxos de sucesso, estados vazios e de erro.
- **Depende de:** telas existirem (#10 auth, #18 biblioteca, #20 execução, #25 água) — escrever junto com cada feature

## Critérios de Aceite
- [ ] Widgets-chave renderizam e respondem a interações
- [ ] Estados de loading/erro/vazio cobertos
- [ ] Suite roda em CI sem flakes (pumpAndSettle com timeout)

## Comando de Verificação
`flutter test test/widget/`

## Arquivos Prováveis
- `test/widget/`

---

#### #37 — `test: testes de integração (Drift em memória + Supabase local)`

## Objetivo
Fluxos ponta a ponta com Drift `:memory:` e Supabase local (CLI): registrar treino offline → sync → validar no banco.

## Contexto
- Supabase CLI permite subir Postgres local para testes de RLS/integração.
- Drift suporta `NativeDatabase.memory()` — sem arquivo físico.
- **Depende de:** #3 (migração Supabase aplicada), #5 (sync engine)

## Critérios de Aceite
- [ ] Teste de integração auth + criação de sessão + sets
- [ ] Sync da fila validado contra Supabase local
- [ ] RLS: tentativa de acesso a dados de outro usuário bloqueada
- [ ] Pipeline de CI executa a suite de integração

## Comando de Verificação
`supabase start && flutter test test/integration/`

## Arquivos Prováveis
- `test/integration/`
- `supabase/` (config local)

---

#### #38 — `chore(pub): keystore, assinatura e build .aab de release`

## Objetivo
Configurar a assinatura de release (keystore .jks, key.properties) e gerar o `.aab` publicável.

## Contexto
- R8 ativo por padrão em release; versionCode/Name vêm do pubspec.
- Keystore **nunca** versionado; Play App Signing recomendado.
- Iniciar closed testing assim que o .aab existir (12 testadores × 14 dias roda em paralelo).
- **Depende de:** #1 (scaffold), features principais estáveis; roda no fim (Sprint 4)

## Critérios de Aceite
- [ ] Keystore gerado e armazenado fora do repo (com backup seguro)
- [ ] `android/key.properties` criado (gitignored)
- [ ] Signing configurado no Gradle (release)
- [ ] `flutter build appbundle --release` gera `app.aab`
- [ ] .aab instala/atualiza corretamente no teste fechado

## Comando de Verificação
`flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`

## Arquivos Prováveis
- `android/app/build.gradle.kts`
- `android/key.properties` (não versionado)

---

#### #39 — `chore(infra): CI/CD com lint, testes e análise estática`

## Objetivo
Pipeline de CI no GitHub Actions: `flutter analyze`, testes, geração de cobertura e validação de RLS (se aplicável).

## Contexto
- Qualidade mínima em todo PR: lint limpo + testes verdes.
- Reutilizar a matriz do fluxo de trabalho com convenções de branch/PR do grupo.
- **Depende de:** #1 (scaffold), #35 (suíte de testes existir) — pode subir o esqueleto cedo

## Critérios de Aceite
- [ ] Workflow dispara em PRs para `main`
- [ ] `flutter analyze` sem warnings
- [ ] Testes (unit/widget) verdes + cobertura reportada
- [ ] Gate: PR não mergeável se CI falhar

## Comando de Verificação
Abrir PR de teste → CI roda → status green.

## Arquivos Prováveis
- `.github/workflows/ci.yml`

---

#### #40 — `docs: README com setup do projeto e documentação de arquitetura`

## Objetivo
README com instruções de setup (Flutter, Supabase CLI, secrets), estrutura de pastas e links para os docs de plano/gaps.

## Contexto
- Membros novos/ambientes precisam subir o projeto em minutos; workshop de setup na Etapa 1.
- Documento vivo: apontar para `docs/PLANO_IMPLEMENTACAO.md` e `docs/ANALISE_REQUISITOS_GAPS.md`.
- **Depende de:** projeto estável (fim da Etapa 4) — redigir por último

## Critérios de Aceite
- [ ] Pré-requisitos e passo a passo de setup
- [ ] Como rodar o Supabase local e aplicar migração/seed
- [ ] Estrutura de pastas e comandos úteis (codegen, testes)
- [ ] Como gerar o .aab

## Comando de Verificação
Seguir o README num ambiente limpo → app roda.

## Arquivos Prováveis
- `README.md`

---

## 3. Issues de Coordenação (cross-stream, sem branch própria)

> Criadas como issues de acompanhamento por sprint; resolvidas dentro das branches dos respectivos devs (não abrem branch própria).

| # | Issue | Quando | Quem comenta |
|---|-------|--------|--------------|
| C1 | `chore(review): code review cruzado Etapa 1 (Sprint 1)` | Fim da Sprint 1 | Todos |
| C2 | `chore(review): code review cruzado Etapa 2 (Sprint 2)` | Fim da Sprint 2 | Todos |
| C3 | `chore(review): code review cruzado Etapa 3 (Sprint 3)` | Fim da Sprint 3 | Todos |
| C4 | `chore(pub): preencher Data Safety form + privacy policy (antes do .aab)` | Sprint 4 | Ítalo + Matheus |
| C5 | `chore(pub): conta de teste e credenciais para revisor do Play` | Sprint 4 | Todos |
| C6 | `chore(review): checklist final A2 (demo + .aab + revisão)` | Sprint 4 | Todos |

---

## 4. Template do Comentário de Resolução (colar na issue ao fechar)

```
**Sprint {N}** | Branch: `{branch}` | Commit: `{hash}`

## Resumo

{2–5 linhas: o que foi feito, decisões, desvios do plano}

## Validação

```bash
{comando(s) executados para comprovar}
```
```

**Exemplo real:**

```
**Sprint 48** | Branch: `fix/99-106-seguranca-auditoria-sprint48` | Commit: `c6c17a9`

## Resumo

`pyproject.toml` já declara `reportlab>=4.1.0` e `openpyxl>=3.1.0`. O `uv.lock` é gitignored (não versionado). Dockerfile usa `pip install ".[dev]"` — imagem contém as deps. Container: `reportlab 5.0.1`, `openpyxl 3.1.5`.

## Validação

docker compose exec app python -c "import reportlab; print(reportlab.Version); import openpyxl; print(openpyxl.__version__)"
```

---

> **Pós-criação:** 46 issues criadas no GitHub (#20–#65). Decisões ainda em aberto (não bloqueiam o backlog): D7 (SMTP do Supabase), D8 (cor primária do tema), D9 (agendamento das notificações), D10 (gamificação local/remota), D11 (análise das imagens de design — requer modelo com visão). As issues do stream do Danilo (#51–#59 no GitHub) ficaram sem assignee conforme combinado.
