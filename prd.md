**Ref. backlog:** #18 (docs/BACKLOG_ISSUES_PROPOSTA.md)

## Objetivo
Tela da biblioteca de exercícios com agrupamento por grupo muscular, busca por nome e cache offline.

## Contexto
- Dados vêm da tabela `exercise_library` (seed do free-exercise-db) via Supabase; cache em Drift para leitura offline.
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