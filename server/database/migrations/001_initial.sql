CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account VARCHAR(10) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  password_hash TEXT NOT NULL,
  avatar_url TEXT,
  status_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT users_account_format CHECK (account ~ '^@[A-Za-z]+$' AND char_length(account) <= 10)
);

CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  alias VARCHAR(100),
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT contacts_not_self CHECK (user_id <> contact_user_id),
  CONSTRAINT contacts_unique_pair UNIQUE (user_id, contact_user_id)
);

CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_code CHAR(8) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT groups_group_code_format CHECK (group_code ~ '^[0-9]{8}$')
);

CREATE TABLE group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT group_members_role_check CHECK (role IN ('owner', 'admin', 'member')),
  CONSTRAINT group_members_unique_member UNIQUE (group_id, user_id)
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_type VARCHAR(10) NOT NULL,
  recipient_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  type VARCHAR(20) NOT NULL DEFAULT 'text',
  status VARCHAR(20) NOT NULL DEFAULT 'sent',
  content TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  reply_to_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  CONSTRAINT messages_to_type_check CHECK (to_type IN ('user', 'group')),
  CONSTRAINT messages_type_check CHECK (type IN ('text', 'image', 'voice', 'file', 'sticker', 'call_event', 'revoked', 'burn')),
  CONSTRAINT messages_status_check CHECK (status IN ('sent', 'delivered', 'read', 'burned', 'revoked')),
  CONSTRAINT messages_recipient_check CHECK (
    (to_type = 'user' AND recipient_user_id IS NOT NULL AND group_id IS NULL)
    OR
    (to_type = 'group' AND group_id IS NOT NULL AND recipient_user_id IS NULL)
  )
);

CREATE TABLE message_reads (
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE media_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  original_name TEXT NOT NULL,
  storage_key TEXT NOT NULL UNIQUE,
  mime_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT media_files_size_positive CHECK (size_bytes >= 0)
);

CREATE TABLE sticker_packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  name VARCHAR(100) NOT NULL,
  manifest JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_public BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE account_deletions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  scheduled_for TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  reason TEXT
);

CREATE INDEX contacts_user_id_idx ON contacts (user_id);
CREATE INDEX contacts_contact_user_id_idx ON contacts (contact_user_id);
CREATE INDEX groups_owner_id_idx ON groups (owner_id);
CREATE INDEX group_members_user_id_idx ON group_members (user_id);
CREATE INDEX group_members_group_role_idx ON group_members (group_id, role);
CREATE INDEX messages_sender_sent_at_idx ON messages (sender_id, sent_at DESC);
CREATE INDEX messages_recipient_user_sent_at_idx ON messages (recipient_user_id, sent_at DESC) WHERE to_type = 'user';
CREATE INDEX messages_group_sent_at_idx ON messages (group_id, sent_at DESC) WHERE to_type = 'group';
CREATE INDEX messages_status_idx ON messages (status);
CREATE INDEX message_reads_user_id_idx ON message_reads (user_id);
CREATE INDEX media_files_owner_id_idx ON media_files (owner_id);
CREATE INDEX media_files_message_id_idx ON media_files (message_id);
CREATE INDEX sticker_packs_owner_id_idx ON sticker_packs (owner_id);
CREATE INDEX account_deletions_user_id_idx ON account_deletions (user_id);
