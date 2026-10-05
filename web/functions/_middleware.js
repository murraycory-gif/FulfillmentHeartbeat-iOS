// Session gate for every Pages request, including static files.
// Accounts live in HB_AUTH (D1): email, PBKDF2 password, role, invite, revocable session.
// The shared BASIC_PASS login stays until AUTH_CUTOVER=1, after the account sign-in is verified.
// Nothing here is a password. A missing secret fails closed.

import {
  acceptInvite,
  adminAct,
  adminHTML,
  authCutover,
  authDb,
  deniedHTML,
  emailInvitesEnabled,
  ensureAdminSeed,
  ensureSchema,
  inviteHTML,
  listUsers,
  loginHTML,
  clearLoginFailures,
  loginThrottled,
  openInvite,
  readAccountSession,
  recordLoginFailure,
  revokeSession,
  setupText,
  authenticateAccount,
} from "./accounts.js";

const COOKIE = "hb_session";
const MAX_AGE = 30 * 24 * 60 * 60;

export function timingSafeEqualString(left, right) {
  const encoder = new TextEncoder();
  const a = encoder.encode(String(left ?? ""));
  const b = encoder.encode(String(right ?? ""));
  const equal =
    crypto.subtle && typeof crypto.subtle.timingSafeEqual === "function"
      ? crypto.subtle.timingSafeEqual.bind(crypto.subtle)
      : null;
  if (a.byteLength !== b.byteLength) {
    if (equal && a.byteLength > 0) equal(a, a);
    return false;
  }
  if (equal) return equal(a, b);
  let diff = 0;
  for (let i = 0; i < a.byteLength; i += 1) diff |= a[i] ^ b[i];
  return diff === 0;
}

export function basicCredentials(header) {
  const match = /^Basic\s+([A-Za-z0-9+/=]+)$/i.exec(String(header || "").trim());
  if (!match) return null;
  let bytes;
  try {
    const binary = atob(match[1]);
    bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  } catch {
    return null;
  }
  const text = new TextDecoder().decode(bytes);
  const split = text.indexOf(":");
  if (split < 0) return null;
  return { user: text.slice(0, split), pass: text.slice(split + 1) };
}

function envSecret(env, key) {
  const value = env && env[key];
  return typeof value === "string" ? value : "";
}

export function matchedAccount(user, pass, env) {
  const presentedUser = String(user ?? "");
  const presentedPass = String(pass ?? "");
  const masterUser = envSecret(env, "BASIC_USER");
  const masterPass = envSecret(env, "BASIC_PASS");
  const testerUser = "tester";
  const testerNamed = envSecret(env, "BASIC_USER_TESTER");
  const testerPass = envSecret(env, "BASIC_PASS_TESTER");
  const masterOk =
    Boolean(masterUser && masterPass) &&
    timingSafeEqualString(presentedUser, masterUser) &&
    timingSafeEqualString(presentedPass, masterPass);
  const testerNameOk =
    timingSafeEqualString(presentedUser, testerUser) ||
    timingSafeEqualString(presentedUser, testerNamed || testerUser);
  const testerOk = Boolean(testerPass) && timingSafeEqualString(presentedPass, testerPass) && testerNameOk;
  if (masterOk) return { user: masterUser, pass: masterPass };
  if (testerOk) return { user: presentedUser, pass: testerPass };
  return null;
}

export function basicAuthOk(request, env) {
  const got = basicCredentials((request && request.headers && request.headers.get("authorization")) || "");
  if (!got) return false;
  return Boolean(matchedAccount(got.user, got.pass, env));
}

function sessionSecret(env) {
  const secret = envSecret(env, "SESSION_SECRET");
  return secret.length >= 16 ? secret : "";
}

