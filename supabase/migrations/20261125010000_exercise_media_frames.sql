-- Issue #125: o app e o backend deixam de usar raw.githubusercontent.com/cdn.jsdelivr.net
-- e passam a servir os quadros do catálogo pelo bucket público exercise-media.
-- Os quadros originais ficam em v1/<external_id>/0.jpg e v1/<external_id>/1.jpg,
-- então o caminho relativo do dataset (ex.: <id>/0.jpg) corresponde à chave do
-- objeto em v1/ (ex.: v1/<id>/0.jpg).

-- O bucket passa a aceitar WebP (miniatura/animação) e JPEG (quadros originais).
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/webp', 'image/jpeg']
WHERE id = 'exercise-media';

-- Mesma função de 20261124000000_exercise_media.sql, agora resolvendo o caminho
-- relativo no bucket público em vez do repositório do GitHub.
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
         CASE WHEN e.image_urls[1] ~ '^https?://' THEN e.image_urls[1]
              ELSE 'https://sgcgvyywidwvybfxllkj.supabase.co/storage/v1/object/public/exercise-media/v1/'
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

-- Reescreve caminhos relativos já gravados para a URL pública do bucket apenas
-- quando todos os quadros existem em storage.objects. Assim a migration é
-- idempotente e, no banco local sem objetos, permanece no-op.
UPDATE public.exercise_library e
SET image_urls = ARRAY(
  SELECT 'https://sgcgvyywidwvybfxllkj.supabase.co/storage/v1/object/public/exercise-media/v1/' || u.p
  FROM unnest(e.image_urls) WITH ORDINALITY AS u(p, n)
  ORDER BY u.n
)
WHERE cardinality(e.image_urls) > 0
  AND NOT EXISTS (
    SELECT 1
    FROM unnest(e.image_urls) AS x(p)
    WHERE x.p ~ '^https?://'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM unnest(e.image_urls) AS x(p)
    WHERE NOT EXISTS (
      SELECT 1
      FROM storage.objects o
      WHERE o.bucket_id = 'exercise-media'
        AND o.name = 'v1/' || x.p
    )
  );

NOTIFY pgrst, 'reload schema';
