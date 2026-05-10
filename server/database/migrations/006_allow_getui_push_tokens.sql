ALTER TABLE push_tokens
  DROP CONSTRAINT IF EXISTS push_tokens_platform_check;

ALTER TABLE push_tokens
  ADD CONSTRAINT push_tokens_platform_check CHECK (platform IN ('android', 'ios', 'web', 'getui'));
