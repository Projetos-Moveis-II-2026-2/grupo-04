-- ============================================================
-- MIGRAÇÃO 007 — reparo de grants (#28, follow-up do PR #72)
-- O remoto aplicou a migração 001 ANTES da correção de grants do
-- PR #72; editar a 001 não re-aplica em quem já rodou. Aqui o
-- estado de grants é (re)aplicado de forma idempotente:
-- - REVOKE de defaults em todas as tabelas app (anon+authenticated)
-- - catálogo: SELECT para anon+authenticated (leitura pública)
-- - tabelas user-scoped: CRUD para authenticated apenas
-- ============================================================

REVOKE ALL ON exercise_library FROM anon, authenticated;
REVOKE ALL ON profiles, workout_templates, template_exercises,
            workout_sessions, exercise_sets, water_intake
  FROM anon, authenticated;

GRANT SELECT ON exercise_library TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON template_exercises TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON exercise_sets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON water_intake TO authenticated;

NOTIFY pgrst, 'reload schema';
