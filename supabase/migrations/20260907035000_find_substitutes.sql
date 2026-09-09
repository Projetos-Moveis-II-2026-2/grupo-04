-- ============================================================
-- MIGRAÇÃO 006 — find_substitutes (#28, camada 1 — sem LLM)
-- Busca estruturada: exercícios que trabalham o(s) mesmo(s) músculo(s)
-- primário(s) com equipamento diferente. O fallback LLM só é chamado
-- quando esta função retorna 0 linhas.
-- ============================================================

CREATE OR REPLACE FUNCTION public.find_substitutes(
  p_exercise_id UUID,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  external_id TEXT,
  name TEXT,
  force TEXT,
  level TEXT,
  mechanic TEXT,
  equipment TEXT,
  primary_muscles TEXT[],
  image_url TEXT
)
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT e.id,
         e.external_id,
         e.name,
         e.force,
         e.level,
         e.mechanic,
         e.equipment,
         e.primary_muscles,
         CASE WHEN e.image_urls IS NULL OR array_length(e.image_urls, 1) IS NULL
              THEN NULL
              ELSE 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/'
                   || e.image_urls[1]
         END AS image_url
  FROM public.exercise_library e
  WHERE e.id <> p_exercise_id
    AND e.equipment IS DISTINCT FROM (SELECT x.equipment
                                      FROM public.exercise_library x
                                      WHERE x.id = p_exercise_id)
    AND EXISTS (
      SELECT 1
      FROM public.exercise_library s,
           unnest(s.primary_muscles) AS m
      WHERE s.id = p_exercise_id AND m = ANY (e.primary_muscles)
    )
  ORDER BY e.id
  LIMIT LEAST(p_limit, 50);
$$;

GRANT EXECUTE ON FUNCTION public.find_substitutes(UUID, INTEGER) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
