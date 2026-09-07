# Olimpus

App de acompanhamento de treino e hidratação — Flutter + Supabase (offline-first).

> ⚠️ README completo (setup, estrutura, comandos) é a issue #59 do backlog. Documento em construção.

## Edge Functions (supabase/functions)

Funções Deno deployadas no Supabase, com **JWT de usuário obrigatório** (`verify_jwt = true` no `supabase/config.toml` + `auth: ["user"]` no handler).

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

**Secrets** (server-side, nunca no código): `GEMINI_API_KEY` (IA — provedor Gemini Flash-Lite, free tier). Configurar com `supabase secrets set GEMINI_API_KEY=...`; dentro da função: `Deno.env.get("GEMINI_API_KEY")`. Lista sem expor valores: `supabase secrets list`.

## Documentos do projeto

| Documento | Conteúdo |
|-----------|----------|
| [`docs/WORKFLOW_IA.md`](docs/WORKFLOW_IA.md) | **Padrão obrigatório** para IAs/devs implementarem as issues (branch → commits → reanálise → comentário → merge → close) |
| [`docs/BACKLOG_ISSUES_PROPOSTA.md`](docs/BACKLOG_ISSUES_PROPOSTA.md) | Backlog completo (46 issues), mapa backlog→GitHub, branches e template de comentário |
| [`docs/PLANO_IMPLEMENTACAO.md`](docs/PLANO_IMPLEMENTACAO.md) | Plano de implementação v2.0 (arquitetura, Supabase, Etapas 1–4, pubspec final) |
| [`docs/ANALISE_REQUISITOS_GAPS.md`](docs/ANALISE_REQUISITOS_GAPS.md) | Análise de requisitos e gaps de implementação/arquitetura |

## Padrão de trabalho

Antes de implementar qualquer issue, **leia `docs/WORKFLOW_IA.md`** — define o ciclo: branch baseada em `dev`, nome `tipo/<N-github>-<slug>`, commits convencionais, reanálise do implementado, comentário na issue, merge para `dev` e close.
