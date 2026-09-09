-- ============================================================
-- MIGRATION 001 — Olimpus (docs/PLANO_IMPLEMENTACAO.md §5.1)
-- Ajustes de segurança sobre o SQL do plano, conforme guia do
-- Supabase: policies de dono com TO authenticated (evita aplicar
-- regra de posse a anon) e WITH CHECK explícito (UPDATE não deve
-- permitir troca de user_id).
-- ============================================================

-- ── TABELAS ──────────────────────────────────────────────────

CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  display_name TEXT,
  body_weight_kg DECIMAL(5,2),
  daily_water_goal_ml INTEGER DEFAULT 2000,
  experience_level TEXT CHECK (experience_level IN ('beginner','intermediate','advanced')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercise_library (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT UNIQUE NOT NULL,     -- id do free-exercise-db
  name TEXT NOT NULL,
  force TEXT,
  level TEXT,
  mechanic TEXT,
  equipment TEXT,
  primary_muscles TEXT[] NOT NULL,
  secondary_muscles TEXT[],
  instructions TEXT[],
  category TEXT,
  image_urls TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE template_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES workout_templates(id) ON DELETE CASCADE NOT NULL,
  exercise_id UUID REFERENCES exercise_library(id) NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  target_sets INTEGER NOT NULL DEFAULT 3,
  target_reps INTEGER
);

CREATE TABLE workout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  template_id UUID REFERENCES workout_templates(id),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  total_volume_kg DECIMAL(10,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercise_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES workout_sessions(id) ON DELETE CASCADE NOT NULL,
  exercise_id UUID REFERENCES exercise_library(id) NOT NULL,
  set_number INTEGER NOT NULL,
  weight_kg DECIMAL(5,2) NOT NULL,
  reps INTEGER NOT NULL,
  completed BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE water_intake (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount_ml INTEGER NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  date DATE DEFAULT CURRENT_DATE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── GRANTS: revogar defaults e conceder o mínimo ──────────────
REVOKE ALL ON exercise_library FROM anon, authenticated;
REVOKE ALL ON profiles, workout_templates, template_exercises,
            workout_sessions, exercise_sets, water_intake
  FROM anon, authenticated;

GRANT SELECT ON exercise_library TO anon, authenticated;        -- catálogo público
GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON template_exercises TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON workout_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON exercise_sets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON water_intake TO authenticated;

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_intake ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_library ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own profile" ON profiles
  FOR ALL TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "own templates" ON workout_templates
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own template exercises" ON template_exercises
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM workout_templates t
                         WHERE t.id = template_id AND t.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM workout_templates t
                      WHERE t.id = template_id AND t.user_id = auth.uid()));
CREATE POLICY "own sessions" ON workout_sessions
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own sets" ON exercise_sets
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM workout_sessions s
                         WHERE s.id = session_id AND s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM workout_sessions s
                      WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE POLICY "own water" ON water_intake
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "public exercise read" ON exercise_library
  FOR SELECT
  TO anon, authenticated
  USING (TRUE);

-- ── ÍNDICES ───────────────────────────────────────────────────
CREATE INDEX idx_exercise_sets_session ON exercise_sets(session_id);
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, started_at DESC);
CREATE INDEX idx_water_intake_user_date ON water_intake(user_id, date);
CREATE INDEX idx_template_exercises_template ON template_exercises(template_id);

-- ── TRIGGER: updated_at automático ────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['profiles','workout_templates','workout_sessions',
                          'exercise_sets','water_intake'] LOOP
    EXECUTE format('CREATE TRIGGER trg_%s_updated BEFORE UPDATE ON %I
                    FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
  END LOOP;
END $$;
