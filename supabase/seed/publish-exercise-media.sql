-- Execute com psql -v supabase_url=<URL do projeto> após o upload dos WebPs.
-- Apenas exercícios com todos os objetos esperados recebem URLs públicas.
WITH media AS (
  SELECT e.id,
         array_remove(ARRAY[
           rtrim(:'supabase_url', '/') || '/storage/v1/object/public/exercise-media/' || thumbnail.name,
           rtrim(:'supabase_url', '/') || '/storage/v1/object/public/exercise-media/' || motion.name
         ], NULL) AS image_urls
  FROM public.exercise_library e
  JOIN storage.objects thumbnail
    ON thumbnail.bucket_id = 'exercise-media'
   AND thumbnail.name = 'v1/' || e.external_id || '/thumbnail.webp'
  LEFT JOIN storage.objects motion
    ON motion.bucket_id = thumbnail.bucket_id
   AND motion.name = 'v1/' || e.external_id || '/motion.webp'
   AND cardinality(e.image_urls) = 2
  WHERE e.image_urls[1] = e.external_id || '/0.jpg'
    AND (cardinality(e.image_urls) = 1 OR motion.id IS NOT NULL)
)
UPDATE public.exercise_library e
SET image_urls = media.image_urls
FROM media
WHERE e.id = media.id;
