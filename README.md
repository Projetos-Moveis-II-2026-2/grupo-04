# 🏋️‍♂️ Olimpus

Bem-vindo ao **Olimpus**! Este é o nosso app de acompanhamento de treino de musculação e hidratação. Construído com **Flutter** e **Supabase**, ele foca em uma experiência *offline-first* poderosa para que você possa treinar mesmo sem internet.

> ⚠️ **Status do Documento:** README principal em construção (referente à issue #59 do backlog).

---

## 🚀 Começando (Pré-requisitos e Instalação)

Antes de rodar o projeto, certifique-se de estar com o ambiente configurado corretamente. O projeto utiliza as seguintes versões mínimas:

* **Flutter**: `^3.44.0` *(Se a sua versão for mais antiga, rode `flutter upgrade`)*
* **Dart SDK**: `^3.13.0`

### Passos para rodar:
1. Clone o repositório:
   ```bash
   git clone <url-do-repo>
   cd olimpus
   ```
2. Instale as dependências:
   ```bash
   flutter pub get
   ```
3. Rode o aplicativo:
   ```bash
   flutter run
   ```

---

## 🏗️ Estrutura e Arquitetura do Projeto

Para mantermos o código organizado, escalável e testável, utilizamos uma abordagem **Feature-First** (divisão por funcionalidades) baseada nos princípios de Clean Architecture. 

Dentro de `lib/features/`, cada funcionalidade (como `workout`, `water`, `auth`, etc.) é dividida em três camadas principais:

* 🎨 **`presentation/`**: Contém tudo que é visual. Suas telas (Screens), componentes de UI (Widgets) e os gerenciadores de estado (usamos Riverpod para Providers e controllers).
* 🧠 **`domain/`**: O coração da regra de negócio. Contém suas Entidades (modelos puros) e as definições de repositórios (interfaces/contratos) que dizem "o que" o app faz, sem se importar com "como" é feito.
* 💾 **`data/`**: A camada de comunicação externa e persistência. Aqui ficam os modelos DTO, implementação das chamadas de API (Supabase) e banco de dados local (Drift/SQLite).

---

## 🤝 Como Contribuir e Padrão de Issues

Temos um fluxo muito bem estruturado para garantir a rastreabilidade e a qualidade das entregas. **Antes de implementar qualquer issue, é obrigatório ler o nosso fluxo de trabalho!**

* 👉 **Fluxo de Trabalho:** Leia o [`docs/WORKFLOW_IA.md`](docs/WORKFLOW_IA.md) para entender como criar branches (`tipo/<N-github>-<slug>`), formato dos commits e como submeter seu PR.
* 👉 **Backlog:** Todas as tarefas podem ser encontradas no [`docs/BACKLOG_ISSUES_PROPOSTA.md`](docs/BACKLOG_ISSUES_PROPOSTA.md).
* A branch de integração principal e desenvolvimento base para tudo é a `dev`.

---

## 📚 Documentação Adicional

Toda a documentação aprofundada do projeto pode ser encontrada na nossa pasta `docs/`. Lá temos informações valiosas que valem a leitura:

| Documento | Descrição |
|-----------|----------|
| 🔄 [`WORKFLOW_IA.md`](docs/WORKFLOW_IA.md) | **Leitura Obrigatória.** Padrão para implementarem issues (branch → commits → merge). |
| 📋 [`BACKLOG_ISSUES_PROPOSTA.md`](docs/BACKLOG_ISSUES_PROPOSTA.md) | Backlog completo de issues, mapa backlog→GitHub e templates de comentários. |
| 🗺️ [`PLANO_IMPLEMENTACAO.md`](docs/PLANO_IMPLEMENTACAO.md) | Detalhes da arquitetura, uso do Supabase e separação de etapas de desenvolvimento. |
| 🔍 [`ANALISE_REQUISITOS_GAPS.md`](docs/ANALISE_REQUISITOS_GAPS.md) | Análise profunda de requisitos, gaps e pontos de atenção técnica. |
| 🎓 [`Projeto-Disciplina.md`](docs/Projeto-Disciplina.md) | Escopo, notas e visão geral do projeto para a disciplina acadêmica. |

---

## ⚡ Edge Functions (supabase/functions)

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
