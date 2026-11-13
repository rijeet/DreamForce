-- Dream Force Android MVP schema. Apply only through the CI migration workflow.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  email_normalized text NOT NULL UNIQUE,
  email_verified_at timestamptz,
  role varchar(16) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  google_subject text UNIQUE,
  password_hash text,
  display_name varchar(80),
  avatar_url text,
  locale varchar(35) NOT NULL DEFAULT 'en',
  status varchar(24) NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'deletion_pending', 'deleted', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (
    (role = 'user' AND google_subject IS NOT NULL AND password_hash IS NULL)
    OR (role = 'admin' AND google_subject IS NULL AND password_hash IS NOT NULL)
  )
);

CREATE TABLE user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  gender varchar(80),
  date_of_birth date CHECK (date_of_birth IS NULL OR date_of_birth <= current_date),
  country varchar(100),
  city varchar(100),
  profession varchar(120),
  timezone varchar(64) NOT NULL DEFAULT 'UTC',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_settings (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme_preference varchar(12) NOT NULL DEFAULT 'system'
    CHECK (theme_preference IN ('system', 'light', 'dark')),
  phase_notifications_enabled boolean NOT NULL DEFAULT true,
  sound_enabled boolean NOT NULL DEFAULT true,
  haptics_enabled boolean NOT NULL DEFAULT true,
  live_activity_enabled boolean NOT NULL DEFAULT true,
  analytics_app_usage_opt_in boolean NOT NULL DEFAULT false,
  week_starts_on smallint NOT NULL DEFAULT 1 CHECK (week_starts_on BETWEEN 1 AND 7),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash bytea NOT NULL,
  user_agent varchar(500),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  replaced_by_session_id uuid REFERENCES auth_sessions(id) ON DELETE SET NULL,
  CHECK (expires_at > created_at)
);
CREATE INDEX auth_sessions_user_active_idx ON auth_sessions(user_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE activity_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  name varchar(80) NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 80),
  icon_key varchar(40) NOT NULL,
  category varchar(40),
  planned_minutes smallint NOT NULL CHECK (planned_minutes BETWEEN 1 AND 480),
  is_builtin boolean NOT NULL DEFAULT false,
  created_by_admin_id uuid REFERENCES users(id) ON DELETE SET NULL,
  archived_at timestamptz,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (is_builtin = false AND owner_user_id IS NOT NULL)
    OR (is_builtin = true AND owner_user_id IS NULL AND created_by_admin_id IS NOT NULL)
  )
);
CREATE INDEX activity_templates_owner_idx ON activity_templates(owner_user_id, updated_at DESC)
  WHERE archived_at IS NULL;

CREATE TABLE weekly_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name varchar(80) NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 80),
  timezone varchar(64) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX weekly_plans_user_idx ON weekly_plans(user_id, updated_at DESC);

CREATE TABLE weekly_plan_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES weekly_plans(id) ON DELETE CASCADE,
  template_id uuid NOT NULL REFERENCES activity_templates(id) ON DELETE RESTRICT,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  position smallint NOT NULL CHECK (position >= 0),
  local_start_time time,
  planned_minutes_override smallint CHECK (planned_minutes_override BETWEEN 1 AND 480),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_id, weekday, position)
);

CREATE TABLE plan_occurrences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES weekly_plans(id) ON DELETE CASCADE,
  plan_entry_id uuid REFERENCES weekly_plan_entries(id) ON DELETE SET NULL,
  template_id uuid REFERENCES activity_templates(id) ON DELETE SET NULL,
  local_date date NOT NULL,
  timezone varchar(64) NOT NULL,
  local_start_time time,
  planned_minutes smallint NOT NULL CHECK (planned_minutes BETWEEN 1 AND 480),
  name_snapshot varchar(80) NOT NULL,
  icon_key_snapshot varchar(40) NOT NULL,
  state varchar(16) NOT NULL DEFAULT 'scheduled'
    CHECK (state IN ('scheduled', 'started', 'skipped', 'completed', 'unstarted')),
  skip_reason varchar(500),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX plan_occurrences_entry_date_idx ON plan_occurrences(plan_entry_id, local_date)
  WHERE plan_entry_id IS NOT NULL;
CREATE INDEX plan_occurrences_user_date_idx ON plan_occurrences(user_id, local_date, state);

