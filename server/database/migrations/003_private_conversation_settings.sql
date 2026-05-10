CREATE TABLE IF NOT EXISTS private_conversation_settings (
  user_a_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  burn_after INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_a_id, user_b_id),
  CONSTRAINT private_conversation_settings_order_check CHECK (user_a_id < user_b_id),
  CONSTRAINT private_conversation_settings_burn_after_check CHECK (burn_after IN (0, 5, 10, 30, 60))
);
