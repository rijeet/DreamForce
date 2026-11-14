ALTER TABLE user_settings
  ADD COLUMN screen_time_sync_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN screen_time_consent_version varchar(64),
  ADD COLUMN screen_time_consent_at timestamptz,
  ADD COLUMN screen_time_sync_revoked_at timestamptz,
  ADD COLUMN terms_accepted_version varchar(64),
  ADD COLUMN terms_accepted_at timestamptz,
  ADD CONSTRAINT user_settings_screen_time_consent_check CHECK (
    NOT screen_time_sync_enabled
    OR (screen_time_consent_version IS NOT NULL AND screen_time_consent_at IS NOT NULL)
  );

CREATE TABLE user_app_usage_daily (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date date NOT NULL,
  timezone_id varchar(64) NOT NULL,
  package_name varchar(255) NOT NULL,
  app_label varchar(160) NOT NULL,
  usage_seconds integer NOT NULL CHECK (usage_seconds BETWEEN 0 AND 86400),
  queried_at timestamptz NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, local_date, timezone_id, package_name)
);

CREATE INDEX user_app_usage_daily_range_idx
  ON user_app_usage_daily(user_id, timezone_id, local_date DESC);

