# Olimpus

[![CI](https://github.com/Projetos-Moveis-II-2026-2/grupo-04/actions/workflows/ci.yml/badge.svg?branch=dev)](https://github.com/Projetos-Moveis-II-2026-2/grupo-04/actions/workflows/ci.yml)

Aplicativo mobile que reúne o **controle de treinos de musculação** e o **monitoramento de hidratação** em um só lugar. Desenvolvido em **Flutter** com **Supabase** como backend, com foco em uso *offline-first*: os registros são gravados primeiro no banco local (Drift/SQLite) e sincronizados quando há conexão.

Projeto da disciplina **Programação para Dispositivos Móveis II** (Grupo 4).

## Sumário

1. [Sobre o projeto](#sobre-o-projeto)
2. [Integrantes](#integrantes)
3. [Funcionalidades e status](#funcionalidades-e-status)
4. [Pré-requisitos e dependências](#pré-requisitos-e-dependências)
5. [Como executar](#como-executar)
6. [Supabase local, migrações e Edge Functions](#supabase-local-migrações-e-edge-functions)
7. [Geração de código, testes e CI](#geração-de-código-testes-e-ci)
8. [Arquitetura](#arquitetura)
9. [Build de produção (.aab)](#build-de-produção-aab)
10. [Como contribuir](#como-contribuir)
11. [Documentação](#documentação)

---

## Sobre o projeto

### O problema

A gestão autônoma de treinos e de hábitos de saúde costuma ser fragmentada e pouco visual. Quem treina tem dificuldade para:

- lembrar com exatidão as cargas, séries e repetições dos treinos anteriores;
- enxergar, por meio de gráficos e dados, onde está evoluindo ou estagnando;
- aplicar a sobrecarga progressiva de forma sistemática;
- manter a disciplina com a ingestão diária de água, de acordo com metas individuais;
- concentrar a rotina de saúde (treino e hidratação) em uma única interface, de preenchimento rápido durante o exercício.

O Olimpus substitui anotações soltas, planilhas improvisadas e o uso de vários aplicativos por um registro estruturado e sincronizado entre dispositivos.

### Público-alvo

Praticantes de atividades físicas, especialmente musculação, de todos os níveis, e pessoas que querem construir o hábito de se hidratar:

- **Iniciantes:** têm dificuldade de manter a constância e de lembrar cargas e exercícios; precisam de um sistema simples e visual, com dados rápidos de ler e apoio ao hábito da hidratação.
- **Intermediários e avançados:** praticantes assíduos que aplicam a sobrecarga progressiva e precisam registrar o histórico exato do desempenho de forma ágil, com gráficos para evitar estagnação.
- **Foco em saúde e rotina:** pessoas que buscam praticidade, sem múltiplos aplicativos, e precisam de lembretes e de uma interface única para cumprir a meta diária de água.

### Diferenciais propostos

- Unir a principal variável de esforço (carga e sobrecarga) e a principal de recuperação (água) em uma única interface.
- Registro de baixo atrito, pensado para ser preenchido em poucos segundos durante o treino.
- Contraste imediato com o desempenho anterior, sem depender da memória.
- Sugestões de carga e de substituição de exercícios por IA, processadas em Edge Functions.

> Os diferenciais acima vêm da proposta do app. O que já está implementado no código está detalhado em [Funcionalidades e status](#funcionalidades-e-status).

---

## Integrantes

**Grupo 4**

| Nome | GitHub |
|------|--------|
| Alêkson Castro | `@aleksoncastro` |
| Gustavo Oliveira da Silva | `@gustavo-oli-silva` |
| Ítalo Emannuel Beckman | `@italobeckman` |
| Matheus Alexandre Ferreira Nardi | `@Matheus-Nardi` |

---

## Funcionalidades e status

Status conferido no código de `lib/` (telas, widgets e serviços efetivamente referenciados pelo app), e não apenas no estado das issues.

- **Pronto:** implementado e acessível ao usuário no app.
- **Parcial:** existe parte da implementação, mas falta integração ou algum requisito da proposta.
- **Pendente:** não implementado.

| Funcionalidade | Status | Situação verificada no código |
|----------------|--------|-------------------------------|
| Autenticação | Pronto | Cadastro, confirmação de e-mail pendente, login, logout, recuperação e redefinição de senha (deep link `olimpus://auth/*`) e exclusão de conta pela Edge Function `delete-account`. |
| Onboarding e perfil | Pronto | Tela de configuração inicial (nome, peso e meta diária de água) obrigatória no primeiro acesso; perfil salvo no Supabase. |
| Navegação e tema | Pronto | `go_router` com redirecionamento por autenticação e onboarding; barra inferior com Início, Treinos, Exercícios e Progresso; tema claro/escuro; configurações (tema, vibração, som de feedback, meta de água, sair, excluir conta). |
| Biblioteca de exercícios | Pronto (catálogo local) | Lista com busca e filtro por grupo muscular, detalhes e textos em pt-BR. O catálogo vem dos assets `assets/data/exercises.json` e `exercises_pt.json` (classe `ExerciseRemoteDataSourceFake`) e é guardado em cache no Drift; o app não lê a tabela `exercise_library` do Supabase. |
| Hidratação | Pronto | Registro rápido (+250 ml, +500 ml e valor livre), remoção, meta diária editável, total do dia, gráfico semanal e histórico. Gravação no Drift com enfileiramento na `SyncQueue`. |
| Treino livre | Parcial | Escolha de exercício, registro de séries (carga e repetições), timer de descanso fixo de 1 minuto e conclusão do treino. A gravação é feita **apenas no Drift**: `FreeWorkoutRepository` não enfileira nada na `SyncQueue`, então os treinos não sobem para o Supabase. |
| Fichas de treino (templates) | Pendente | A aba Treinos lista apenas o "Treino livre". A rota `/workout/:id` é um placeholder ("Detalhes da ficha de treino"); não há tela para criar, editar ou executar fichas. Existem só a tabela `workout_templates` e o pull inicial do Supabase. |
| Progresso | Pronto | Sequência (streak), calendário mensal, resumo do mês e gráfico de evolução de carga por exercício, lidos do Drift. Os dados dependem de treinos registrados. O gerador de dados de demonstração só aparece em modo debug. |
| Sincronização offline | Parcial | `SyncQueue` com retry e backoff exponencial, dreno automático ao reconectar e pull inicial do Supabase. Em produção, **somente `water_intake` é enfileirado**; treinos não. |
| IA: sugestão de carga | Parcial | Backend pronto (Edge Function `suggest-load`, `AiDatasource`, `suggestionProvider`) e o widget `LoadSuggestionBadge` existe, mas **nenhuma tela o utiliza**. |
| IA: substituição de exercício | Parcial | Backend pronto (RPC `find_substitutes`, Edge Function `suggest-substitute`, `substitutesProvider`) e `showSubstitutionSheet` existe, mas **nenhuma tela o chama**. |
| Notificações e lembretes | Pendente | `flutter_local_notifications`, `permission_handler`, `flutter_timezone` e `timezone` estão no `pubspec.yaml`, mas não são importados em nenhum arquivo de `lib/`. Não há lembretes de água nem de treino. |

---

## Pré-requisitos e dependências

### Ferramentas

| Ferramenta | Versão | Observação |
|------------|--------|------------|
| Flutter | **3.47.2** | Versão fixada em [`.fvmrc`](.fvmrc). |
| Flutter (mínimo do `pubspec.yaml`) | `^3.44.0` | Restrição `environment.flutter`. |
| Dart SDK (mínimo do `pubspec.yaml`) | `^3.13.0` | Vem com o Flutter. |
| JDK | 17 | `build.gradle.kts` usa `JavaVersion.VERSION_17`. |
| Android SDK | `compileSdk 37` | Instalável pelo Android Studio. |
| Android Studio ou Android SDK Platform-Tools | — | Necessário para o `adb`. |
| [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) | 3.2.0 no CI | Só para rodar o backend local. Exige Docker. |
| [scrcpy](https://github.com/Genymobile/scrcpy) | — | Opcional, para espelhar a tela do celular. |

Para usar a versão exata do projeto com o [FVM](https://fvm.app/), rode `fvm install` na raiz e prefixe os comandos com `fvm` (por exemplo, `fvm flutter run`).

> O CI (`.github/workflows/ci.yml` e `integration.yml`) usa Flutter 3.47.4. Localmente, siga o `.fvmrc` (3.47.2).

### Dependências principais

Versões conforme o [`pubspec.yaml`](pubspec.yaml).

| Pacote | Versão | Finalidade |
|--------|--------|------------|
| `flutter_riverpod` | `^3.0.0` | Gerenciamento de estado e injeção de dependência. |
| `riverpod_annotation` | `^4.0.0` | Anotações do Riverpod. |
| `go_router` | `^14.0.0` | Navegação declarativa, rotas aninhadas e redirecionamentos por autenticação. |
| `supabase_flutter` | `^2.8.0` | Autenticação, banco Postgres, RPC e Edge Functions. |
| `drift` | `^2.34.4` | Banco local SQLite para uso offline e `SyncQueue`. |
| `sqlite3_flutter_libs` | `^0.5.0` | Binários do SQLite para o Drift. |
| `path_provider` | `^2.1.0` | Localização do arquivo do banco local. |
| `shared_preferences` | `^2.5.0` | Preferências simples (tema, meta de água, estado de sincronização). |
| `connectivity_plus` | `^7.3.1` | Detecta a conexão para drenar a fila de sincronização. |
| `dio` | `^5.7.0` | Cliente HTTP com interceptors de erro e retry. Configurado em `core/network/`; as features ainda não o consomem. |
| `fl_chart` | `^1.2.0` | Gráficos de água e de evolução de carga. |
| `cached_network_image` | `^3.4.1` | Cache das imagens dos exercícios. |
| `intl` | `^0.19.0` | Formatação de datas e números em pt-BR. |
| `equatable` | `^2.0.0` | Igualdade por valor nas entidades. |
| `json_annotation`, `freezed_annotation` | `^4.9.0`, `^3.1.0` | Serialização e modelos imutáveis. |
| `shimmer` | `^3.0.0` | Declarada; ainda não usada em `lib/`. |
| `flutter_local_notifications`, `permission_handler`, `flutter_timezone`, `timezone` | `^22.3.0`, `^13.0.1`, `^5.1.0`, `^0.11.0` | Notificações locais. Declaradas; **ainda não usadas em `lib/`**. |

Desenvolvimento: `build_runner`, `drift_dev` (geração do código do Drift), `mocktail` (mocks), `flutter_lints` e `riverpod_lint` (análise estática). Também constam `json_serializable`, `freezed` e `riverpod_generator`.

---

## Como executar

### 1. Clonar e instalar dependências

```bash
git clone https://github.com/Projetos-Moveis-II-2026-2/grupo-04.git
cd grupo-04
flutter pub get
```

### 2. Backend

O app usa um **projeto Supabase já configurado**. A URL e a *publishable key* (pública por design) ficam em [`lib/core/constants/api_endpoints.dart`](lib/core/constants/api_endpoints.dart). Não é preciso criar conta nem arquivo `.env` para rodar o app.

Para apontar o app para um Supabase local, veja [Supabase local, migrações e Edge Functions](#supabase-local-migrações-e-edge-functions).

### 3. Rodar em emulador, desktop ou web

```bash
flutter devices
flutter run
```

### 4. Rodar em um celular Android físico

> **Use o modo debug.** O build de release exige a keystore de assinatura própria e falha sem o `android/key.properties` (veja [Build de produção](#build-de-produção-aab)).

1. No celular, ative as **Opções do desenvolvedor** (Configurações > Sobre o telefone > toque várias vezes em "Número da versão").
2. Em Opções do desenvolvedor, ative a **Depuração USB**.
3. Conecte o celular ao computador por cabo USB e autorize a depuração quando o aparelho pedir.
4. Confirme que o dispositivo foi reconhecido:

   ```bash
   adb devices
   ```

   O aparelho deve aparecer com o estado `device`. Se aparecer `unauthorized`, aceite o pedido de autorização na tela do celular.
5. Execute o app direto no aparelho:

   ```bash
   flutter run
   ```

   Com mais de um dispositivo conectado, escolha um com `flutter run -d <id>` (o id aparece em `flutter devices`).

**Alternativa: gerar e instalar o APK de debug**

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

A flag `-r` reinstala o app mantendo os dados já existentes.

**Espelhar a tela com scrcpy (opcional)**

Com o celular conectado e a depuração USB ativa, rode:

```bash
scrcpy
```

Isso exibe e permite controlar a tela do aparelho no computador, útil para demonstrações e gravações.

---

## Supabase local, migrações e Edge Functions

A configuração fica em [`supabase/config.toml`](supabase/config.toml) (`project_id = "grupo-04"`). O stack local sobe Postgres, Auth, Studio e as Edge Functions via Docker.

### Subir o stack e aplicar migrações

```bash
# Sobe o stack local (API em http://127.0.0.1:54321, Studio em http://127.0.0.1:54323)
supabase start

# Recria o banco local aplicando todas as migrações de supabase/migrations/
supabase db reset

# Mostra URLs e chaves do ambiente local
supabase status
```

Migrações em [`supabase/migrations/`](supabase/migrations/):

| Migração | Conteúdo |
|----------|----------|
| `20260906230337_initial_schema.sql` | Tabelas `profiles`, `exercise_library`, `workout_templates`, `template_exercises`, `workout_sessions`, `exercise_sets` e `water_intake`, com políticas de RLS. |
| `20260906231952_seed_exercises.sql` | Seed da biblioteca de exercícios (free-exercise-db). |
| `20260907020000_fix_seed_encoding.sql` | Reparo de encoding do seed no banco remoto. |
| `20260907024331_ai_rate_limits.sql` | Tabela `ai_rate_limits` (limite de uso das funções de IA). |
| `20260907030000_handle_new_user.sql` | Função `handle_new_user()`, que cria o perfil ao cadastrar um usuário. |
| `20260907035000_find_substitutes.sql` | Função `find_substitutes()` para sugerir substitutos. |
| `20260907040000_grants_repair.sql` | Reparo de permissões. |
| `20260915180000_fix_profiles_cascade.sql` | Ajuste de cascade em `profiles`. |

**Seed:** a carga inicial de exercícios é aplicada pela própria migração `20260906231952_seed_exercises.sql`. Os arquivos em [`supabase/seed/`](supabase/seed/) (`exercises.json` e o gerador `import-exercises.ps1`) são a origem desse seed; o `config.toml` aponta para `./seed.sql`, arquivo que não existe no repositório.

### Catálogo de exercícios em pt-BR

A tabela `public.exercise_library` guarda os nomes e as instruções em pt-BR
em `name` e `instructions`. As colunas `name_en` e `instructions_en`
preservam o original em inglês. A função `suggest-substitute` usa
`name_en` para localizar sugestões e devolve o nome em português quando
encontra o exercício no catálogo.

Para reproduzir a migration da issue #124 a partir de
`assets/data/exercises_pt.json`:

```bash
dart run tool/translation/generate_supabase_migration.dart
git diff --exit-code supabase/migrations
```

O gerador recria a migration inicial de tradução. Para mudanças depois que a
migration já estiver publicada, crie uma migration nova.

### Edge Functions

Funções Deno em [`supabase/functions/`](supabase/functions/), com **JWT de usuário obrigatório** (`verify_jwt = true` no `supabase/config.toml` + `auth: ["user"]` no handler):

| Função | Finalidade |
|--------|------------|
| `hello-world` | Teste de autenticação e de presença dos secrets. |
| `suggest-load` | Sugestão de carga com base no histórico de séries (LLM Gemini). |
| `suggest-substitute` | Sugestão de exercícios substitutos (LLM Gemini). |
| `delete-account` | Exclusão da conta do usuário autenticado (usa `service_role` no servidor). |

```bash
# Rodar local (precisa do stack local: supabase start)
supabase functions serve hello-world

# Testar localmente (Bearer = access_token de um usuário autenticado)
curl -i -X POST 'http://127.0.0.1:54321/functions/v1/hello-world' \
  -H 'apikey: <publishable_key>' \
  -H "Authorization: Bearer <user_jwt>" \
  --data '{"name":"Olimpus"}'
# Sem Bearer → 401; com Bearer válido → 200

# Deploy no remoto
npx supabase@latest functions deploy hello-world
```

**Secrets** (server-side, nunca no código): `GEMINI_API_KEY` (IA, provedor Gemini Flash-Lite, free tier). Configure com `supabase secrets set GEMINI_API_KEY=...`; dentro da função: `Deno.env.get("GEMINI_API_KEY")`. Liste sem expor valores com `supabase secrets list`.

---

## Geração de código, testes e CI

### Geração de código (build_runner)

O código do banco Drift é gerado por `drift_dev`. O único arquivo gerado hoje, `lib/core/database/app_database.g.dart`, é versionado. Regere-o sempre que alterar as tabelas em `lib/core/database/tables/` ou o `AppDatabase`:

```bash
dart run build_runner build --delete-conflicting-outputs

# Ou, durante o desenvolvimento, regenerando a cada alteração
dart run build_runner watch --delete-conflicting-outputs
```

### Testes

Os testes unitários e de widget ficam em `test/`, espelhando a estrutura de `lib/`.

```bash
# Todos os testes
flutter test

# Com relatório de cobertura (gera coverage/lcov.info)
flutter test --coverage

# Verifica a cobertura mínima de 60% em lib/features/*/domain/
dart run tool/coverage_check.dart
```

O script [`tool/coverage_check.dart`](tool/coverage_check.dart) lê `coverage/lcov.info`, calcula a cobertura de linhas por arquivo de `lib/features/*/domain/` e encerra com erro se o total ficar abaixo de **60%**.

### Testes de integração

Os testes de `test/integration/` exercitam a fila offline do Drift e, quando há um Supabase local, autenticação, sincronização com o Postgres e isolamento por RLS entre usuários. A parte Drift-only roda sempre; os testes de Supabase são pulados automaticamente quando `SUPABASE_TEST_URL` e `SUPABASE_TEST_ANON_KEY` não estão definidas.

```bash
# Sobe o stack local e exporta as credenciais de teste
supabase start
eval "$(supabase status -o env)"
export SUPABASE_TEST_URL="${API_URL:-$SUPABASE_URL}"
export SUPABASE_TEST_ANON_KEY="${ANON_KEY:-$PUBLISHABLE_KEY}"

flutter test test/integration/
```

No CI ([`.github/workflows/integration.yml`](.github/workflows/integration.yml)), o Supabase local sobe automaticamente em pull requests para `dev` e `main`.

### Verificação local antes do PR (comandos do CI)

O workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em todo `pull_request` e `push` para `main` e `dev`. Para reproduzi-lo localmente:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze --fatal-infos
flutter test --coverage --exclude-tags integration
```

Se a formatação falhar, corrija com `dart format lib test`. Detalhes e configuração do gate de merge em [`docs/CI.md`](docs/CI.md).

---

## Arquitetura

O projeto segue a abordagem **feature-first**, inspirada em Clean Architecture. Cada funcionalidade em `lib/features/` é dividida em três camadas:

- **`presentation/`:** telas (pages), widgets e providers/notifiers do Riverpod.
- **`domain/`:** entidades, contratos de repositório (interfaces) e casos de uso. Não depende de Flutter, Supabase nem Drift.
- **`data/`:** implementações dos repositórios, datasources (Supabase, Drift, assets) e acesso externo.

Decisões principais:

- **Riverpod** é o gerenciador de estado **e** o container de injeção de dependência (não há `get_it`).
- **Repository Pattern:** os repositórios têm contratos no domínio (por exemplo, `IAuthRepository`, `IWaterRepository`) e implementações em `data/`. Há exceções ainda não adequadas: `free_workout_page.dart`, `load_suggestion_badge.dart` e `substitution_sheet.dart` importam classes de `data/` diretamente.
- **go_router** centraliza a navegação em `lib/router/app_router.dart`, com redirecionamentos por estado de autenticação e de onboarding, e `StatefulShellRoute` para a barra de navegação inferior.
- **Offline-first com Drift e SyncQueue:** as escritas vão primeiro para o SQLite local; operações sincronizáveis entram na tabela `sync_queue` e são enviadas ao Supabase em ordem (FIFO), com retry e backoff exponencial, ao reconectar. Na inicialização, o `InitialSyncService` faz o pull inicial dos dados do usuário.
- **Supabase** fornece autenticação, Postgres com RLS, RPC e Edge Functions.

```text
.
├── lib/
│   ├── main.dart                  # Inicializa Supabase, SharedPreferences e o ProviderScope
│   ├── app.dart                   # MaterialApp.router, tema e bindings de sincronização
│   ├── router/                    # go_router e barra de navegação inferior
│   ├── core/
│   │   ├── constants/             # URL e chave pública do Supabase, constantes do app
│   │   ├── database/              # Drift: AppDatabase, tabelas, conexões e sync/ (SyncQueue)
│   │   ├── errors/                # Exceções do app
│   │   ├── network/               # Dio, interceptors e conectividade
│   │   ├── providers/             # Providers compartilhados (Supabase, Dio, tema, rede)
│   │   ├── theme/                 # Cores e temas claro/escuro
│   │   ├── utils/                 # Validadores, UUID, feedback de UI
│   │   └── widgets/               # Widgets reutilizáveis
│   └── features/
│       ├── auth/                  # Cadastro, login, recuperação de senha, configurações
│       ├── profile/               # Onboarding e perfil do usuário
│       ├── exercise/              # Biblioteca de exercícios e substituição por IA
│       ├── workout/               # Treino livre e sugestão de carga por IA
│       ├── water/                 # Hidratação
│       └── progress/              # Sequência, calendário e gráficos de evolução
│           └── {data,domain,presentation}/
├── test/                          # Testes (core, features, router, integration)
├── supabase/
│   ├── config.toml
│   ├── migrations/                # Schema, RLS, seed e funções SQL
│   ├── functions/                 # Edge Functions (Deno)
│   └── seed/                      # Origem do seed de exercícios
├── assets/data/                   # Catálogo de exercícios (en e pt-BR)
├── tool/                          # Scripts de desenvolvimento (cobertura, dados de exercícios)
├── docs/                          # Documentação do projeto
├── android/ ios/ web/ linux/ macos/ windows/
└── .github/workflows/             # CI (ci.yml) e testes de integração (integration.yml)
```

---

## Build de produção (.aab)

O `applicationId` (e o `namespace`) do app Android é `br.unitins.olimpus`. O build `release` em `android/app/build.gradle.kts` é assinado com a configuração `release`, lida de `android/key.properties`. **Não há fallback para a chave de debug:** se `android/key.properties` não existir (ou estiver incompleto, ou apontar para um `.jks` inexistente), qualquer tarefa Gradle de release (por exemplo `flutter build appbundle --release`) falha com uma mensagem explicando o que falta. Debug, `flutter analyze`, testes e o CI não são afetados.

> A keystore e o `key.properties` **nunca** devem ser versionados (já estão no `.gitignore`) nem compartilhados em chats, issues ou PRs. Este fluxo é a configuração prevista na issue [#57](https://github.com/Projetos-Moveis-II-2026-2/grupo-04/issues/57); a geração e o teste do `.aab` em um aparelho ou no teste fechado ainda precisam ser feitos por quem tem a keystore.

### 1. Gerar a keystore de upload

Gere a keystore **fora do repositório** (por exemplo, em um diretório seguro do seu usuário), com o alias `upload`:

```bash
keytool -genkey -v -keystore <caminho-seguro>/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

O `keytool` vem com o JDK e pergunta as senhas e os dados do certificado. Anote as senhas em um gerenciador de senhas.

### 2. Criar o `android/key.properties`

Crie o arquivo `android/key.properties` (ignorado pelo Git) com este formato, trocando os placeholders pelos seus valores:

```properties
storePassword=<senha-da-keystore>
keyPassword=<senha-da-chave>
keyAlias=upload
storeFile=<caminho-absoluto-para>/upload-keystore.jks
```

Use um caminho absoluto em `storeFile` (um caminho relativo é resolvido a partir de `android/app/`).

### 3. Fazer backup da keystore

Guarde uma cópia do `.jks` e das senhas em local seguro e separado (gerenciador de senhas ou cofre da equipe). Sem a chave de upload, é preciso pedir o reset da chave de upload ao Google Play. O uso do **Play App Signing** é recomendado: o Google guarda a chave de assinatura final e você assina o envio apenas com a chave de upload.

### 4. Definir a versão

`versionCode` e `versionName` do app Android vêm do campo `version` do [`pubspec.yaml`](pubspec.yaml), no formato `versionName+versionCode` (por exemplo, `1.0.0+1`). Incremente o número após o `+` a cada envio à Play Store, pois ele não pode se repetir.

### 5. Gerar o `.aab`

```bash
flutter build appbundle --release
```

O arquivo é gerado em `build/app/outputs/bundle/release/app-release.aab`. O R8 (minificação) já fica ativo no build de release por padrão.

Para testar em um aparelho sem a keystore, use o APK de debug descrito em [Como executar](#como-executar).

---

## Como contribuir

Antes de implementar qualquer issue, leia o [`docs/WORKFLOW_IA.md`](docs/WORKFLOW_IA.md). Resumo do fluxo:

1. **`dev` é a branch de integração.** Toda branch nasce de `dev` e volta para `dev` por Pull Request. A `main` só recebe merge em marcos de entrega.
2. **Nome da branch:** `<tipo>/<numero-da-issue>-<slug-curto>`, com `tipo` em `feat`, `fix`, `chore`, `test`, `docs` ou `refactor`. Exemplo: `docs/59-readme`.
3. **Commits** no padrão Conventional Commits, citando a issue: `<tipo>(<escopo>): <descrição> (#N)`.
4. **Antes do PR**, rode os comandos do CI (veja [Verificação local](#verificação-local-antes-do-pr-comandos-do-ci)).
5. **Pull Request para `dev`** referenciando a issue (`Closes #N`). Todo PR passa por **code review cruzado**: pelo menos uma pessoa diferente do autor deve revisar antes do merge.
6. Não use `git push --force` em `dev` ou `main`, e nunca versione segredos (keystore, `.env`, chaves de API).

---

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [`docs/WORKFLOW_IA.md`](docs/WORKFLOW_IA.md) | Fluxo de trabalho: branches, commits, verificação e merge. |
| [`docs/CI.md`](docs/CI.md) | Integração contínua e gate de merge. |
| [`docs/BACKLOG_ISSUES_PROPOSTA.md`](docs/BACKLOG_ISSUES_PROPOSTA.md) | Backlog de issues, mapa backlog para GitHub e templates de comentários. |
| [`docs/PLANO_IMPLEMENTACAO.md`](docs/PLANO_IMPLEMENTACAO.md) | Arquitetura, uso do Supabase e etapas de desenvolvimento. |
| [`docs/ANALISE_REQUISITOS_GAPS.md`](docs/ANALISE_REQUISITOS_GAPS.md) | Análise de requisitos, gaps e pontos de atenção técnica. |
| [`docs/PLANO_TRADUCAO_EXERCICIOS.md`](docs/PLANO_TRADUCAO_EXERCICIOS.md) | Plano de tradução do catálogo de exercícios para pt-BR. |
| [`docs/Projeto-Disciplina.md`](docs/Projeto-Disciplina.md) | Escopo e visão geral do projeto para a disciplina. |
| [`docs/design-references/`](docs/design-references/) | Imagens de referência de design. |
