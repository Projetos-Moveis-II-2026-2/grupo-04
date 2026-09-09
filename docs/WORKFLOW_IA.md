# Workflow de Implementação para IAs — Projeto Olimpus

> **Propósito:** este documento define o **padrão obrigatório** que qualquer IA (ou dev assistido por IA) deve seguir para dar continuidade à implementação do app, conforme as issues do backlog.
> **Auditoria:** toda execução deve passar por este fluxo do início ao fim, sem atalhos.

---

## 1. Princípios

1. **`dev` é a branch de integração.** Toda branch de trabalho nasce de `dev` e todo merge volta para `dev`. `main` só recebe merge em marcos de entrega (Etapa/checkpoint), nunca no dia a dia.
2. **Uma issue por vez.** A IA pega **uma** issue do backlog, resolve, fecha e só então parte para a próxima (issues correlatas podem compartilhar branch, conforme §3).
3. **A issue é a fonte da verdade.** Objetivo, Contexto, Critérios de Aceite e Comando de Verificação da issue definem o que é "resolvido". Não inventar escopo.
4. **Verificação antes de fechar.** Nada de "está pronto" sem rodar o `Comando de Verificação` da issue e comprovar no comentário.
5. **Rastreabilidade total.** Branch → commits → comentário na issue → close → merge: tudo ligado à issue correspondente.

---

## 2. Preparação do ambiente (só na primeira execução)

```bash
# 1. Garantir que existe a branch base dev (se ainda não existir)
git switch main
git pull origin main
git checkout -b dev
git push -u origin dev

# 2. Na máquina local, a partir daqui SEMPRE trabalhar em dev como base
git switch dev
git pull origin dev
```

> Se a `dev` já existir no repositório, pular a criação e apenas `git switch dev && git pull`.

---

## 3. Convenção de branches

