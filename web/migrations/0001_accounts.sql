-- Forward-only migration for the existing HB_AUTH database.
-- Production: fulfillment-heartbeat-auth (646c017a-802f-4395-b635-d4b5bd66c1cb).
-- Preview: hb-auth-preview (291dfe6d-fcc1-4b15-90c7-768db26d1f8e).
-- CREATE statements match the tables already in production. ALTER statements add columns.
-- No users, passwords, salts, or invite tokens are seeded.
-- The Pages function applies the same statements on the first request.
-- To apply them by hand, use the D1 HTTP API or the dashboard console (see web/DEPLOY.md).
-- Do not point preview at the production database id.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL DEFAULT '',
  password_salt TEXT NOT NULL DEFAULT '',
  password_iterations INTEGER NOT NULL DEFAULT 100000,
  role TEXT NOT NULL CHECK (role IN ('admin', 'viewer')),
  status TEXT NOT NULL CHECK (status IN ('invited', 'active', 'disabled')),
  created_at INTEGER NOT NULL,
  last_login_at INTEGER
);

CREATE TABLE IF NOT EXISTS invites (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  token_enc TEXT NOT NULL DEFAULT '',
  purpose TEXT NOT NULL CHECK (purpose IN ('invite', 'reset', 'setup')),
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_sessions (
  id TEXT PRIMARY KEY,
  subject TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS login_attempts (
  bucket TEXT PRIMARY KEY,
  failures INTEGER NOT NULL,
  window_start INTEGER NOT NULL,
  locked_until INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS invites_user ON invites (user_id, used_at);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user_id, revoked_at);
CREATE INDEX IF NOT EXISTS shared_sessions_live ON shared_sessions (revoked_at, expires_at);

ALTER TABLE users ADD COLUMN password_algo TEXT NOT NULL DEFAULT 'PBKDF2-SHA256';
ALTER TABLE sessions ADD COLUMN last_seen_at INTEGER;
ALTER TABLE shared_sessions ADD COLUMN last_seen_at INTEGER;
ALTER TABLE login_attempts ADD COLUMN next_at INTEGER NOT NULL DEFAULT 0;
