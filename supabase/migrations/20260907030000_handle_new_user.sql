-- ============================================================
-- MIGRAÇÃO 005 — trigger handle_new_user (#27, gap do schema)
-- Todo signup precisa de uma linha em public.profiles (FK de todas
-- as tabelas user-scoped). Descoberto no E2E da #27: insert de
-- workout_session para um usuário recém-signup viola
-- workout_sessions_user_id_fkey por falta do profile.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', NEW.raw_user_meta_data ->> 'name')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