CREATE TABLE focus_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id uuid REFERENCES activity_templates(id) ON DELETE SET NULL,
  plan_occurrence_id uuid REFERENCES plan_occurrences(id) ON DELETE SET NULL,
  name_snapshot varchar(80) NOT NULL,
  icon_key_snapshot varchar(40) NOT NULL,
  category_snapshot varchar(40),
  planned_minutes smallint NOT NULL CHECK (planned_minutes BETWEEN 1 AND 480),
  schedule_version smallint NOT NULL CHECK (schedule_version > 0),
  status varchar(16) NOT NULL CHECK (status IN ('running', 'paused', 'completed', 'cancelled', 'interrupted')),
  current_phase varchar(16) NOT NULL CHECK (current_phase IN ('focus', 'rest', 'finished')),
  current_phase_index smallint NOT NULL DEFAULT 0 CHECK (current_phase_index >= 0),
  started_at timestamptz NOT NULL,
  phase_started_at timestamptz,
  phase_target_end_at timestamptz,
  paused_at timestamptz,
  ended_at timestamptz,
  total_paused_seconds integer NOT NULL DEFAULT 0 CHECK (total_paused_seconds >= 0),
  actual_focus_seconds integer NOT NULL DEFAULT 0 CHECK (actual_focus_seconds >= 0),
  actual_rest_seconds integer NOT NULL DEFAULT 0 CHECK (actual_rest_seconds >= 0),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  client_timezone varchar(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status = 'paused') = (paused_at IS NOT NULL)),
  CHECK ((status IN ('running', 'paused')) = (phase_target_end_at IS NOT NULL)),
  CHECK ((status IN ('completed', 'cancelled', 'interrupted')) = (ended_at IS NOT NULL))
);
CREATE UNIQUE INDEX focus_sessions_one_open_per_user_idx ON focus_sessions(user_id)
  WHERE status IN ('running', 'paused');
CREATE INDEX focus_sessions_user_started_idx ON focus_sessions(user_id, started_at DESC);

CREATE TABLE session_phases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE,
  position smallint NOT NULL CHECK (position >= 0),
  phase_type varchar(8) NOT NULL CHECK (phase_type IN ('focus', 'rest')),
  planned_seconds integer NOT NULL CHECK (planned_seconds > 0),
  started_at timestamptz,
  ended_at timestamptz,
  actual_seconds integer NOT NULL DEFAULT 0 CHECK (actual_seconds >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, position)
);

CREATE TABLE session_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES focus_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_event_id uuid NOT NULL,
  event_type varchar(24) NOT NULL CHECK (event_type IN ('started', 'pause', 'resume', 'focus_started', 'rest_started', 'completed', 'cancel', 'interrupted')),
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (user_id, client_event_id)
);
CREATE INDEX session_events_session_idx ON session_events(session_id, received_at);

CREATE TABLE daily_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date date NOT NULL,
  timezone varchar(64) NOT NULL,
  mood varchar(16) CHECK (mood IN ('positive', 'mixed', 'difficult')),
  summary varchar(1000),
  reflection varchar(5000),
  reason_tags text[] NOT NULL DEFAULT '{}',
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, local_date)
);

CREATE TABLE idempotency_records (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint_key varchar(120) NOT NULL,
  idempotency_key varchar(255) NOT NULL,
  request_hash bytea NOT NULL,
  response_status smallint NOT NULL CHECK (response_status BETWEEN 100 AND 599),
  response_body jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, endpoint_key, idempotency_key),
  CHECK (expires_at > created_at)
);
CREATE INDEX idempotency_expiry_idx ON idempotency_records(expires_at);

CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER user_profiles_set_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER user_settings_set_updated_at BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER activity_templates_set_updated_at BEFORE UPDATE ON activity_templates FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER weekly_plans_set_updated_at BEFORE UPDATE ON weekly_plans FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER weekly_plan_entries_set_updated_at BEFORE UPDATE ON weekly_plan_entries FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER plan_occurrences_set_updated_at BEFORE UPDATE ON plan_occurrences FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER focus_sessions_set_updated_at BEFORE UPDATE ON focus_sessions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER daily_reviews_set_updated_at BEFORE UPDATE ON daily_reviews FOR EACH ROW EXECUTE FUNCTION set_updated_at();
