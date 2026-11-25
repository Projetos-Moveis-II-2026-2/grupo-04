# Plano de Implementação — Catálogo de exercícios em pt-BR no Supabase

Continuação da #102, que traduziu o catálogo só no app (overlay `assets/data/exercises_pt.json`)
e deixou o Supabase fora de escopo (decisão D6 de `docs/PLANO_TRADUCAO_EXERCICIOS.md`).
Este plano leva a mesma tradução para a tabela remota `public.exercise_library`.

## 1. Diagnóstico inicial (2026-11-25)

| Item | Situação |
|------|----------|
| Projeto | `sgcgvyywidwvybfxllkj` (`lib/core/constants/api_endpoints.dart`), Postgres 17 |
| Supabase CLI | 3.2.0 instalada em `~/.local/bin/supabase.exe` (mesma versão do CI). Ainda **sem login**, então não há `link` |
| `exercise_library` remota | 876 linhas, `name` e `instructions` em inglês, iguais a `supabase/seed/exercises.json` |
| Overlay pt-BR | 876 ids. Todos os `external_id` remotos têm tradução e nenhum id do overlay falta no remoto. A contagem de passos das instruções bate nas 876 linhas |
| Sujeira no remoto | `Pallof_Press` e `Skating` ainda têm `\u009d` depois do travessão (a migração `20260907020000_fix_seed_encoding.sql` não removeu esse byte). `Straight-Arm_Dumbbell_Pullover` tem `\r\n` dentro de um passo. 5 linhas têm `instructions = NULL` em vez de `{}`: `Iron_Cross`, `One-Arm_Kettlebell_Swings`, `Push_Press`, `Side_Bridge`, `Side_Jackknife` |
| Storage | Com a publishable key, `GET /storage/v1/bucket` devolve `[]`. Isso só prova que o `anon` não lista buckets, não que nenhum bucket existe. **Pendente:** verificar com a CLI logada (seção 5). As imagens vêm hoje de `raw.githubusercontent.com/yuhonas/free-exercise-db`, montadas no app e na RPC `find_substitutes` |

### Quem lê `name` / `instructions` no backend

