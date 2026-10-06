// Per-user accounts on the existing HB_AUTH D1 binding.
// Passwords are PBKDF2-SHA256. New sessions and setup links are stored only as SHA-256.
// Rows already in fulfillment-heartbeat-auth keep their columns; new columns are added forward-only.
// Nothing in this file is a password, a session token, or an invite token.

export const PASSWORD_ALGO = "PBKDF2-SHA256";
export const PBKDF2_ITERATIONS = 100_000;
export const MIN_PASSWORD = 12;
export const SETUP_TTL = 24 * 60 * 60;
export const INVITE_TTL = 24 * 60 * 60;
export const IDLE_TTL = 12 * 60 * 60;
export const ABSOLUTE_TTL = 7 * 24 * 60 * 60;
export const BACKOFF_CAP = 15 * 60;
export const ACCOUNT_COOKIE = "hb_session";
export const SHARED_COOKIE = "hb_shared";

const DUMMY_SALT = "11".repeat(16);
const DUMMY_HASH = "22".repeat(32);

const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL DEFAULT '',
    password_salt TEXT NOT NULL DEFAULT '',
    password_iterations INTEGER NOT NULL DEFAULT 100000,
    role TEXT NOT NULL CHECK (role IN ('admin', 'viewer')),
    status TEXT NOT NULL CHECK (status IN ('invited', 'active', 'disabled')),
    created_at INTEGER NOT NULL,
    last_login_at INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS invites (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    token_enc TEXT NOT NULL DEFAULT '',
    purpose TEXT NOT NULL CHECK (purpose IN ('invite', 'reset', 'setup')),
    expires_at INTEGER NOT NULL,
    used_at INTEGER,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    revoked_at INTEGER,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS shared_sessions (
    id TEXT PRIMARY KEY,
    subject TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    revoked_at INTEGER,
    created_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS login_attempts (
    bucket TEXT PRIMARY KEY,
    failures INTEGER NOT NULL,
    window_start INTEGER NOT NULL,
    locked_until INTEGER NOT NULL DEFAULT 0
  )`,
  "CREATE INDEX IF NOT EXISTS invites_user ON invites (user_id, used_at)",
  "CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user_id, revoked_at)",
  "CREATE INDEX IF NOT EXISTS shared_sessions_live ON shared_sessions (revoked_at, expires_at)",
];

const ALTERS = [
  "ALTER TABLE users ADD COLUMN password_algo TEXT NOT NULL DEFAULT 'PBKDF2-SHA256'",
  "ALTER TABLE sessions ADD COLUMN last_seen_at INTEGER",
  "ALTER TABLE shared_sessions ADD COLUMN last_seen_at INTEGER",
  "ALTER TABLE login_attempts ADD COLUMN next_at INTEGER NOT NULL DEFAULT 0",
];

const encoder = new TextEncoder();

export function authDb(env) {
  return (env && env.HB_AUTH) || null;
}

export function configuredAdminEmail(env) {
  const email = normalizeEmail(env && env.ADMIN_EMAIL);
  return emailOk(email) ? email : "";
}

export function authCutover(env) {
  return String((env && env.AUTH_CUTOVER) || "") === "1";
}

export function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

export function emailOk(value) {
  const email = normalizeEmail(value);
  return email.length >= 6 && email.length <= 200 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function passwordOk(password) {
  const value = String(password ?? "");
  return value.length >= MIN_PASSWORD && value.length <= 200;
}

export function backoffSeconds(failures) {
  const count = Number(failures) || 0;
  if (count <= 0) return 0;
  const shift = Math.min(count - 1, 16);
  return Math.min(2 ** shift, BACKOFF_CAP);
}

function bytesToHex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function hexToBytes(hex) {
  const text = String(hex || "");
  if (!/^[0-9a-f]+$/i.test(text) || text.length % 2 !== 0) return null;
  const out = new Uint8Array(text.length / 2);
  for (let i = 0; i < out.length; i += 1) out[i] = Number.parseInt(text.slice(i * 2, i * 2 + 2), 16);
  return out;
}

function base64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(String(text)));
  return bytesToHex(new Uint8Array(digest));
}

function bytesEqual(left, right) {
  const a = left instanceof Uint8Array ? left : new Uint8Array();
  const b = right instanceof Uint8Array ? right : new Uint8Array();
  if (a.byteLength !== b.byteLength) {
    const filler = a.byteLength ? a : new Uint8Array(32);
    if (crypto.subtle && typeof crypto.subtle.timingSafeEqual === "function") {
      crypto.subtle.timingSafeEqual(filler, filler);
    }
    return false;
  }
  if (crypto.subtle && typeof crypto.subtle.timingSafeEqual === "function") {
    return crypto.subtle.timingSafeEqual(a, b);
  }
  let diff = 0;
  for (let i = 0; i < a.byteLength; i += 1) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function hashPassword(password, iterations = PBKDF2_ITERATIONS) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", encoder.encode(String(password)), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
    key,
    256,
  );
  return {
    hash: bytesToHex(new Uint8Array(bits)),
    salt: bytesToHex(salt),
    iterations,
    algo: PASSWORD_ALGO,
  };
}

export async function verifyPassword(password, saltHex, expectedHash, iterations, algo = PASSWORD_ALGO) {
  const rounds = Number(iterations) > 0 ? Number(iterations) : PBKDF2_ITERATIONS;
  const salt = hexToBytes(saltHex);
  const saltBytes = salt && salt.byteLength === 16 ? salt : new Uint8Array(16);
  const key = await crypto.subtle.importKey("raw", encoder.encode(String(password)), "PBKDF2", false, ["deriveBits"]);
  const bits = new Uint8Array(
    await crypto.subtle.deriveBits({ name: "PBKDF2", salt: saltBytes, iterations: rounds, hash: "SHA-256" }, key, 256),
  );
  const expected = hexToBytes(expectedHash);
  const expectedBytes = expected && expected.byteLength === bits.byteLength ? expected : new Uint8Array(bits.byteLength);
  const same = bytesEqual(bits, expectedBytes);
  const storedOk =
    algo === PASSWORD_ALGO &&
    rounds === PBKDF2_ITERATIONS &&
    Boolean(salt && salt.byteLength === 16) &&
    Boolean(expected && expected.byteLength === 32);
  return Boolean(same && storedOk);
}

export async function ensureSchema(db) {
  for (const sql of SCHEMA) await db.prepare(sql).run();
  for (const sql of ALTERS) {
    try {
      await db.prepare(sql).run();
    } catch {
      // The column is already there on databases created from the current schema.
    }
  }
}

function clientIp(request) {
  const headers = request && request.headers;
  const raw =
    (headers && (headers.get("cf-connecting-ip") || headers.get("x-forwarded-for"))) || "local";
  return String(raw).split(",")[0].trim().slice(0, 80) || "local";
}

function ipBucket(request) {
  return `ip:${clientIp(request)}`;
}

function emailBucket(email) {
  return `email:${normalizeEmail(email)}`;
}

async function attemptRow(db, bucket) {
  return db
    .prepare("SELECT failures, window_start, next_at, locked_until FROM login_attempts WHERE bucket = ?")
    .bind(bucket)
    .first();
}

function attemptBlocked(row, now) {
  return Boolean(row && (Number(row.next_at) > now || Number(row.locked_until) > now));
}

export async function loginThrottled(db, request, email, now) {
  const ip = await attemptRow(db, ipBucket(request));
  const mail = await attemptRow(db, emailBucket(email));
  return attemptBlocked(ip, now) || attemptBlocked(mail, now);
}

async function bumpAttempt(db, bucket, now) {
  const row = await attemptRow(db, bucket);
  const failures = row ? Number(row.failures) + 1 : 1;
  const windowStart = row ? Number(row.window_start) : now;
  const nextAt = now + backoffSeconds(failures);
  await db
    .prepare(
      `INSERT INTO login_attempts (bucket, failures, window_start, next_at, locked_until) VALUES (?, ?, ?, ?, 0)
       ON CONFLICT(bucket) DO UPDATE SET failures = excluded.failures, window_start = excluded.window_start, next_at = excluded.next_at, locked_until = 0`,
    )
    .bind(bucket, failures, windowStart, nextAt)
    .run();
}

export async function recordLoginFailure(db, request, email, now) {
  await bumpAttempt(db, ipBucket(request), now);
  await bumpAttempt(db, emailBucket(email), now);
}

export async function clearLoginFailures(db, request, email) {
  await db.prepare("DELETE FROM login_attempts WHERE bucket = ?").bind(emailBucket(email)).run();
  void request;
}

async function findUserByEmail(db, email) {
  return db.prepare("SELECT * FROM users WHERE email = ?").bind(normalizeEmail(email)).first();
}

function cookieToken() {
  return bytesToHex(crypto.getRandomValues(new Uint8Array(32)));
}

export function accountCookie(token) {
  return /^[a-f0-9]{64}$/.test(String(token || ""));
}

function sessionSecret(env) {
  const secret = env && typeof env.SESSION_SECRET === "string" ? env.SESSION_SECRET.trim() : "";
  return secret.length >= 16 ? secret : "";
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signed = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return bytesToHex(new Uint8Array(signed));
}

async function legacyRawId(token, env) {
  if (!/^[a-f0-9]{64}\.[a-f0-9]{64}$/i.test(String(token || ""))) return "";
  const secret = sessionSecret(env);
  if (!secret) return "";
  const id = token.slice(0, 64).toLowerCase();
  const sig = token.slice(65).toLowerCase();
  const expected = await hmacHex(secret, id);
  const left = hexToBytes(expected);
  const right = hexToBytes(sig);
  if (!left || !right || !bytesEqual(left, right)) return "";
  return id;
}

function readCookie(request, name) {
  const header = (request && request.headers && request.headers.get("cookie")) || "";
  const prefix = `${name}=`;
  for (const part of header.split(";")) {
    const trimmed = part.trim();
    if (trimmed.startsWith(prefix)) return trimmed.slice(prefix.length);
  }
  return "";
}

async function touchSession(db, table, id, seen, now) {
  if (now - Number(seen || 0) < 60) return;
  await db.prepare(`UPDATE ${table} SET last_seen_at = ? WHERE id = ?`).bind(now, id).run();
}

export async function issueInvite(db, userId, purpose, now) {
  const token = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const id = crypto.randomUUID();
  const ttl = purpose === "setup" ? SETUP_TTL : INVITE_TTL;
  await db.prepare("UPDATE invites SET used_at = ? WHERE user_id = ? AND used_at IS NULL").bind(now, userId).run();
  await db
    .prepare(
      "INSERT INTO invites (id, user_id, token_hash, purpose, expires_at, used_at, created_at) VALUES (?, ?, ?, ?, ?, NULL, ?)",
    )
    .bind(id, userId, await sha256Hex(token), purpose, now + ttl, now)
    .run();
  return token;
}

export function inviteUrl(request, token) {
  return new URL(`/invite/${token}`, request.url).toString();
}

export async function issueFirstAdminLink(db, env, now) {
  const email = configuredAdminEmail(env);
  if (!email) return null;
  const active = await db
    .prepare("SELECT id FROM users WHERE role = 'admin' AND status = 'active' LIMIT 1")
    .first();
  if (active) return null;
  const other = await db
    .prepare("SELECT id, email, status FROM users WHERE role = 'admin' AND email != ? LIMIT 1")
    .bind(email)
    .first();
  if (other) return null;
  let user = await findUserByEmail(db, email);
  if (user && user.role !== "admin") return null;
  if (user && user.status === "disabled") return null;
  if (!user) {
    const id = crypto.randomUUID();
    await db
      .prepare(
        "INSERT INTO users (id, email, password_hash, password_salt, password_algo, password_iterations, role, status, created_at, last_login_at) VALUES (?, ?, '', '', ?, ?, 'admin', 'invited', ?, NULL)",
      )
      .bind(id, email, PASSWORD_ALGO, PBKDF2_ITERATIONS, now)
      .run();
    user = await findUserByEmail(db, email);
  }
  if (!user) return null;
  const token = await issueInvite(db, user.id, "setup", now);
  return { email, token, expiresAt: now + SETUP_TTL };
}

export async function openInvite(db, token, now) {
  if (!token || token.length < 20 || token.length > 200) return null;
  const row = await db
    .prepare(
      `SELECT invites.id AS invite_id, invites.purpose, invites.expires_at, invites.used_at,
              users.id, users.email, users.role, users.status
       FROM invites JOIN users ON users.id = invites.user_id
       WHERE invites.token_hash = ?`,
    )
    .bind(await sha256Hex(token))
    .first();
  if (!row || row.used_at || Number(row.expires_at) < now || row.status === "disabled") return null;
  return row;
}

export async function acceptInvite(db, token, password, confirm, now) {
  const invite = await openInvite(db, token, now);
  if (!invite) return { error: "This link is no longer valid." };
  if (invite.purpose === "setup") {
    const active = await db
      .prepare("SELECT id FROM users WHERE role = 'admin' AND status = 'active' LIMIT 1")
      .first();
    if (active || invite.role !== "admin") {
      return { error: "This link is no longer valid." };
    }
  }
  if (!passwordOk(password)) return { error: "Use at least 12 characters.", email: invite.email };
  if (password !== confirm) return { error: "Those passwords do not match.", email: invite.email };
  const hashed = await hashPassword(password);
  const claimed = await db
    .prepare("UPDATE invites SET used_at = ? WHERE id = ? AND used_at IS NULL")
    .bind(now, invite.invite_id)
    .run();
  const changes = claimed && claimed.meta ? Number(claimed.meta.changes) : 0;
  if (!changes) return { error: "This link is no longer valid.", email: invite.email };
  await db.prepare("UPDATE invites SET used_at = ? WHERE user_id = ? AND used_at IS NULL").bind(now, invite.id).run();
  await db
    .prepare(
      "UPDATE users SET password_hash = ?, password_salt = ?, password_algo = ?, password_iterations = ?, status = 'active', last_login_at = ? WHERE id = ?",
    )
    .bind(hashed.hash, hashed.salt, hashed.algo, hashed.iterations, now, invite.id)
    .run();
  const session = await createAccountSession(db, invite.id, now);
  return session ? { session, email: invite.email } : { error: "Sign-in is unavailable.", email: invite.email };
}

export async function createAccountSession(db, userId, now) {
  const token = cookieToken();
  const id = await sha256Hex(token);
  const exp = now + ABSOLUTE_TTL;
  await db
    .prepare(
      "INSERT INTO sessions (id, user_id, expires_at, last_seen_at, revoked_at, created_at) VALUES (?, ?, ?, ?, NULL, ?)",
    )
    .bind(id, userId, exp, now, now)
    .run();
  return token;
}

async function sessionLive(row, now) {
  if (!row || row.revoked_at) return false;
  if (Number(row.expires_at) < now) return false;
  if (row.last_seen_at == null) return true;
  if (now - Number(row.last_seen_at) > IDLE_TTL) return false;
  return true;
}

async function sessionIdForCookie(token, env) {
  if (accountCookie(token)) return sha256Hex(token);
  return legacyRawId(token, env);
}

export async function readAccountSession(db, request, now, env) {
  const token = readCookie(request, ACCOUNT_COOKIE);
  const id = await sessionIdForCookie(token, env);
  if (!id) return null;
  const row = await db
    .prepare(
      `SELECT sessions.id AS session_id, sessions.expires_at, sessions.last_seen_at, sessions.revoked_at, sessions.created_at,
              users.email, users.role, users.status
       FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.id = ?`,
    )
    .bind(id)
    .first();
  if (!row || row.status !== "active" || !(await sessionLive(row, now))) return null;
  await touchSession(db, "sessions", row.session_id, row.last_seen_at || row.created_at, now);
  return { user: row.email, role: row.role, exp: Number(row.expires_at), sessionId: row.session_id, account: true };
}

export async function revokeSession(db, sessionId, now) {
  if (!sessionId) return;
  await db.prepare("UPDATE sessions SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL").bind(now, sessionId).run();
}

async function revokeUserSessions(db, userId, now) {
  await db.prepare("UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL").bind(now, userId).run();
}

export async function createSharedSession(db, subject, now) {
  const name = String(subject || "").trim();
  if (!db || !name || /[|\r\n]/.test(name)) return "";
  const token = cookieToken();
  const id = await sha256Hex(token);
  const exp = now + ABSOLUTE_TTL;
  await db
    .prepare(
      "INSERT INTO shared_sessions (id, subject, expires_at, last_seen_at, revoked_at, created_at) VALUES (?, ?, ?, ?, NULL, ?)",
    )
    .bind(id, name, exp, now, now)
    .run();
  return token;
}

export async function readSharedSession(db, request, now, env) {
  const token = readCookie(request, SHARED_COOKIE);
  let id = accountCookie(token) ? await sha256Hex(token) : "";
  if (!id) id = await legacyRawId(readCookie(request, ACCOUNT_COOKIE), env);
  if (!db || !id) return null;
  const row = await db
    .prepare("SELECT id, subject, expires_at, last_seen_at, revoked_at, created_at FROM shared_sessions WHERE id = ?")
    .bind(id)
    .first();
  if (!(await sessionLive(row, now))) return null;
  await touchSession(db, "shared_sessions", row.id, row.last_seen_at || row.created_at, now);
  return { user: row.subject, role: "viewer", exp: Number(row.expires_at), sessionId: row.id, account: false, shared: true };
}

export async function revokeSharedSession(db, sessionId, now) {
  if (!db || !sessionId) return;
  await db
    .prepare("UPDATE shared_sessions SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL")
    .bind(now, sessionId)
    .run();
}

function recognizedPassword(user) {
  if (!user || user.status !== "active" || !user.password_hash) return false;
  const algo = user.password_algo || PASSWORD_ALGO;
  return algo === PASSWORD_ALGO && Number(user.password_iterations) === PBKDF2_ITERATIONS;
}

async function dummyVerify(password) {
  return verifyPassword(password || "invalid-password", DUMMY_SALT, DUMMY_HASH, PBKDF2_ITERATIONS, PASSWORD_ALGO);
}

export async function changePassword(db, session, current, password, confirm, now, request) {
  if (!session || !session.account) return { error: "This sign-in does not have its own password." };
  if (request && (await loginThrottled(db, request, session.user, now))) {
    await dummyVerify(current);
    return { error: "Too many attempts. Try again later.", status: 429 };
  }
  const user = await findUserByEmail(db, session.user);
  const active = recognizedPassword(user);
  const match = await verifyPassword(
    current || "invalid-password",
    active ? user.password_salt : DUMMY_SALT,
    active ? user.password_hash : DUMMY_HASH,
    PBKDF2_ITERATIONS,
    PASSWORD_ALGO,
  );
  if (!passwordOk(password)) return { error: "Use at least 12 characters." };
  if (password !== confirm) return { error: "Those passwords do not match." };
  if (!match || !active) {
    if (request) await recordLoginFailure(db, request, session.user, now);
    return { error: "That password is wrong.", status: 401 };
  }
  const hashed = await hashPassword(password);
  await db
    .prepare(
      "UPDATE users SET password_hash = ?, password_salt = ?, password_algo = ?, password_iterations = ? WHERE id = ?",
    )
    .bind(hashed.hash, hashed.salt, hashed.algo, hashed.iterations, user.id)
    .run();
  await revokeUserSessions(db, user.id, now);
  if (request) await clearLoginFailures(db, request, session.user);
  const fresh = await createAccountSession(db, user.id, now);
  return fresh ? { notice: "Password saved.", session: fresh } : { error: "Sign-in is unavailable.", status: 503 };
}

export async function authenticateAccount(db, request, emailRaw, password, now) {
  const email = normalizeEmail(emailRaw);
  const throttled = await loginThrottled(db, request, email, now);
  const user = email ? await findUserByEmail(db, email) : null;
  const active = recognizedPassword(user);
  const match = await verifyPassword(
    password || "invalid-password",
    active ? user.password_salt : DUMMY_SALT,
    active ? user.password_hash : DUMMY_HASH,
    PBKDF2_ITERATIONS,
    PASSWORD_ALGO,
  );
  if (throttled) return { throttled: true, email };
  if (!match || !active) return { bad: true, email };
  await clearLoginFailures(db, request, email);
  await db.prepare("UPDATE users SET last_login_at = ? WHERE id = ?").bind(now, user.id).run();
  const session = await createAccountSession(db, user.id, now);
  if (!session) return { unavailable: true };
  return { session, email: user.email, role: user.role };
}

async function adminCount(db) {
  const row = await db
    .prepare("SELECT COUNT(*) AS n FROM users WHERE role = 'admin' AND status != 'disabled'")
    .first();
  return Number(row && row.n) || 0;
}

export async function listUsers(db) {
  const listed = await db
    .prepare("SELECT id, email, role, status, created_at, last_login_at FROM users ORDER BY created_at, email")
    .all();
  return (listed && listed.results) || [];
}

async function insertUser(db, email, role, status, hashed, now) {
  const id = crypto.randomUUID();
  await db
    .prepare(
      "INSERT INTO users (id, email, password_hash, password_salt, password_algo, password_iterations, role, status, created_at, last_login_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)",
    )
    .bind(
      id,
      email,
      hashed ? hashed.hash : "",
      hashed ? hashed.salt : "",
      PASSWORD_ALGO,
      hashed ? hashed.iterations : PBKDF2_ITERATIONS,
      role,
      status,
      now,
    )
    .run();
  return id;
}

export async function adminAct(db, request, fields, now) {
  const action = String(fields.action || "");
  const email = normalizeEmail(fields.email || "");
  const userId = String(fields.user || "");
  if (action === "add") {
    if (!emailOk(email)) return { error: "Enter a full email address." };
    const role = fields.role === "admin" ? "admin" : "viewer";
    const existing = await findUserByEmail(db, email);
    if (existing && existing.status === "disabled") return { error: "That person is disabled. Re-enable them instead." };
    if (existing && existing.status === "active") return { error: "That person already has an account." };
    const temp = String(fields.password || "");
    if (temp) {
      if (!passwordOk(temp)) return { error: "Use at least 12 characters." };
      const hashed = await hashPassword(temp);
      if (existing) {
        await db
          .prepare(
            "UPDATE users SET password_hash = ?, password_salt = ?, password_algo = ?, password_iterations = ?, role = ?, status = 'active' WHERE id = ?",
          )
          .bind(hashed.hash, hashed.salt, hashed.algo, hashed.iterations, role, existing.id)
          .run();
        await revokeUserSessions(db, existing.id, now);
      } else {
        await insertUser(db, email, role, "active", hashed, now);
      }
      return { notice: `${email} can sign in with the password you set.`, email };
    }
    let id = existing && existing.id;
    if (!id) id = await insertUser(db, email, role, "invited", null, now);
    const token = await issueInvite(db, id, "invite", now);
    const link = token ? inviteUrl(request, token) : "";
    return { notice: "Copy this one-time link. It expires in 24 hours.", link, email };
  }
  const user = userId ? await db.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first() : null;
  if (!user) return { error: "That person is not on the list." };
  if (action === "resend" || action === "reset") {
    if (action === "reset") {
      await revokeUserSessions(db, user.id, now);
      await db
        .prepare(
          "UPDATE users SET password_hash = '', password_salt = '', password_algo = ?, password_iterations = ?, status = 'invited' WHERE id = ?",
        )
        .bind(PASSWORD_ALGO, PBKDF2_ITERATIONS, user.id)
        .run();
    }
    const purpose = action === "reset" ? "reset" : "invite";
    const token = await issueInvite(db, user.id, purpose, now);
    const link = token ? inviteUrl(request, token) : "";
    return {
      link,
      email: user.email,
      notice: action === "reset" ? "Password cleared. Send this set-password link." : "New invite link. The previous link no longer works.",
    };
  }
  if (action === "role") {
    const role = fields.role === "admin" ? "admin" : "viewer";
    if (user.role === "admin" && role !== "admin" && (await adminCount(db)) <= 1) {
      return { error: "Keep at least one admin." };
    }
    if (role !== user.role) {
      await db.prepare("UPDATE users SET role = ? WHERE id = ?").bind(role, user.id).run();
      await revokeUserSessions(db, user.id, now);
    }
    return { notice: `${user.email} is ${role}.` };
  }
  if (action === "disable") {
    if (user.role === "admin" && (await adminCount(db)) <= 1) return { error: "Keep at least one admin." };
    await db.prepare("UPDATE users SET status = 'disabled' WHERE id = ?").bind(user.id).run();
    await revokeUserSessions(db, user.id, now);
    return { notice: `${user.email} is disabled.` };
  }
  if (action === "enable") {
    const status = user.password_hash ? "active" : "invited";
    await db.prepare("UPDATE users SET status = ? WHERE id = ?").bind(status, user.id).run();
    return { notice: `${user.email} is ${status}.` };
  }
  if (action === "remove") {
    if (user.role === "admin" && (await adminCount(db)) <= 1) return { error: "Keep at least one admin." };
    await db.prepare("DELETE FROM sessions WHERE user_id = ?").bind(user.id).run();
    await db.prepare("DELETE FROM invites WHERE user_id = ?").bind(user.id).run();
    await db.prepare("DELETE FROM users WHERE id = ?").bind(user.id).run();
    return { notice: `${user.email} was removed.` };
  }
  return { error: "That action is not available." };
}

export function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => {
    if (char === "&") return "&amp;";
    if (char === "<") return "&lt;";
    if (char === ">") return "&gt;";
    if (char === '"') return "&quot;";
    return "&#39;";
  });
}

const SCORE_PAGES = [
  ["dashboard", "Dashboard", "/"],
  ["sales", "Sales", "/?page=sales"],
  ["lost_revenue", "Lost Revenue", "/?page=lost_revenue"],
  ["missing_items", "Missing Items", "/?page=missing_items"],
  ["five_star", "5 Star", "/?page=five_star"],
  ["pre_sub_oos", "Pre-Sub", "/?page=pre_sub_oos"],
  ["pick_path", "Pick Path", "/?page=pick_path"],
  ["prep_not_ready", "Prep", "/?page=prep_not_ready"],
  ["dynacap", "Dynacap", "/?page=dynacap"],
  ["schedule_quality", "Schedule Quality", "/?page=schedule_quality"],
  ["schedule", "Schedule Check", "/?page=schedule"],
  ["picker_scorecard", "Picker", "/?page=picker_scorecard"],
  ["pph", "PPH", "/?page=pph"],
  ["labor", "Labor", "/?page=labor"],
];

function homeChrome(chrome) {
  const pages = SCORE_PAGES.map(([, title, href]) => `<li><a href="${href}">${escapeHtml(title)}</a></li>`).join("");
  const settings = [];
  if (chrome.admin) {
    const current = chrome.here === "admin" ? ' aria-current="page"' : "";
    settings.push(`<li><a href="/admin"${current}>User management</a></li>`);
  }
  if (chrome.account) {
    const current = chrome.here === "account" ? ' aria-current="page"' : "";
    settings.push(`<li><a href="/account"${current}>Account</a></li>`);
  }
  const settingsBlock = settings.length
    ? `<p class="drawer-label">Settings</p><ul class="pages drawer-settings">${settings.join("")}</ul>`
    : "";
  return `<div id="scrim" hidden></div>
  <nav id="drawer" aria-label="Pages">
    <div class="drawer-head"><p class="drawer-title">Pages</p><button type="button" class="drawer-close" data-close-drawer>Close</button></div>
    <ul class="pages">${pages}</ul>
    <div class="drawer-foot">${settingsBlock}<form method="POST" action="/logout" class="drawer-logout-form"><button type="submit" class="drawer-logout">Logout</button></form></div>
  </nav>
  <header class="top">
    <div class="header-tools">
      <a class="header-back" href="/"><svg viewBox="0 0 20 20" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" d="M12.5 4.5L7 10l5.5 5.5"/></svg><span>Dashboard</span></a>
      <button id="nav-toggle" type="button" aria-controls="drawer" aria-expanded="false">Pages</button>
    </div>
    <p class="brand-lockup">
      <span class="wordmark" aria-label="Fulfillment Heartbeat"><span class="fulfill">Fulfill</span><span class="ment">ment</span></span>
      <svg class="heart" viewBox="0 0 36 33" aria-hidden="true">
        <path fill="#3d8dff" d="M18 32.4C18 27.36 0 20.88 1.8 12.96C3.6 1.44 13.68 1.44 18 7.92C22.32 1.44 32.4 1.44 34.2 12.96C36 20.88 18 27.36 18 32.4Z"/>
      </svg>
      <svg class="pulse" viewBox="0 0 52 22" aria-hidden="true">
        <path fill="none" stroke="#00A9E0" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" d="M0 14.5L5.1 14.5L8.2 17.5L15.3 1.5L21.4 20.5L25.5 14.5Q30.6 7.5 35.7 14.5L51 14.5"/>
      </svg>
    </p>
    <h1>${escapeHtml(chrome.heading)}</h1>
  </header>`;
}

function shell(title, heading, body, chrome) {
  const head = chrome
    ? homeChrome({ ...chrome, heading })
    : `<header class="top">
    <p class="brand-lockup">
      <span class="wordmark" aria-label="Fulfillment Heartbeat"><span class="fulfill">Fulfill</span><span class="ment">ment</span></span>
      <svg class="heart" viewBox="0 0 36 33" aria-hidden="true">
        <path fill="#3d8dff" d="M18 32.4C18 27.36 0 20.88 1.8 12.96C3.6 1.44 13.68 1.44 18 7.92C22.32 1.44 32.4 1.44 34.2 12.96C36 20.88 18 27.36 18 32.4Z"/>
      </svg>
      <svg class="pulse" viewBox="0 0 52 22" aria-hidden="true">
        <path fill="none" stroke="#00A9E0" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" d="M0 14.5L5.1 14.5L8.2 17.5L15.3 1.5L21.4 20.5L25.5 14.5Q30.6 7.5 35.7 14.5L51 14.5"/>
      </svg>
    </p>
    <h1>${escapeHtml(heading)}</h1>
  </header>`;
  const navScript = chrome ? `<script src="/shell-nav.js?v=1"></script>` : "";
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="icon" href="/favicon-32.png" type="image/png" sizes="32x32">
  <link rel="icon" href="/favicon-16.png" type="image/png" sizes="16x16">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <link rel="stylesheet" href="/login.css?v=2">
  <script src="/nav-boot.js?v=3"></script>
</head>
<body>
  ${head}
  <main class="login-main">${body}</main>
  ${navScript}
</body>
</html>`;
}

export function loginHTML(message, email) {
  const alert = message ? `<p class="login-error" role="alert">${escapeHtml(message)}</p>` : "";
  return shell(
    "Sign in · Fulfillment Heartbeat",
    "Sign in",
    `<form class="login-card" method="POST" action="/login" autocomplete="on">
      <h2>Fulfillment Heartbeat</h2>
      ${alert}
      <label>Email or username<input name="email" type="text" inputmode="email" autocomplete="username" autocapitalize="none" autocorrect="off" spellcheck="false" required value="${escapeHtml(email)}"></label>
      <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
      <button type="submit">Sign in</button>
    </form>`,
  );
}

export function inviteHTML(email, token, message) {
  const alert = message ? `<p class="login-error" role="alert">${escapeHtml(message)}</p>` : "";
  return shell(
    "Set password · Fulfillment Heartbeat",
    "Set password",
    `<form class="login-card" method="POST" action="/invite/${escapeHtml(token)}" autocomplete="on">
      <h2>${escapeHtml(email || "Fulfillment Heartbeat")}</h2>
      ${alert}
      <label>New password<input name="password" type="password" autocomplete="new-password" minlength="12" required></label>
      <label>Confirm password<input name="confirm" type="password" autocomplete="new-password" minlength="12" required></label>
      <p class="hint">At least 12 characters. This link works once.</p>
      <button type="submit">Save and sign in</button>
    </form>`,
  );
}

export function deniedHTML(chrome) {
  return shell(
    "People · Fulfillment Heartbeat",
    "People",
    `<section class="login-card"><h2>Admins only</h2><p>This page is for an admin account.</p></section>`,
    chrome || { admin: false, account: false, here: "" },
  );
}

export function accountHTML(email, message, notice, chrome) {
  const alert = message ? `<p class="login-error" role="alert">${escapeHtml(message)}</p>` : notice ? `<p class="hint">${escapeHtml(notice)}</p>` : "";
  return shell(
    "Account · Fulfillment Heartbeat",
    "Account",
    `<form class="login-card" method="POST" action="/account" autocomplete="on">
      <h2>${escapeHtml(email || "Change password")}</h2>
      ${alert}
      <label>Current password<input name="current" type="password" autocomplete="current-password" required></label>
      <label>New password<input name="password" type="password" autocomplete="new-password" minlength="12" required></label>
      <label>Confirm password<input name="confirm" type="password" autocomplete="new-password" minlength="12" required></label>
      <p class="hint">At least 12 characters.</p>
      <button type="submit">Save password</button>
    </form>`,
    chrome || { admin: false, account: true, here: "account" },
  );
}

export function accountSharedHTML(chrome) {
  return shell(
    "Account · Fulfillment Heartbeat",
    "Account",
    `<section class="login-card"><h2>Shared sign-in</h2><p>This sign-in does not have its own password.</p></section>`,
    chrome || { admin: false, account: false, here: "account" },
  );
}

function userActions(user) {
  const id = escapeHtml(user.id);
  const button = (action, label) => `<button type="submit" name="action" value="${action}" form="user-${id}">${label}</button>`;
  const parts = [];
  if (user.status !== "active") parts.push(button("resend", "New link"));
  if (user.status === "active") parts.push(button("reset", "Reset password"));
  if (user.role === "admin") parts.push(button("role", "Make viewer"));
  else parts.push(button("role", "Make admin"));
  if (user.status === "disabled") parts.push(button("enable", "Re-enable"));
  else parts.push(button("disable", "Disable"));
  parts.push(button("remove", "Remove"));
  return parts.join("");
}

export function adminHTML({ users, notice, error, link, chrome }) {
  const alert = error ? `<p class="login-error" role="alert">${escapeHtml(error)}</p>` : notice ? `<p class="hint">${escapeHtml(notice)}</p>` : "";
  const linkBox = link
    ? `<label>One-time link<input id="invite-link" readonly value="${escapeHtml(link)}"></label><button type="button" data-copy="invite-link">Copy</button>`
    : "";
  const cards = (users || [])
    .map((user) => {
      const when = user.last_login_at
        ? new Date(Number(user.last_login_at) * 1000).toISOString().slice(0, 16).replace("T", " ")
        : "never";
      const nextRole = user.role === "admin" ? "viewer" : "admin";
      return `<article class="user-card">
        <h2>${escapeHtml(user.email)}</h2>
        <p class="hint">${escapeHtml(user.role)} · ${escapeHtml(user.status)} · last sign-in ${escapeHtml(when)}</p>
        <form id="user-${escapeHtml(user.id)}" method="POST" action="/admin"><input type="hidden" name="user" value="${escapeHtml(user.id)}"><input type="hidden" name="role" value="${nextRole}"></form>
        <div class="row-actions">${userActions(user)}</div>
      </article>`;
    })
    .join("");
  return shell(
    "People · Fulfillment Heartbeat",
    "People",
    `<section class="login-card">
      <h2>Add a person</h2>
      ${alert}
      ${linkBox}
      <p class="hint">Email is off. Copy the invite link. A blank password makes a one-time link instead.</p>
      <form method="POST" action="/admin">
        <input type="hidden" name="action" value="add">
        <label>Email<input name="email" type="email" autocomplete="off" autocapitalize="none" required></label>
        <label>Role<select name="role"><option value="viewer">Viewer</option><option value="admin">Admin</option></select></label>
        <label>Temporary password<input name="password" type="password" autocomplete="new-password" minlength="12"></label>
        <button type="submit">Add user</button>
      </form>
    </section>
    <div class="user-list">${cards}</div>
    <script src="/auth-copy.js"></script>`,
    chrome || { admin: true, account: false, here: "admin" },
  );
}
