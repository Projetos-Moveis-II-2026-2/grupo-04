-- ============================================================
-- MIGRAÇÃO 004 — ai_rate_limits (#27)
-- Rate limit server-side das funções de IA: 1 chamada por
-- (user_id, exercise_id) a cada 7 dias (cláusula da issue #27).
-- A função suggest-load lê/insere com service_role (bypassa RLS,
-- por design); o usuário NÃO acessa esta tabela diretamente.
-- ============================================================

CREATE TABLE ai_rate_limits (
  user_id UUID NOT NULL,
  exercise_id TEXT NOT NULL,
  last_called_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, exercise_id)
);

ALTER TABLE ai_rate_limits ENABLE ROW LEVEL SECURITY;

-- Nenhuma policy: anon e authenticated ficam sem acesso direto.
-- (A Edge Function usa a service_role key injetada no runtime.)

NOTIFY pgrst, 'reload schema';
