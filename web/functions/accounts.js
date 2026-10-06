// Per-user accounts on the HB_AUTH D1 binding.
// Passwords are PBKDF2-SHA256 with a per-user salt. Sessions live in D1 so disable can revoke them.
// Nothing in this file is a password or an invite token.

export const PBKDF2_ITERATIONS = 100_000;
export const INVITE_TTL = 7 * 24 * 60 * 60;
export const SESSION_TTL = 30 * 24 * 60 * 60;
export const LOGIN_WINDOW = 15 * 60;
export const LOGIN_LIMIT = 8;

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
  `CREATE TABLE IF NOT EXISTS login_attempts (
    bucket TEXT PRIMARY KEY,
    failures INTEGER NOT NULL,
    window_start INTEGER NOT NULL,
    locked_until INTEGER NOT NULL DEFAULT 0
  )`,
  "CREATE INDEX IF NOT EXISTS invites_user ON invites (user_id, used_at)",
  "CREATE INDEX IF NOT EXISTS sessions_user ON sessions (user_id, revoked_at)",
];

const encoder = new TextEncoder();

export function authDb(env) {
  return (env && (env.HB_AUTH || env.DB)) || null;
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

function envSecret(env, key) {
  const value = env && env[key];
  return typeof value === "string" ? value.trim() : "";
}

export function sessionSecret(env) {
  const secret = envSecret(env, "SESSION_SECRET");
  return secret.length >= 16 ? secret : "";
}

function bytesToHex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function hexToBytes(hex) {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i += 1) out[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

function base64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
}

function base64urlDecode(text) {
  const pad = text.length % 4 === 0 ? "" : "=".repeat(4 - (text.length % 4));
  const binary = atob(String(text).replaceAll("-", "+").replaceAll("_", "/") + pad);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(String(text)));
  return bytesToHex(new Uint8Array(digest));
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signed = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return bytesToHex(new Uint8Array(signed));
}

async function aesKey(secret) {
  const raw = await crypto.subtle.digest("SHA-256", encoder.encode(secret));
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

async function encryptToken(secret, token) {
  const key = await aesKey(secret);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoder.encode(token)));
  const packed = new Uint8Array(iv.length + cipher.length);
  packed.set(iv, 0);
  packed.set(cipher, iv.length);
  return base64url(packed);
}

async function decryptToken(secret, packed) {
  try {
    const bytes = base64urlDecode(packed);
    if (bytes.length < 13) return "";
    const key = await aesKey(secret);
    const plain = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: bytes.slice(0, 12) },
      key,
      bytes.slice(12),
    );
    return new TextDecoder().decode(plain);
  } catch {
    return "";
  }
}

export async function hashPassword(password, iterations = PBKDF2_ITERATIONS) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
    key,
    256,
  );
  return { hash: bytesToHex(new Uint8Array(bits)), salt: bytesToHex(salt), iterations };
}

export async function verifyPassword(password, saltHex, expectedHash, iterations) {
  if (!saltHex || !expectedHash) return false;
  const rounds = Number(iterations) || PBKDF2_ITERATIONS;
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt: hexToBytes(saltHex), iterations: rounds, hash: "SHA-256" },
    key,
    256,
  );
  const actual = bytesToHex(new Uint8Array(bits));
  if (actual.length !== expectedHash.length) return false;
  let diff = 0;
  for (let i = 0; i < actual.length; i += 1) diff |= actual.charCodeAt(i) ^ expectedHash.charCodeAt(i);
  return diff === 0;
}

export async function ensureSchema(db) {
  for (const sql of SCHEMA) await db.prepare(sql).run();
}

function clientIp(request) {
  return (
    (request && request.headers && (request.headers.get("cf-connecting-ip") || request.headers.get("x-forwarded-for"))) ||
    "local"
  )
    .split(",")[0]
    .trim()
    .slice(0, 80);
}