function passwordForSessionUser(env, user) {
  const masterUser = envSecret(env, "BASIC_USER");
  const testerNamed = envSecret(env, "BASIC_USER_TESTER");
  if (masterUser && timingSafeEqualString(user, masterUser)) return envSecret(env, "BASIC_PASS");
  if (timingSafeEqualString(user, "tester")) return envSecret(env, "BASIC_PASS_TESTER");
  if (testerNamed && timingSafeEqualString(user, testerNamed)) return envSecret(env, "BASIC_PASS_TESTER");
  return "";
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(String(text ?? "")));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function passwordVersion(password) {
  return (await sha256Hex(password)).slice(0, 32);
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(signed)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function encodeToken(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
}

function decodeToken(text) {
  const pad = text.length % 4 === 0 ? "" : "=".repeat(4 - (text.length % 4));
  const binary = atob(text.replaceAll("-", "+").replaceAll("_", "/") + pad);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

export async function createSessionToken(env, user, pass, nowSeconds = Math.floor(Date.now() / 1000)) {
  const secret = sessionSecret(env);
  const account = matchedAccount(user, pass, env);
  if (!secret || !account || /[|\r\n]/.test(account.user)) return "";
  const exp = Math.floor(nowSeconds) + MAX_AGE;
  const version = await passwordVersion(account.pass);
  const body = `${account.user}|${exp}|${version}`;
  const encoded = encodeToken(body);
  const sig = await hmacHex(secret, encoded);
  return `${encoded}.${sig}`;
}

function readCookie(request, name) {
  const header = (request && request.headers && request.headers.get("cookie")) || "";
  for (const part of header.split(";")) {
    const trimmed = part.trim();
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    if (trimmed.slice(0, eq) !== name) continue;
    return trimmed.slice(eq + 1);
  }
  return "";
}

export async function readSession(request, env, nowSeconds = Math.floor(Date.now() / 1000)) {
  const secret = sessionSecret(env);
  const token = readCookie(request, COOKIE);
  const dot = token.lastIndexOf(".");
  if (!secret || dot <= 0) return null;
  const encoded = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const expected = await hmacHex(secret, encoded);
  if (!timingSafeEqualString(sig, expected)) return null;
  let body = "";
  try {
    body = decodeToken(encoded);
  } catch {
    return null;
  }
  const parts = body.split("|");
  if (parts.length !== 3) return null;
  const [user, expRaw, version] = parts;
  const exp = Number(expRaw);
  if (!user || !version || !Number.isFinite(exp) || exp < nowSeconds) return null;
  const password = passwordForSessionUser(env, user);
  if (!password) return null;
  const current = await passwordVersion(password);
  if (!timingSafeEqualString(version, current)) return null;
  return { user, exp };
}

function sessionCookie(token) {
  return `${COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${MAX_AGE}`;
}

function clearCookie() {
  return `${COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;
}

function htmlResponse(html, status = 200) {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy":
        "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'",
    },
  });
}

function loginResponse(message, email, status) {
  return htmlResponse(loginHTML(message, email), status);
}

function unauthorizedJSON() {
  return new Response(JSON.stringify({ error: "unauthorized" }), {
    status: 401,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function redirect(request, path, cookie, status = 303) {
  const headers = new Headers();
  headers.set("Location", new URL(path, request.url).toString());
  headers.set("Cache-Control", "no-store");
  if (cookie) headers.set("Set-Cookie", cookie);
  return new Response(null, { status, headers });
}

function sameOrigin(request) {
  const origin = request.headers.get("origin");
  if (!origin) return true;
  let originHost = "";
  try {
    originHost = new URL(origin).host;
  } catch {
    return false;
  }
  const host = (request.headers.get("x-forwarded-host") || request.headers.get("host") || "").split(",")[0].trim();
  if (host && originHost === host) return true;
  try {
    return originHost === new URL(request.url).host;
  } catch {
    return false;
  }
}

async function readForm(request) {
  let text = "";
  try {
    text = await request.text();
  } catch {
    text = "";
  }
  if (text.length > 8192) return null;
  return new URLSearchParams(text);
}

function sessionIsAdmin(session, env) {
  if (!session) return false;
  if (session.account) return session.role === "admin";
  if (authCutover(env)) return false;
  const master = envSecret(env, "BASIC_USER");
  return Boolean(master) && session.user === master;
}

async function submitLogin(request, env, db, now) {
  if (!sessionSecret(env)) return loginResponse("Sign-in is unavailable.", "", 503);
  if (!sameOrigin(request)) return loginResponse("That email or password is wrong.", "", 403);
  const params = await readForm(request);
  if (!params) return loginResponse("That email or password is wrong.", "", 401);
  const email = params.get("email") || params.get("username") || "";
  const password = params.get("password") || "";
  if (db) {
    if (await loginThrottled(db, request, email, now)) {
      return loginResponse("Too many sign-in attempts. Try again later.", email, 429);
    }
    const result = await authenticateAccount(db, env, request, email, password, now);
    if (result.throttled) return loginResponse("Too many sign-in attempts. Try again later.", email, 429);
    if (result.invited) return loginResponse("Use the invite link to set a password.", email, 401);
    if (result.unavailable) return loginResponse("Sign-in is unavailable.", email, 503);
    if (result.session) return redirect(request, "/", sessionCookie(result.session));
  }
  if (!authCutover(env)) {
    const account = matchedAccount(email, password, env);
    if (account) {
      const token = await createSessionToken(env, account.user, account.pass, now);
      if (!token) return loginResponse("Sign-in is unavailable.", "", 503);
      if (db) {
        try {
          await clearLoginFailures(db, request, email);
        } catch {
          // A shared-password sign-in still succeeds if the attempt log cannot be cleared.
        }
      }
      return redirect(request, "/", sessionCookie(token));
    }
  }
  if (db) await recordLoginFailure(db, request, email, now);
  return loginResponse("That email or password is wrong.", email, 401);
}

async function inviteResponse(request, env, db, token, now) {
  if (!db) return loginResponse("Sign-in is unavailable.", "", 503);
  if (request.method === "POST") {
    if (!sameOrigin(request)) return htmlResponse(inviteHTML("", token, "This link is no longer valid."), 403);
    const params = await readForm(request);
    if (!params) return htmlResponse(inviteHTML("", token, "This link is no longer valid."), 400);
    const result = await acceptInvite(db, env, token, params.get("password") || "", params.get("confirm") || "", now);
    if (result.session) return redirect(request, "/", sessionCookie(result.session));
    return htmlResponse(inviteHTML(result.email || "", token, result.error), 400);
  }
  const invite = await openInvite(db, token, now);
  if (!invite) return htmlResponse(inviteHTML("", token, "This link is no longer valid."), 400);
  return htmlResponse(inviteHTML(invite.email, token, ""));
}

async function adminResponse(request, env, db, session, now) {
  if (!sessionIsAdmin(session, env)) return htmlResponse(deniedHTML(), 403);
  if (!db) return htmlResponse(adminHTML({ users: [], error: "Accounts are not set up yet.", emailOn: false }), 503);
  let notice = "";
  let error = "";
  let link = "";
  if (request.method === "POST") {
    if (!sameOrigin(request)) return htmlResponse(deniedHTML(), 403);
    const params = await readForm(request);
    if (!params) return htmlResponse(adminHTML({ users: await listUsers(db), error: "That form was empty.", emailOn: emailInvitesEnabled(env) }), 400);
    const fields = Object.fromEntries(params.entries());
    const result = await adminAct(db, env, request, fields, now);
    notice = result.notice || "";
    error = result.error || "";
    link = result.link || "";
  }
  return htmlResponse(adminHTML({ users: await listUsers(db), notice, error, link, emailOn: emailInvitesEnabled(env) }));
}

export async function onRequest(context) {
  const request = context.request;
  const env = (context && context.env) || {};
  const url = new URL(request.url || "https://fulfillment-heartbeat-web.pages.dev/");
  const pathname = url.pathname;
  const now = Math.floor(Date.now() / 1000);
  const db = authDb(env);
  let accountsReady = false;
  if (db) {
    try {
      await ensureSchema(db);
      await ensureAdminSeed(db, env, now);
      accountsReady = true;
    } catch (error) {
      console.error("accounts setup failed", error instanceof Error ? error.message : "unknown");
      accountsReady = false;
    }
  }
  const readyDb = accountsReady ? db : null;

  if (request.method === "GET" && pathname === "/setup") {
    if (!readyDb) return new Response("Not found", { status: 404 });
    const text = await setupText(readyDb, env, request, now);
    if (text == null) return new Response("Not found", { status: 404, headers: { "Cache-Control": "no-store" } });
    return new Response(text, { status: 200, headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });
  }
  if (pathname.startsWith("/invite/")) {
    return inviteResponse(request, env, readyDb, decodeURIComponent(pathname.slice("/invite/".length)), now);
  }
  if (request.method === "POST" && pathname === "/login") return submitLogin(request, env, readyDb, now);
  if ((request.method === "GET" || request.method === "HEAD" || request.method === "POST") && pathname === "/logout") {
    if (readyDb) {
      const current = await readAccountSession(readyDb, request, env, now);
      if (current) await revokeSession(readyDb, current.sessionId, now);
    }
    return redirect(request, "/login", clearCookie(), 302);
  }
  if ((request.method === "GET" || request.method === "HEAD") && pathname === "/favicon.ico") {
    return redirect(request, "/favicon.svg", "", 302);
  }
  if ((request.method === "GET" || request.method === "HEAD") && (pathname === "/login.css" || pathname === "/nav-boot.js" || pathname === "/favicon.svg" || pathname === "/auth-copy.js")) {
    return context.next();
  }

  let session = readyDb ? await readAccountSession(readyDb, request, env, now) : null;
  if (!session && !authCutover(env)) session = await readSession(request, env, now);
  if (pathname === "/admin") return adminResponse(request, env, readyDb, session, now);
  if (!session) {
    if (pathname.startsWith("/data/")) return unauthorizedJSON();
    return loginResponse("", "", 200);
  }
  if (pathname === "/login") return redirect(request, "/");

  const response = await context.next();
  if (!pathname.startsWith("/data/")) return response;
  const headers = new Headers(response.headers);
  headers.set("Cache-Control", "private, no-store");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
