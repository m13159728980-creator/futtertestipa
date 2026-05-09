CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  account VARCHAR(10) NOT NULL UNIQUE,
  display_name VARCHAR(24) NOT NULL,
  avatar_index SMALLINT NOT NULL CHECK (avatar_index BETWEEN 0 AND 8),
  token_version INTEGER NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT users_account_format CHECK (account ~ '^@[A-Za-z]{1,9}$')
);

CREATE TABLE contacts (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, contact_id),
  CONSTRAINT contacts_not_self CHECK (user_id <> contact_id)
);

CREATE TABLE groups (
  id BIGSERIAL PRIMARY KEY,
  group_code CHAR(8) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL,
  owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  burn_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT groups_group_code_format CHECK (group_code ~ '^[0-9]{8}$')
);

CREATE TABLE group_members (
  group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  removed_at TIMESTAMPTZ NULL,
  PRIMARY KEY (group_id, user_id),
  CONSTRAINT group_members_role_check CHECK (role IN ('owner', 'admin', 'member'))
);

CREATE TABLE media_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
  storage_path TEXT NOT NULL,
  sha256 CHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_id BIGINT NOT NULL,
  to_type VARCHAR(10) NOT NULL,
  type VARCHAR(20) NOT NULL DEFAULT 'text',
  content TEXT,
  media_id UUID NULL REFERENCES media_files(id) ON DELETE SET NULL,
  burn_after INTEGER NOT NULL DEFAULT 0,
  burn_started_at TIMESTAMPTZ NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'sent',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT messages_to_type_check CHECK (to_type IN ('user', 'group')),
  CONSTRAINT messages_type_check CHECK (type IN ('text', 'image', 'voice', 'file', 'sticker', 'call_event', 'revoked', 'burn')),
  CONSTRAINT messages_burn_after_check CHECK (burn_after IN (0, 5, 10, 30, 60)),
  CONSTRAINT messages_status_check CHECK (status IN ('sent', 'delivered', 'read', 'burned', 'revoked'))
);

CREATE TABLE message_reads (
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE sticker_packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  version INTEGER NOT NULL DEFAULT 1,
  zip_path TEXT NOT NULL,
  manifest JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE account_deletions (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  purge_after TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ NULL
);

CREATE INDEX contacts_contact_id_idx ON contacts (contact_id);
CREATE INDEX groups_owner_id_idx ON groups (owner_id);
CREATE INDEX group_members_user_id_idx ON group_members (user_id);
CREATE INDEX group_members_group_role_idx ON group_members (group_id, role) WHERE removed_at IS NULL;
CREATE INDEX media_files_owner_id_idx ON media_files (owner_id);
CREATE INDEX messages_to_lookup_idx ON messages (to_type, to_id, created_at DESC);
CREATE INDEX messages_from_id_idx ON messages (from_id, created_at DESC);
CREATE INDEX messages_media_id_idx ON messages (media_id);
CREATE INDEX message_reads_user_id_idx ON message_reads (user_id);
CREATE INDEX sticker_packs_active_idx ON sticker_packs (is_active);
CREATE INDEX account_deletions_purge_after_idx ON account_deletions (purge_after) WHERE completed_at IS NULL;
