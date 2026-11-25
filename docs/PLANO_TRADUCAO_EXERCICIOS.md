# Plano de Desenvolvimento — Tradução estática da biblioteca de exercícios (#102)

Issue: https://github.com/Projetos-Moveis-II-2026-2/grupo-04/issues/102
Branch: a do workspace atual (criada pelo Orca a partir de `dev`)

## 1. Contexto e decisões de arquitetura

O catálogo (free-exercise-db, 876 exercícios) é carregado de `assets/data/exercises.json` por
`ExerciseRemoteDataSourceFake` (`lib/features/exercise/data/datasources/exercise_remote_datasource_fake.dart`),
mapeado para `Exercise` e gravado uma única vez na tabela Drift `exercise_library`
(`ExerciseRepositoryImpl._performSync` retorna cedo se `hasExercises()`).

| # | Decisão | Motivo |
|---|---------|--------|
| D1 | **Overlay** `assets/data/exercises_pt.json` (`{ "<id>": { "name": "...", "instructions": ["...", ...] } }`), sem editar `exercises.json` | Mantém o dataset original intacto e permite reimportar upstream; `supabase/seed` não muda |
| D2 | Mesclar o overlay **no parse** (`_mapExerciseJson` / `parseExercisesFromJson` / `parseExercisesInChunks`); fallback para o texto original se faltar o id | Drift passa a guardar `name`/`instructions` já em pt-BR; busca por nome (`searchByName`, `filteredExercisesProvider`) funciona em português sem mudança |
| D3 | Campos curtos (`primaryMuscles`, `secondaryMuscles`, `level`, `equipment`, `mechanic`, `force`, `category`) **continuam em inglês nos dados** e são traduzidos **só na exibição** | O filtro de grupo muscular compara contra as chaves em inglês (`muscleGroupTranslation`); traduzir o dado quebraria o filtro e as consultas |
| D4 | Mapas de rótulos centralizados em `lib/features/exercise/presentation/utils/exercise_labels.dart` (fora dos widgets); fallback devolve o valor original capitalizado se a chave for desconhecida | Evita string solta nas telas e é testável |
| D5 | `schemaVersion` Drift **1 → 2**; no `onUpgrade` (`from < 2`) apagar **apenas** `exercise_library` | `syncExercises` só semeia com a tabela vazia; sem isso quem já instalou nunca receberia a tradução. Os `id`s são estáveis e `exercise_sets.exerciseId` é texto sem FK, então dados do usuário ficam intactos |
| D6 | Supabase (`seed`, `find_substitutes`, Edge Functions) **fora de escopo** | O sheet de substituição recebe nome em inglês da RPC; ver tarefa T6 (resolver o nome pelo catálogo local via `external_id`/`id`) |

## 2. Glossário (obrigatório em todas as traduções)

Usar sempre o mesmo termo. Manter em inglês só nomes consagrados no Brasil.

- Equipamento: barbell → barra; dumbbell → halter; cable → cabo/polia; machine → máquina; kettlebells → kettlebell; bands → elástico; e-z curl bar → barra W; medicine ball → medicine ball (bola medicinal na descrição); exercise ball → bola suíça; foam roll → rolo de espuma; body only → peso corporal; other → outro.
- Nomes: Squat → agachamento; Deadlift → levantamento terra; Bench Press → supino; Pull-Up → barra fixa; Chin-Up → barra fixa supinada; Push-Up → flexão de braço; Sit-Up/Crunch → abdominal; Curl → rosca; Row → remada; Lunge → avanço/afundo; Fly → crucifixo; Lat Pulldown → puxada; Shrug → encolhimento; Calf Raise → elevação de panturrilha; Plank → prancha; Stretch → alongamento; Press (ombros) → desenvolvimento; Raise → elevação; Kickback → coice; Dip → mergulho; Clean/Snatch/Jerk → manter (arremesso/arranque/arremesso conforme contexto, citando o termo em inglês entre parênteses só na 1ª ocorrência se ambíguo).
- Instruções: imperativo, 2ª pessoa do singular implícita ("Deite-se...", "Segure a barra...", "Repita..."), frases curtas, mesma quantidade de passos que o original, números/repetições preservados.
- Preservar nomes próprios (ex.: Zottman, Arnold, Romanian → "romeno" apenas em "Romanian Deadlift"), unidades e números.

## 3. Tarefas

### T1 — Esqueleto de dados e ferramentas (sem traduzir ainda)
- Criar `tool/translation/split_exercises.dart` (ou script Python em `tool/translation/`) que divide `assets/data/exercises.json` em lotes de **30 exercícios** (`tool/translation/chunks/chunk_001.json` ...) contendo só `id`, `name`, `instructions`.
- Criar `tool/translation/merge_translations.dart` que junta `tool/translation/out/chunk_NNN.json` em `assets/data/exercises_pt.json` (ordenado por id, UTF-8 sem escape, `indent: 2`) e **falha** se houver id faltando, nome vazio ou número de instruções diferente do original.
- Adicionar `tool/translation/out/` e `chunks/` ao `.gitignore` (artefatos intermediários).