- `find_substitutes` (RPC): devolve `name`, que o app exibe. O app já troca esse nome pelo pt-BR usando o catálogo local (T6 da #102).
- `suggest-load` (Edge Function): usa `name` no prompt. Em pt-BR fica melhor, sem risco.
- `suggest-substitute` (Edge Function): **quebra se `name` virar pt-BR.** O prompt pede ao LLM nomes "EM INGLÊS como no catálogo" e casa a resposta com `.ilike("name", ...)`.

## 2. Decisões

| # | Decisão | Motivo |
|---|---------|--------|
| S1 | Sobrescrever `name` e `instructions` com pt-BR e guardar o original em colunas novas `name_en TEXT` e `instructions_en TEXT[]` | Atende ao pedido de deixar todos os registros em pt-BR. O inglês continua disponível para o casamento do LLM e para reimportar do upstream |
| S2 | Fazer a mudança numa **migration** versionada (`supabase/migrations/<ts>_exercise_library_pt_br.sql`), gerada por script a partir de `assets/data/exercises_pt.json` | Mesmo padrão do seed. `db reset` local e `db push` remoto ficam reproduzíveis, sem editar dados pelo painel |
| S3 | `UPDATE ... FROM jsonb_each($pt$<json>$pt$::jsonb)` casando por `external_id`, dentro de um bloco que **aborta** se o total atualizado for diferente de 876 | Uma transação só. Se faltar alguma linha, nada é gravado (o JSON não contém `$pt$`, já conferido; o payload tem cerca de 520 KB) |
| S4 | `force`, `level`, `mechanic`, `equipment`, `category` e os músculos **continuam em inglês** | Mesmo critério da D3. `find_substitutes` compara `equipment` e `primary_muscles`, e o app traduz esses campos na exibição |
| S5 | `suggest-substitute` passa a usar `name_en` no prompt e no `ilike`, e devolve `name` (pt-BR) em `matched_name` | Mantém o casamento com o LLM funcionando |
| S6 | Ao preencher `name_en`/`instructions_en`, limpar `\u009d` e `\r`, e trocar `NULL` por `{}` | Aproveita a migration para corrigir os problemas listados na seção 1 |
| S7 | Re-sincronizar o catálogo do app quando a revisão mudar | O seletor de exercícios de fichas baixa o catálogo remoto para o Drift. Gravar a revisão depois de persistir o catálogo traduzido. Até a migration estar disponível, manter o catálogo local e tentar outra vez na próxima abertura do seletor. |

## 3. Tarefas

### T1 — Gerador da migration (`tool/translation/generate_supabase_migration.dart`)
- Ler `assets/data/exercises_pt.json` em UTF-8 e escrever `supabase/migrations/<timestamp>_exercise_library_pt_br.sql` em UTF-8 sem BOM, com conteúdo determinístico (ids ordenados).
- Falhar se o JSON tiver `$pt$` ou `$do$`, se algum nome estiver vazio ou se algum passo de instrução vier vazio.
- O SQL gerado executa as etapas a seguir em um único bloco `DO`:
  1. `ALTER TABLE public.exercise_library ADD COLUMN IF NOT EXISTS name_en TEXT, ADD COLUMN IF NOT EXISTS instructions_en TEXT[];`
  2. Backfill idempotente, só onde `name_en IS NULL`: `name_en = name` e `instructions_en = COALESCE(<instructions sem chr(157) e chr(13)>, '{}')`. Usar `ARRAY(SELECT replace(replace(x, chr(157), ''), chr(13), '') FROM unnest(instructions) x)`.
  3. Atualizar nomes e instruções na ordem do overlay, casando por `external_id`. Conferir o `ROW_COUNT` e abortar o bloco se for diferente de 876.
  4. Comentários `COMMENT ON COLUMN` explicando `name_en`/`instructions_en`, e `NOTIFY pgrst, 'reload schema';`.
- Não mexer em `GRANT`/RLS. As colunas novas herdam o `SELECT` público da tabela.

### T2 — Edge Function `suggest-substitute`
- `select("name, name_en, equipment, primary_muscles")`. O prompt usa `exercise.name_en ?? exercise.name`.
- No casamento, priorizar o nome exato sem distinguir maiúsculas, depois buscar um trecho do nome com ordenação estável. Escapar os curingas do padrão e devolver o nome em pt-BR em `matched_name`.
- Ajustar ou adicionar o teste Deno, se houver, e conferir que `suggest-load` continua compilando (não precisa mudar).

### T3 — Teste local
- `supabase start` e depois `supabase db reset` (precisa de Docker, que **não está instalado** nesta máquina; alternativa: o job `integration.yml` do CI).
- Consultas de verificação:
  - `select count(*) from exercise_library where name = name_en;` deve dar ~0 (só nomes que não mudaram, como "Skating" → conferir).
  - `select count(*) from exercise_library where cardinality(instructions) <> cardinality(instructions_en);` deve dar 0.
  - `select count(*) from exercise_library where name_en like '%' || chr(157) || '%' or array_to_string(instructions_en, '') ~ E'[\\r\\u009d]';` deve dar 0.
- Rodar `flutter test test/integration` (rls/offline) contra o stack local.

### T4 — Aplicar no remoto (só com aprovação explícita)
1. `supabase login` (interativo, feito pelo usuário) e depois `supabase link --project-ref sgcgvyywidwvybfxllkj`.
2. `supabase migration list` para confirmar que o histórico remoto bate com as 8 migrations locais.
3. `supabase db push --dry-run`. Deve listar só a migration nova.
4. `supabase db push`.
5. `supabase functions deploy suggest-substitute`.
6. Verificar pela API pública: `GET /rest/v1/exercise_library?select=external_id,name,name_en&external_id=eq.3_4_Sit-Up` deve trazer `"Abdominal 3/4"`. Chamar a RPC `find_substitutes` e conferir nomes em pt-BR.

**Rollback:** migration inversa `UPDATE ... SET name = name_en, instructions = instructions_en;` (as colunas `_en` são o backup).

### T5 — Documentação
- README, seção Supabase: catálogo em pt-BR no banco, colunas `_en` e como regenerar (`dart run tool/translation/generate_supabase_migration.dart`).
- `PLANO_TRADUCAO_EXERCICIOS.md`: vincular a decisão D6 à issue #124.

## 4. Execução com subagentes

| Tarefa | Executor | Como |
|--------|----------|------|
| T1, T2, T5 | opencode `opencode-go/deepseek-v4.1-flash` | Um worktree por tarefa (`../grupo-04-wt/<tarefa>`), rodando `opencode run -m opencode-go/deepseek-v4.1-flash --auto` com este plano. Um supervisor (Claude) confere `dart analyze`, o SQL gerado e `deno check` |
| Revisão do SQL e da função | Codex `gpt-6.2-sol` | `codex exec -m gpt-6.2-sol` em modo leitura, revisando o diff (idempotência, transação, escape do `ilike`) |
| T3, T4 | Claude (sessão principal) | Exige credenciais e aprovação do usuário. Não delegar |

Commits em Conventional Commits com o número da issue. Push e PR (alvo `dev`) só quando o usuário pedir.

## 5. Mídia do catálogo

Com a CLI autenticada e vinculada ao projeto Olimpus, a consulta ao Storage
confirmou o bucket público `exercise-media` e os 1.746 quadros JPG dos 873
exercícios com imagens. A issue #125 trata da troca das URLs pelo bucket.