- **Base:** sempre `dev` (nunca `main`, nunca outra branch de feature).
- **Padrão de nome:** `<tipo>/<numero-github>-<slug-curto>`
  - `<tipo>`: `feat` | `fix` | `chore` | `test` | `docs` | `refactor`
  - `<numero-github>`: número da issue **no GitHub** (ex.: #20 → `20`)
  - `<slug-curto>`: 2–4 palavras do título, separadas por `-`
- **Exemplos:**
  - Issue #20 (`chore(core): scaffold...`) → `chore/20-scaffold-projeto`
  - Issue #29 (`feat(auth): signup/login/logout...`) → `feat/29-auth-signup-login`
- **Issues correlatas podem compartilhar a mesma branch** (mesmo grupo de correlação do backlog — ex.: #20+#21 fundação). Nesse caso o nome usa o intervalo ou o número da principal: `feat/20-21-fundacao`.
- **Regra de ouro:** o nome da branch **sempre** contém o número da issue no GitHub, para o GitHub vincular a branch à issue automaticamente.

---

## 4. Ciclo completo de implementação (passo a passo)

### Etapa A — Iniciar

```bash
git switch dev
git pull origin dev                     # dev sempre atualizada
git checkout -b feat/20-scaffold-projeto   # branch nova a partir de dev
```

1. Ler a issue inteira (Objetivo, Contexto, Critérios, Comando de Verificação, Arquivos Prováveis).
2. Conferir a linha `**Depende de:** #N` — se a dependência **não** estiver mergeada em `dev`, **não começar**: reportar e aguardar.

### Etapa B — Implementar

3. Implementar a solução em **um ou mais commits** (quantos forem necessários para a resolução perfeita — commit por unidade lógica, mensagens descritivas, ver §5).
4. **Não** misturar escopo de outras issues na mesma branch.

### Etapa C — Reanálise do implementado (auto-revisão obrigatória)

5. **Reanalisar o próprio trabalho** antes de comentar/fechar:
   - [ ] Rodei o `Comando de Verificação` da issue e ele passou? (ou o equivalente manual/teste)
   - [ ] Todos os **Critérios de Aceite** foram atendidos? (checar um a um)
   - [ ] `flutter analyze` limpo? (`dart format` aplicado?)
   - [ ] Segui a arquitetura do plano (feature-first, Riverpod como DI, Drift, padrão data/domain/presentation)?
   - [ ] Não quebrei nada que já estava em `dev` (regressão)? (rodar testes existentes)
   - [ ] Não deixei código morto, TODO solto, segredos/keys hardcoded ou arquivos desnecessários?
   - [ ] Mensagens de commit claras e convencionais?
   - [ ] Se encontrei problema na reanálise: **corrigi com novo commit na mesma branch** (nunca fecho com pendência).

### Etapa D — Comentar a implementação na issue

6. Comentar na issue (o comentário **deve** seguir o template da §6) com:
   - Branch usada + hash(es) do(s) commit(s)
   - Resumo do que foi implementado
   - Validação (comandos rodados e saída/resultado)

### Etapa E — Fechar a issue

7. Fechar a issue **somente após**:
   - Reanálise OK (§Etapa C)
   - Comentário de implementação postado (Etapa D)
   - **E** a branch já ter sido mergeada em `dev` (ver Etapa F) — a ordem correta é: **merge → close**. Fechar antes do merge quebra a rastreabilidade.
   - Alternativa aceitável: fechar com `Closes #N` no corpo do PR, para o GitHub fechar automaticamente no merge.

### Etapa F — Merge para `dev`

8. Subir a branch e abrir PR para `dev`:

```bash
git push -u origin feat/20-scaffold-projeto
```

9. No PR: título e corpo referenciando a issue (`Closes #20`), resumo das mudanças e resultado da verificação.
10. Aguardar o merge do PR em `dev` (por humano ou por regra do grupo, ver §7). Após merge, **fechar a issue** se ainda não foi fechada.
11. Limpeza: deletar a branch remota após o merge (`git push origin --delete feat/20-scaffold-projeto`).

---

## 5. Convenção de commits

- **Formato (Conventional Commits):** `<tipo>(<escopo>): <descrição> (#NúmeroDaIssue)`
  - `feat(core): adiciona AppDatabase com tabelas drift (#21)`
  - `fix(auth): corrige estado de confirmação pendente (#29)`
  - `chore(theme): aplica escala de tipografia M3 (#47)`
- **Escopo:** área afetada (`core`, `auth`, `workout`, `exercise`, `water`, `progress`, `supabase`, `theme`, `infra`, `pub`, `docs`).
- **Referencie a issue** em **todos** os commits da branch (ex.: `(#20)`) para rastreabilidade.
- **Corpo do commit** quando necessário: explica o *porquê*, não o *o quê*.
- **Proibido:** commit gigante "wip", commit com várias issues, commit sem mensagem.

---

## 6. Template do comentário de implementação (colar na issue)

```markdown
**Sprint {N}** | Branch: `{branch}` | Commit: `{hash}`

## Resumo

{2–5 linhas: o que foi feito, decisões, desvios do plano}

## Validação

```bash
{comando(s) executados para comprovar — o Comando de Verificação da issue}
{saída/resultado}
```
```

> Exemplo real de preenchimento no fim de `docs/BACKLOG_ISSUES_PROPOSTA.md`.

---

## 7. Regras de merge e revisão

1. **PR para `dev` é o caminho de merge** (merges diretos para `dev` sem PR só em casos triviais/documented e com ciência do grupo).
2. **Code review cruzado** conforme issues de coordenação C1–C3: todo PR deve ser revisado por **pelo menos 1 dev diferente do autor** antes do merge.
3. **CI como gate** (quando a issue #58 estiver implementada): PR não mergeável com CI vermelho.
4. **Conflitos:** resolver em `dev` local (`git switch dev && git pull && git switch -` e rebase/merge), nunca forçar push na `dev` (`--force` proibido em `dev` e `main`).
5. **`main`:** recebe merge apenas em marcos (Etapa 1→4, A2), via PR revisado por todo o grupo.

---

## 8. O que NÃO fazer

- ❌ Branch a partir de `main` ou de outra branch de feature
- ❌ Push direto para `dev`/`main` sem PR (fora exceção documentada)
- ❌ `git push --force` em branches compartilhadas
- ❌ Fechar issue sem rodar/registrar a verificação
- ❌ Fechar issue antes do merge em `dev`
- ❌ Implementar issue cuja dependência (`Depende de: #N`) não está em `dev`
- ❌ Commitar segredos (keystore, `.env`, chaves de API) — ver `.gitignore`
- ❌ Alterar o pubspec/dependências fora do escopo da issue sem registrar no comentário

---

## 9. Quando a IA deve PARAR e reportar (não "resolver de qualquer jeito")

- A issue depende de outra que ainda não foi mergeada em `dev`.
- O `Comando de Verificação` falha e a causa foge do escopo da issue (ex.: bug em infra alheia).
- A implementação exige decisão não resolvida (D7–D11 do plano: SMTP, cor do tema, agendamento de notificações, gamificação local/remota, análise de imagens de design).
- Há conflito entre o que a issue pede e o que já existe em `dev` (ex.: API de outro stream que mudou).
- O escopo da issue é grande demais para uma execução — **não** partir em duas issues: reportar e sugerir desmembramento.

Nesses casos: comentar na issue o bloqueio (template acima com o motivo), **não** fechar, e aguardar orientação.

---

## 10. Resumo visual do fluxo

```
dev ──► branch <tipo>/<N-github>-<slug> ──► commits ──► reanálise ──► comentário na issue
   ▲                                                                        │
   └────────────── merge (PR para dev) ◄──── close da issue ◄───────────────┘
```

**Ordem final (não inverter):** branch → commits → verificação/reanálise → comentário → **merge em dev → close da issue**.

---

*Documento vivo — atualizar junto com decisões do grupo. Vincular na issue #59 (README/docs).*
