ALTER TABLE users DROP CONSTRAINT IF EXISTS users_account_format;

UPDATE users
SET account = LPAD(id::text, 10, '0')
WHERE account !~ '^[0-9]{10}$';

ALTER TABLE users
  ADD CONSTRAINT users_account_format CHECK (account ~ '^[0-9]{10}$');
