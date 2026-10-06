// Session gate for every Pages request, including static files.
// Accounts live in HB_AUTH (D1): email, PBKDF2 password, role, invite, revocable session.
// The shared BASIC_PASS login stays until AUTH_CUTOVER=1, after the account sign-in is verified.
// Nothing here is a password. A missing secret fails closed.

import { packApiPath, readPackObject } from "./pack-store.js";
import {
  acceptInvite,
  accountHTML,
  accountSharedHTML,
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
  changePassword,
  clearLoginFailures,
  loginThrottled,
  openInvite,
  createSharedSession,
  readAccountSession,
  readSharedSession,
  recordLoginFailure,
  revokeSession,
  revokeSharedSession,
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

function sessionCookie(token) {
  return `${COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${MAX_AGE}`;
}

function clearCookie() {
  return `${COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;
}

const REFERRER_POLICY = "same-origin";
const CROSS_SITE_MESSAGE = "Sign-in blocked: please open the site directly and try again.";

function htmlResponse(html, status = 200) {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": REFERRER_POLICY,
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

function requestHost(request) {
  const forwarded = String(request.headers.get("x-forwarded-host") || request.headers.get("host") || "")
    .split(",")[0]
    .trim();
  if (forwarded) return forwarded;
  try {
    return new URL(request.url).host;
  } catch {
    return "";
  }
}

function hostFrom(value) {
  try {
    return new URL(value).host;
  } catch {
    return "";
  }
}

function refererMatches(request, host) {
  if (!host) return false;
  const referer = request.headers.get("referer") || request.headers.get("referrer") || "";
  if (!referer) return false;
  return hostFrom(referer) === host;
}

function sameOrigin(request) {
  const site = (request.headers.get("sec-fetch-site") || "").trim().toLowerCase();
  if (site === "cross-site" || site === "same-site") return false;
  const host = requestHost(request);
  const origin = (request.headers.get("origin") || "").trim();
  if (!origin || origin.toLowerCase() === "null") {
    if (site === "same-origin") return true;
    return refererMatches(request, host);
  }
  const originHost = hostFrom(origin);
  if (!originHost) return false;
  if (host && originHost === host) return true;
  const urlHost = hostFrom(request.url);
  return Boolean(urlHost) && originHost === urlHost;
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

function sessionIsAdmin(session) {
  return Boolean(session && session.account && session.role === "admin");
}

function settingsChrome(session, here) {
  return {
    admin: sessionIsAdmin(session),
    account: Boolean(session && session.account),
    here,
  };
}

async function submitLogin(request, env, db, now) {
  if (!sessionSecret(env)) return loginResponse("Sign-in is unavailable.", "", 503);
  if (!sameOrigin(request)) return loginResponse(CROSS_SITE_MESSAGE, "", 403);
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
      if (!db) return loginResponse("Sign-in is unavailable.", "", 503);
      const token = await createSharedSession(db, env, account.user, now);
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
    if (!sameOrigin(request)) return htmlResponse(inviteHTML("", token, CROSS_SITE_MESSAGE), 403);
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
  const chrome = settingsChrome(session, "admin");
  if (!chrome.admin) return htmlResponse(deniedHTML(chrome), 403);
  if (!db) return htmlResponse(adminHTML({ users: [], error: "Accounts are not set up yet.", emailOn: false, chrome }), 503);
  let notice = "";
  let error = "";
  let link = "";
  if (request.method === "POST") {
    if (!sameOrigin(request)) {
      return htmlResponse(adminHTML({ users: [], error: CROSS_SITE_MESSAGE, emailOn: emailInvitesEnabled(env), chrome }), 403);
    }
    const params = await readForm(request);
    if (!params) return htmlResponse(adminHTML({ users: await listUsers(db), error: "That form was empty.", emailOn: emailInvitesEnabled(env), chrome }), 400);
    const fields = Object.fromEntries(params.entries());
    const result = await adminAct(db, env, request, fields, now);
    notice = result.notice || "";
    error = result.error || "";
    link = result.link || "";
  }
  return htmlResponse(adminHTML({ users: await listUsers(db), notice, error, link, emailOn: emailInvitesEnabled(env), chrome }));
}

function sessionPayload(session) {
  return {
    email: session.user,
    role: session.account && session.role === "admin" ? "admin" : session.account ? session.role : "viewer",
    account: Boolean(session.account),
  };
}

function sessionJSON(session) {
  return new Response(JSON.stringify(sessionPayload(session)), {
    status: 200,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "private, no-store",
    },
  });
}

async function accountResponse(request, env, db, session, now) {
  if (!session) return loginResponse("", "", 200);
  const chrome = settingsChrome(session, "account");
  if (!session.account) return htmlResponse(accountSharedHTML(chrome));
  if (!db) return htmlResponse(accountHTML(session.user, "Accounts are not set up yet.", "", chrome), 503);
  if (request.method === "POST") {
    if (!sameOrigin(request)) return htmlResponse(accountHTML(session.user, CROSS_SITE_MESSAGE, "", chrome), 403);
    const params = await readForm(request);
    if (!params) return htmlResponse(accountHTML(session.user, "That form was empty.", "", chrome), 400);
    const result = await changePassword(
      db,
      env,
      request,
      session,
      params.get("current") || "",
      params.get("password") || "",
      params.get("confirm") || "",
      now,
    );
    if (result.notice) return htmlResponse(accountHTML(session.user, "", result.notice, chrome));
    return htmlResponse(accountHTML(session.user, result.error, "", chrome), result.status || 400);
  }
  return htmlResponse(accountHTML(session.user, "", "", chrome));
}

function packHeaders() {
  return {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "private, no-store",
    "X-Content-Type-Options": "nosniff",
  };
}

function packJSON(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: packHeaders() });
}

// HEARTBEAT_PACKS is read here, after the session check, and nowhere else.
async function packFromBucket(env, url) {
  const bucket = env && env.HEARTBEAT_PACKS;
  if (!bucket || typeof bucket.get !== "function") return null;
  const object = await readPackObject(bucket, url);
  if (object && object.absent) return { absent: true };
  if (!object || object.missing || object.body == null) return null;
  return new Response(object.body, { status: 200, headers: packHeaders() });
}

async function apiPackResponse(request, env, pathname) {
  if (request.method !== "GET" && request.method !== "HEAD") return packJSON({ error: "NO DATA" }, 405);
  const rel = packApiPath(pathname);
  if (!rel) return packJSON({ error: "NO DATA" }, 404);
  const bucket = env && env.HEARTBEAT_PACKS;
  const object = await readPackObject(bucket, request.url);
  if (!object || object.absent || object.missing || object.body == null) return packJSON({ error: "NO DATA" }, 404);
  if (request.method === "HEAD") return new Response(null, { status: 200, headers: packHeaders() });
  return new Response(object.body, { status: 200, headers: packHeaders() });
}

function withReferrerPolicy(response) {
  const headers = new Headers(response.headers);
  headers.set("Referrer-Policy", REFERRER_POLICY);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export async function onRequest(context) {
  return withReferrerPolicy(await routeRequest(context));
}

async function routeRequest(context) {
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
      else {
        const shared = await readSharedSession(readyDb, request, env, now);
        if (shared) await revokeSharedSession(readyDb, shared.sessionId, now);
      }
    }
    return redirect(request, "/login", clearCookie(), 302);
  }
  if ((request.method === "GET" || request.method === "HEAD") && pathname === "/favicon.ico") {
    return redirect(request, "/favicon.svg", "", 302);
  }
  if ((request.method === "GET" || request.method === "HEAD") && (pathname === "/login.css" || pathname === "/nav-boot.js" || pathname === "/favicon.svg" || pathname === "/favicon-32.png" || pathname === "/favicon-16.png" || pathname === "/apple-touch-icon.png" || pathname === "/auth-copy.js")) {
    return context.next();
  }

  let session = readyDb ? await readAccountSession(readyDb, request, env, now) : null;
  if (!session && readyDb && !authCutover(env)) session = await readSharedSession(readyDb, request, env, now);
  if (pathname === "/admin") return adminResponse(request, env, readyDb, session, now);
  if (pathname === "/account") return accountResponse(request, env, readyDb, session, now);
  if (!session) {
    if (pathname.startsWith("/data/") || pathname.startsWith("/api/") || pathname === "/session") return unauthorizedJSON();
    return loginResponse("", "", 200);
  }
  if (pathname === "/login") return redirect(request, "/");
  if ((request.method === "GET" || request.method === "HEAD") && pathname === "/session") return sessionJSON(session);
  if (pathname.startsWith("/api/")) return apiPackResponse(request, env, pathname);
  if (pathname.startsWith("/data/")) {
    const bucket = env && env.HEARTBEAT_PACKS;
    if (bucket && typeof bucket.get === "function") {
      const packed = await packFromBucket(env, request.url);
      // Only a missing current.json uses the static tree. A bad pointer stays 404.
      if (!(packed && packed.absent)) {
        if (packed) return packed;
        return packJSON({ error: "NO DATA" }, 404);
      }
    }
  }

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