### T2 — Tradução (lotes)
- Para cada lote, escrever `tool/translation/out/chunk_NNN.json` com o mesmo formato e `instructions` com o **mesmo número de itens**.
- Ao concluir todos os lotes, rodar o merge e commitar `assets/data/exercises_pt.json`.
- Revisão por amostragem: reler os 15 primeiros e 15 últimos exercícios e 20 aleatórios; checar aderência ao glossário.

### T3 — Merge do overlay no datasource
- `exercise_remote_datasource_fake.dart`: carregar `assets/data/exercises_pt.json` com `rootBundle` na isolate principal junto do JSON original; passar **ambas as strings** para o parse (`compute` recebe um record/objeto simples) e para `parseExercisesInChunks`.
- `_mapExerciseJson` aplica `name` e `instructions` (`• ` + item, unidos por `\n`, formato atual) do overlay quando existirem; senão mantém o original.
- Manter o comportamento web (chunks) e não regredir o ganho de performance da #98.

### T4 — Rótulos de exibição
- Criar `exercise_labels.dart` com: `muscleLabel`, `levelLabel` (beginner → Iniciante, intermediate → Intermediário, expert → Avançado), `equipmentLabel`, `mechanicLabel` (compound → Composto, isolation → Isolado), `forceLabel` (pull → Puxar, push → Empurrar, static → Estático), `categoryLabel` (strength → Força, stretching → Alongamento, plyometrics → Pliométrico, powerlifting → Powerlifting, olympic weightlifting → Levantamento olímpico, strongman → Strongman, cardio → Cardio) e um helper para listas separadas por vírgula (`primaryMuscles` é `"chest, triceps"`).
- Os 17 músculos: abdominals → Abdômen, abductors → Abdutores, adductors → Adutores, biceps → Bíceps, calves → Panturrilhas, chest → Peito, forearms → Antebraços, glutes → Glúteos, hamstrings → Posteriores de coxa, lats → Dorsais, lower back → Lombar, middle back → Costas (meio), neck → Pescoço, quadriceps → Quadríceps, shoulders → Ombros, traps → Trapézio, triceps → Tríceps.
- Reaproveitar/ancorar `muscleGroupTranslation` (filtro) sem alterar suas chaves em inglês.

### T5 — Aplicar nas telas
- `exercise_card.dart` (músculos e equipamento), `exercise_details_page.dart` (músculo primário/secundário, nível, equipamento, mecânica, força, categoria — onde exibidos), `substitution_sheet.dart` (equipamento) e o seletor de exercício do treino (`exercise_picker_sheet.dart`, se exibir esses campos).
- Substituir o `'N/A'` por `'—'` ou "Não informado" de forma consistente.

### T6 — Nome traduzido na sheet de substituição
- `SubstituteSuggestion.name` vem da RPC em inglês. Resolver o nome em pt-BR consultando o catálogo local pelo `id` (o `id` da RPC é o UUID do Supabase; verificar se bate com `externalId`/`id` local — se não bater, usar o `external_id` retornado pela RPC e **não** alterar o SQL). Se não for viável sem mudar o backend, deixar o nome original e registrar o limite no PR.

### T7 — Migração Drift
- `app_database.dart`: `schemaVersion => 2`; em `onUpgrade`, `if (from < 2) await delete(exerciseLibraryTable).go();` (confirmar o nome do accessor gerado). Não mexer em `deleteAllUserData`.
- Se o schema gerado mudar (não deve), rodar `dart run build_runner build --delete-conflicting-outputs`.

### T8 — Testes
- Overlay: 876 ids, todos presentes em `exercises.json`, nomes não vazios, mesma contagem de instruções do original, nenhuma instrução vazia.
- Datasource: merge aplica pt-BR; fallback ao original quando falta o id (usar fixture pequena).
- `exercise_labels`: todos os valores distintos do dataset (`force`, `level`, `mechanic`, `equipment`, `category`, 17 músculos) têm rótulo; desconhecido devolve fallback; listas com vírgula.
- Migração: banco v1 populado → abrir em v2 → `exercise_library` vazia e `exercise_sets` preservado (usar `NativeDatabase.memory()`/verificador de schema já usado no projeto, se houver).
- Widget: `ExerciseCard` mostra rótulos em português.
- Atualizar testes existentes que dependam de textos em inglês.

## 4. Convenções do projeto

- Código/identificadores como já estão no projeto; comentários e mensagens em pt-BR com acentuação correta.
- Commits em Conventional Commits com a issue: `feat(exercise): ... (#102)`, `test(exercise): ... (#102)`, `docs(exercise): ... (#102)`. Commits pequenos por tarefa (T1…T8). **Não** fazer push nem abrir PR.
- Não editar `lib/core/database/app_database.g.dart` à mão.
- Não alterar `assets/data/exercises.json`, `supabase/seed/*` nem migrations/Edge Functions do Supabase.

## 5. Verificação final

```bash
flutter pub get
flutter analyze
flutter test test/features/exercise test/features/workout
flutter test
```

Checklist: critérios de aceite da issue #102 atendidos; nenhum texto em inglês visível nos cards/detalhes/seletor (exceto nomes próprios consagrados); `git status` sem artefatos intermediários.