async function attemptRow(db, bucket) {
  return db.prepare("SELECT failures, window_start, locked_until FROM login_attempts WHERE bucket = ?").bind(bucket).first();
}

export async function loginThrottled(db, request, email, now) {
  const buckets = [`ip:${clientIp(request)}`, `email:${normalizeEmail(email)}`];
  for (const bucket of buckets) {
    const row = await attemptRow(db, bucket);
    if (row && Number(row.locked_until) > now) return true;
  }
  return false;
}

export async function recordLoginFailure(db, request, email, now) {
  const buckets = [`ip:${clientIp(request)}`, `email:${normalizeEmail(email)}`];
  for (const bucket of buckets) {
    const row = await attemptRow(db, bucket);
    const fresh = !row || now - Number(row.window_start) > LOGIN_WINDOW;
    const failures = fresh ? 1 : Number(row.failures) + 1;
    const windowStart = fresh ? now : Number(row.window_start);
    const locked = failures >= LOGIN_LIMIT ? now + LOGIN_WINDOW : 0;
    await db
      .prepare(
        `INSERT INTO login_attempts (bucket, failures, window_start, locked_until) VALUES (?, ?, ?, ?)
         ON CONFLICT(bucket) DO UPDATE SET failures = excluded.failures, window_start = excluded.window_start, locked_until = excluded.locked_until`,
      )
      .bind(bucket, failures, windowStart, locked)
      .run();
  }
}

export async function clearLoginFailures(db, request, email) {
  await db.prepare("DELETE FROM login_attempts WHERE bucket = ? OR bucket = ?").bind(`ip:${clientIp(request)}`, `email:${normalizeEmail(email)}`).run();
}

async function findUserByEmail(db, email) {
  return db.prepare("SELECT * FROM users WHERE email = ?").bind(normalizeEmail(email)).first();
}

export async function issueInvite(db, env, userId, purpose, now) {
  const secret = sessionSecret(env);
  if (!secret) return null;
  const token = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const id = crypto.randomUUID();
  await db.prepare("UPDATE invites SET used_at = ? WHERE user_id = ? AND used_at IS NULL").bind(now, userId).run();
  await db
    .prepare(
      "INSERT INTO invites (id, user_id, token_hash, token_enc, purpose, expires_at, used_at, created_at) VALUES (?, ?, ?, ?, ?, ?, NULL, ?)",
    )
    .bind(id, userId, await sha256Hex(token), await encryptToken(secret, token), purpose, now + INVITE_TTL, now)
    .run();
  return token;
}

export function inviteUrl(request, token) {
  return new URL(`/invite/${token}`, request.url).toString();
}

export async function ensureAdminSeed(db, env, now) {
  const email = normalizeEmail(envSecret(env, "ADMIN_EMAIL"));
  if (!emailOk(email)) return null;
  const admins = await db.prepare("SELECT id FROM users WHERE role = 'admin' LIMIT 1").first();
  if (admins) return null;
  const id = crypto.randomUUID();
  try {
    await db
      .prepare(
        "INSERT INTO users (id, email, password_hash, password_salt, password_iterations, role, status, created_at, last_login_at) VALUES (?, ?, '', '', ?, 'admin', 'invited', ?, NULL)",
      )
      .bind(id, email, PBKDF2_ITERATIONS, now)
      .run();
  } catch {
    return findUserByEmail(db, email);
  }
  await issueInvite(db, env, id, "setup", now);
  return findUserByEmail(db, email);
}

