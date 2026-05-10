CREATE TABLE IF NOT EXISTS push_tokens (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT PRIMARY KEY,
  platform VARCHAR(20) NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT push_tokens_platform_check CHECK (platform IN ('android', 'ios', 'web'))
);

CREATE INDEX IF NOT EXISTS push_tokens_user_id_idx ON push_tokens (user_id);
