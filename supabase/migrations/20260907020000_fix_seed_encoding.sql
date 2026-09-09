-- ============================================================
-- MIGRAÇÃO 003 — reparo de encoding no seed (follow-up do review do
-- Copilot nos PRs #71/#72).
--
-- Contexto: o primeiro push remoto levou a migração 002 gerada antes
-- do fix UTF-8 do gerador (PR #72), gravando textos com UTF-8 dupla-
-- mente codificado (leitura ANSI no Windows PowerShell 5.1). O banco
-- local já nasceu corrigido; este reparo é só para o remoto.
--
-- Método: inventário do dataset confirmou que existem exatamente 3
-- caracteres não-ASCII no free-exercise-db:
--   —  U+2014 EM DASH            → corrompido: Ã¢â‚¬â€ (6 bytes visíveis: Ã¢â‚¬â€)
--   ¾  U+00BE VULGAR FRACTION ¾  → corrompido: Ã‚Â¾
--   °  U+00B0 DEGREE SIGN        → corrompido: Ã‚Â°
-- O reparo faz replace determinístico dessas sequências (não usa
-- convert LATIN1: há byte sequences sem equivalente e falharia).
--
-- Idempotente: linhas sem as sequências não são afetadas.
-- Escopo: somente exercise_library (dados do dataset, sem dado de usuário).
-- ============================================================

UPDATE exercise_library
SET name = replace(replace(name, 'Ã¢â‚¬â€', '—'), 'Ã‚Â¾', '¾'),
    primary_muscles = (
      SELECT array_agg(replace(replace(m, 'Ã¢â‚¬â€', '—'), 'Ã‚Â¾', '¾'))
      FROM unnest(primary_muscles) AS m
    ),
    secondary_muscles = (
      SELECT array_agg(replace(replace(m, 'Ã¢â‚¬â€', '—'), 'Ã‚Â¾', '¾'))
      FROM unnest(secondary_muscles) AS m
    ),
    instructions = (
      SELECT array_agg(replace(replace(i, 'Ã¢â‚¬â€', '—'), 'Ã‚Â¾', '¾') ORDER BY ord)
      FROM unnest(instructions) WITH ORDINALITY AS t(i, ord)
    )
WHERE name LIKE '%Ã%'
   OR array_to_string(primary_muscles, '') LIKE '%Ã%'
   OR array_to_string(secondary_muscles, '') LIKE '%Ã%'
   OR array_to_string(instructions, '') LIKE '%Ã%';

-- Caso residual (não esperado): ¾ dentro de instructions etc. já coberto
-- acima; ° U+00B0 → 'Ã‚Â°' coberto pelo replace abaixo nas mesmas colunas.
UPDATE exercise_library
SET name = replace(name, 'Ã‚Â°', '°'),
    primary_muscles = (
      SELECT array_agg(replace(m, 'Ã‚Â°', '°'))
      FROM unnest(primary_muscles) AS m
    ),
    secondary_muscles = (
      SELECT array_agg(replace(m, 'Ã‚Â°', '°'))
      FROM unnest(secondary_muscles) AS m
    ),
    instructions = (
      SELECT array_agg(replace(i, 'Ã‚Â°', '°') ORDER BY ord)
      FROM unnest(instructions) WITH ORDINALITY AS t(i, ord)
    )
WHERE name LIKE '%Ã%'
   OR array_to_string(primary_muscles, '') LIKE '%Ã%'
   OR array_to_string(secondary_muscles, '') LIKE '%Ã%'
   OR array_to_string(instructions, '') LIKE '%Ã%';

NOTIFY pgrst, 'reload schema';