export async function setupText(db, env, request, now) {
  const expected = envSecret(env, "SETUP_SECRET");
  const header = (request.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
  if (!expected || expected.length < 16 || header.length !== expected.length) return null;
  let diff = 0;
  for (let i = 0; i < expected.length; i += 1) diff |= expected.charCodeAt(i) ^ header.charCodeAt(i);
  if (diff !== 0) return null;
  await ensureAdminSeed(db, env, now);
  const email = normalizeEmail(envSecret(env, "ADMIN_EMAIL"));
  const user = await findUserByEmail(db, email);
  if (!user) return "ADMIN_EMAIL is not set to a usable address.\n";
  let invite = await db
    .prepare(
      "SELECT token_enc, expires_at, used_at FROM invites WHERE user_id = ? AND used_at IS NULL ORDER BY created_at DESC LIMIT 1",
    )
    .bind(user.id)
    .first();
  if (!invite || Number(invite.expires_at) < now) {
    await issueInvite(db, env, user.id, "setup", now);
    invite = await db
      .prepare(
        "SELECT token_enc, expires_at, used_at FROM invites WHERE user_id = ? AND used_at IS NULL ORDER BY created_at DESC LIMIT 1",
      )
      .bind(user.id)
      .first();
  }
  const token = invite ? await decryptToken(sessionSecret(env), invite.token_enc) : "";
  if (!token) return `Admin ${user.email} is ${user.status}. Issue a new link from People after you sign in.\n`;
  return `email: ${user.email}\ninvite: ${inviteUrl(request, token)}\n`;
}

export async function openInvite(db, token, now) {
  if (!token || token.length < 20 || token.length > 200) return null;
  const row = await db
    .prepare(
      `SELECT invites.id AS invite_id, invites.expires_at, invites.used_at, users.id, users.email, users.status
       FROM invites JOIN users ON users.id = invites.user_id
       WHERE invites.token_hash = ?`,
    )
    .bind(await sha256Hex(token))
    .first();
  if (!row || row.used_at || Number(row.expires_at) < now || row.status === "disabled") return null;
  return row;
}

export async function acceptInvite(db, env, token, password, confirm, now) {
  const invite = await openInvite(db, token, now);
  if (!invite) return { error: "This link is no longer valid." };
  if (String(password || "").length < 10) return { error: "Use at least 10 characters.", email: invite.email };
  if (password !== confirm) return { error: "Those passwords do not match.", email: invite.email };
  if (String(password).length > 200) return { error: "That password is too long.", email: invite.email };
  const hashed = await hashPassword(password);
  await db
    .prepare(
      "UPDATE users SET password_hash = ?, password_salt = ?, password_iterations = ?, status = 'active', last_login_at = ? WHERE id = ?",
    )
    .bind(hashed.hash, hashed.salt, hashed.iterations, now, invite.id)
    .run();
  await db.prepare("UPDATE invites SET used_at = ? WHERE user_id = ? AND used_at IS NULL").bind(now, invite.id).run();
  const session = await createAccountSession(db, env, invite.id, now);
  return session ? { session, email: invite.email } : { error: "Sign-in is unavailable.", email: invite.email };
}

export async function createAccountSession(db, env, userId, now) {
  const secret = sessionSecret(env);
  if (!secret) return "";
  const id = bytesToHex(crypto.getRandomValues(new Uint8Array(32)));
  const exp = now + SESSION_TTL;
  await db.prepare("INSERT INTO sessions (id, user_id, expires_at, revoked_at, created_at) VALUES (?, ?, ?, NULL, ?)").bind(id, userId, exp, now).run();
  const sig = await hmacHex(secret, id);
  return `${id}.${sig}`;
}

export function accountCookie(token) {
  if (!token) return "";
  return /^[a-f0-9]{64}\.[a-f0-9]{64}$/.test(token);
}

export async function readAccountSession(db, request, env, now) {
  const secret = sessionSecret(env);
  const header = (request && request.headers && request.headers.get("cookie")) || "";
  let token = "";
  for (const part of header.split(";")) {
    const trimmed = part.trim();
    if (trimmed.startsWith("hb_session=")) token = trimmed.slice("hb_session=".length);
  }
  if (!secret || !accountCookie(token)) return null;
  const id = token.slice(0, 64);
  const sig = token.slice(65);
  const expected = await hmacHex(secret, id);
  if (expected.length !== sig.length) return null;
  let diff = 0;
  for (let i = 0; i < expected.length; i += 1) diff |= expected.charCodeAt(i) ^ sig.charCodeAt(i);
  if (diff !== 0) return null;
  const row = await db
    .prepare(
      `SELECT sessions.id AS session_id, sessions.expires_at, sessions.revoked_at, users.email, users.role, users.status
       FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.id = ?`,
    )
    .bind(id)
    .first();
  if (!row || row.revoked_at || Number(row.expires_at) < now || row.status !== "active") return null;
  return { user: row.email, role: row.role, exp: Number(row.expires_at), sessionId: row.session_id, account: true };
}

export async function revokeSession(db, sessionId, now) {
  if (!sessionId) return;
  await db.prepare("UPDATE sessions SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL").bind(now, sessionId).run();
}

export async function changePassword(db, env, request, session, current, password, confirm, now) {
  if (!session || !session.account) return { error: "This sign-in does not have its own password." };
  if (await loginThrottled(db, request, session.user, now)) return { error: "Too many attempts. Try again later.", status: 429 };
  if (String(password || "").length < 10) return { error: "Use at least 10 characters." };
  if (password !== confirm) return { error: "Those passwords do not match." };
  if (String(password).length > 200) return { error: "That password is too long." };
  const user = await findUserByEmail(db, session.user);
  const active = Boolean(user && user.status === "active" && user.password_hash);
  const match = await verifyPassword(
    current || "invalid-password",
    active ? user.password_salt : bytesToHex(crypto.getRandomValues(new Uint8Array(16))),
    active ? user.password_hash : bytesToHex(new Uint8Array(32)),
    active ? user.password_iterations : PBKDF2_ITERATIONS,
  );
  if (!match) {
    await recordLoginFailure(db, request, session.user, now);
    return { error: "That password is wrong.", status: 401 };
  }
  const hashed = await hashPassword(password);
  await db
    .prepare("UPDATE users SET password_hash = ?, password_salt = ?, password_iterations = ? WHERE id = ?")
    .bind(hashed.hash, hashed.salt, hashed.iterations, user.id)
    .run();
  await db
    .prepare("UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND id != ? AND revoked_at IS NULL")
    .bind(now, user.id, session.sessionId)
    .run();
  await clearLoginFailures(db, request, session.user);
  return { notice: "Password saved." };
}

export async function authenticateAccount(db, env, request, emailRaw, password, now) {
  const email = normalizeEmail(emailRaw);
  if (await loginThrottled(db, request, email, now)) return { throttled: true };
  const user = email ? await findUserByEmail(db, email) : null;
  if (user && user.status === "invited") return { invited: true, email };
  const active = Boolean(user && user.status === "active" && user.password_hash);
  const salt = active ? user.password_salt : bytesToHex(crypto.getRandomValues(new Uint8Array(16)));
  const expected = active ? user.password_hash : bytesToHex(new Uint8Array(32));
  const iterations = active ? user.password_iterations : PBKDF2_ITERATIONS;
  const match = await verifyPassword(password || "invalid-password", salt, expected, iterations);
  if (!match) return { missing: !active, bad: active, email };
  await clearLoginFailures(db, request, email);
  await db.prepare("UPDATE users SET last_login_at = ? WHERE id = ?").bind(now, user.id).run();
  const session = await createAccountSession(db, env, user.id, now);
  if (!session) return { unavailable: true };
  return { session, email: user.email, role: user.role };
}

async function adminCount(db) {
  const row = await db.prepare("SELECT COUNT(*) AS n FROM users WHERE role = 'admin' AND status != 'disabled'").first();
  return Number(row && row.n) || 0;
}

export async function listUsers(db) {
  const listed = await db.prepare("SELECT id, email, role, status, created_at, last_login_at FROM users ORDER BY created_at, email").all();
  return (listed && listed.results) || [];
}

async function currentInviteLink(db, env, request, userId, now) {
  const row = await db
    .prepare(
      "SELECT token_enc, expires_at FROM invites WHERE user_id = ? AND used_at IS NULL ORDER BY created_at DESC LIMIT 1",
    )
    .bind(userId)
    .first();
  if (!row || Number(row.expires_at) < now) return "";
  const token = await decryptToken(sessionSecret(env), row.token_enc);
  return token ? inviteUrl(request, token) : "";
}

export async function adminAct(db, env, request, fields, now) {
  const action = String(fields.action || "");
  const email = normalizeEmail(fields.email || "");
  const userId = String(fields.user || "");
  if (action === "add") {
    if (!emailOk(email)) return { error: "Enter a full email address." };
    const role = fields.role === "admin" ? "admin" : "viewer";
    const existing = await findUserByEmail(db, email);
    if (existing && existing.status === "disabled") return { error: "That person is disabled. Re-enable them instead." };
    if (existing && existing.status === "active") return { error: "That person already has an account." };
    let id = existing && existing.id;
    if (!id) {
      id = crypto.randomUUID();
      await db
        .prepare(
          "INSERT INTO users (id, email, password_hash, password_salt, password_iterations, role, status, created_at, last_login_at) VALUES (?, ?, '', '', ?, ?, 'invited', ?, NULL)",
        )
        .bind(id, email, PBKDF2_ITERATIONS, role, now)
        .run();
    }
    const token = await issueInvite(db, env, id, "invite", now);
    const link = token ? inviteUrl(request, token) : "";
    const mailed = await maybeEmailInvite(env, email, link);
    return { notice: mailed.notice, link, email };
  }
  const user = userId ? await db.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first() : null;
  if (!user) return { error: "That person is not on the list." };
  if (action === "copy" || action === "resend" || action === "reset") {
    if (action === "copy") {
      const link = await currentInviteLink(db, env, request, user.id, now);
      if (link) return { link, email: user.email, notice: "Copy this invite link." };
    }
    if (action === "reset") {
      await db.prepare("UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL").bind(now, user.id).run();
      await db.prepare("UPDATE users SET password_hash = '', password_salt = '', status = 'invited' WHERE id = ?").bind(user.id).run();
    }
    const purpose = action === "reset" ? "reset" : "invite";
    const token = await issueInvite(db, env, user.id, purpose, now);
    const link = token ? inviteUrl(request, token) : "";
    const mailed = action === "resend" ? await maybeEmailInvite(env, user.email, link) : { notice: "" };
    return { link, email: user.email, notice: mailed.notice || (action === "reset" ? "Password cleared. Send this set-password link." : "New invite link.") };
  }
  if (action === "disable") {
    if (user.role === "admin" && (await adminCount(db)) <= 1) return { error: "Keep at least one admin." };
    await db.prepare("UPDATE users SET status = 'disabled' WHERE id = ?").bind(user.id).run();
    await db.prepare("UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL").bind(now, user.id).run();
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

export function emailInvitesEnabled(env) {
  return envSecret(env, "INVITE_EMAIL") === "1";
}

async function maybeEmailInvite(env, email, link) {
  if (!emailInvitesEnabled(env)) return { notice: "" };
  const url = envSecret(env, "INVITE_EMAIL_URL");
  if (!url || !link) return { notice: "Email is on, but no mailer is configured. Copy the link." };
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ to: email, link }),
      signal: AbortSignal.timeout(4000),
    });
    if (!response.ok) return { notice: "Email did not send. Copy the link." };
    return { notice: "Email sent. The link is below if you also want to copy it." };
  } catch {
    return { notice: "Email did not send. Copy the link." };
  }
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
  const pages = SCORE_PAGES.map(
    ([, title, href]) => `<li><a href="${href}">${escapeHtml(title)}</a></li>`,
  ).join("");
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
    <div class="drawer-foot">${settingsBlock}<a class="drawer-logout" href="/logout">Logout</a></div>
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
  <script src="/nav-boot.js?v=2"></script>
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
      <label>New password<input name="password" type="password" autocomplete="new-password" minlength="10" required></label>
      <label>Confirm password<input name="confirm" type="password" autocomplete="new-password" minlength="10" required></label>
      <p class="hint">At least 10 characters.</p>
      <button type="submit">Save and sign in</button>
    </form>`,
  );
}

export function deniedHTML(chrome) {
  return shell(
    "People · Fulfillment Heartbeat",
    "People",
    `<section class="login-card"><h2>Admins only</h2><p>This page is for an admin account.</p><p><a href="/">Back to Heartbeat</a></p></section>`,
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
      <label>New password<input name="password" type="password" autocomplete="new-password" minlength="10" required></label>
      <label>Confirm password<input name="confirm" type="password" autocomplete="new-password" minlength="10" required></label>
      <p class="hint">At least 10 characters.</p>
      <button type="submit">Save password</button>
      <p><a href="/">Back to Heartbeat</a></p>
    </form>`,
    chrome || { admin: false, account: true, here: "account" },
  );
}

