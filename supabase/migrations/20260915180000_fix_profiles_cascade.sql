-- ============================================================
-- MIGRAÇÃO 008 — Fix FK profiles → auth.users (#32)
-- A FK original não incluía ON DELETE CASCADE, impedindo a
-- deleção do auth.users pela Edge Function delete-account.
-- Com cascade, ao deletar o auth user, o profile e todas as
-- tabelas filhas (workout_templates, sessions, sets, water)
-- são limpos automaticamente pelo Postgres.
-- ============================================================

ALTER TABLE profiles
  DROP CONSTRAINT profiles_id_fkey,
  ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