export function accountSharedHTML(chrome) {
  return shell(
    "Account · Fulfillment Heartbeat",
    "Account",
    `<section class="login-card"><h2>Shared sign-in</h2><p>This sign-in does not have its own password.</p><p><a href="/">Back to Heartbeat</a></p></section>`,
    chrome || { admin: false, account: false, here: "account" },
  );
}

function userActions(user) {
  const id = escapeHtml(user.id);
  const button = (action, label) =>
    `<button type="submit" name="action" value="${action}" form="user-${id}">${label}</button>`;
  const parts = [];
  if (user.status !== "active") parts.push(button("resend", "New invite"), button("copy", "Copy invite"));
  if (user.status === "active") parts.push(button("reset", "Reset password"));
  if (user.status === "disabled") parts.push(button("enable", "Re-enable"));
  else parts.push(button("disable", "Disable"));
  parts.push(button("remove", "Remove"));
  return parts.join("");
}

export function adminHTML({ users, notice, error, link, emailOn, chrome }) {
  const alert = error ? `<p class="login-error" role="alert">${escapeHtml(error)}</p>` : notice ? `<p class="hint">${escapeHtml(notice)}</p>` : "";
  const linkBox = link
    ? `<label>Invite link<input id="invite-link" readonly value="${escapeHtml(link)}"></label><button type="button" data-copy="invite-link">Copy</button>`
    : "";
  const cards = (users || [])
    .map((user) => {
      const when = user.last_login_at ? new Date(Number(user.last_login_at) * 1000).toISOString().slice(0, 16).replace("T", " ") : "never";
      return `<article class="user-card">
        <h2>${escapeHtml(user.email)}</h2>
        <p class="hint">${escapeHtml(user.role)} · ${escapeHtml(user.status)} · last sign-in ${escapeHtml(when)}</p>
        <form id="user-${escapeHtml(user.id)}" method="POST" action="/admin"><input type="hidden" name="user" value="${escapeHtml(user.id)}"></form>
        <div class="row-actions">${userActions(user)}</div>
      </article>`;
    })
    .join("");
  const mailNote = emailOn ? "" : `<p class="hint">Email is off. Copy the invite link.</p>`;
  return shell(
    "People · Fulfillment Heartbeat",
    "People",
    `<section class="login-card">
      <h2>Add a person</h2>
      ${alert}
      ${linkBox}
      ${mailNote}
      <form method="POST" action="/admin">
        <input type="hidden" name="action" value="add">
        <label>Email<input name="email" type="email" autocomplete="off" autocapitalize="none" required></label>
        <label>Role<select name="role"><option value="viewer">Viewer</option><option value="admin">Admin</option></select></label>
        <button type="submit">Create invite</button>
      </form>
      <p><a href="/">Back to Heartbeat</a></p>
    </section>
    <div class="user-list">${cards}</div>
    <script src="/auth-copy.js"></script>`,
    chrome || { admin: true, account: false, here: "admin" },
  );
}
