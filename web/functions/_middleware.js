// Session gate for documents and data. Static assets skip the database.
// Accounts live in HB_AUTH (D1): email, PBKDF2 password, role, one-time link, revocable session.
// The shared BASIC_PASS login stays a viewer until AUTH_CUTOVER=1.
// Nothing here is a password. A missing database fails closed.

import { packApiPath, readPackObject } from "./pack-store.js";
import {
  ABSOLUTE_TTL,
  ACCOUNT_COOKIE,
  SHARED_COOKIE,
  acceptInvite,
  accountHTML,
  accountSharedHTML,
  adminAct,
  adminHTML,
  authCutover,
  authDb,
  deniedHTML,
  ensureSchema,
  inviteHTML,
  listUsers,
  loginHTML,
  changePassword,
  clearLoginFailures,
  openInvite,
  createSharedSession,
  readLiveSession,
  revokePresentedSessions,
  recordLoginFailure,
  authenticateAccount,
} from "./accounts.js";

const MAX_AGE = ABSOLUTE_TTL;

let authNow = () => Math.floor(Date.now() / 1000);

export function setAuthClock(clock) {
  authNow = typeof clock === "function" ? clock : () => Math.floor(Date.now() / 1000);
}

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

function sessionCookie(name, token) {
  return `${name}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${MAX_AGE}`;
}

function clearCookie(name) {
  return `${name}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;
}

function accountCookies(token) {
  return [sessionCookie(ACCOUNT_COOKIE, token), clearCookie(SHARED_COOKIE)];
}

function sharedCookies(token) {
  return [sessionCookie(SHARED_COOKIE, token), clearCookie(ACCOUNT_COOKIE)];
}

function clearedCookies() {
  return [clearCookie(ACCOUNT_COOKIE), clearCookie(SHARED_COOKIE)];
}

const REFERRER_POLICY = "same-origin";
const CROSS_SITE_MESSAGE = "Sign-in blocked: please open the site directly and try again.";

function htmlResponse(html, status = 200, cookies = []) {
  const headers = new Headers({
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "private, no-store",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": REFERRER_POLICY,
    "Content-Security-Policy":
      "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'",
  });
  for (const cookie of cookies) headers.append("Set-Cookie", cookie);
  return new Response(html, { status, headers });
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
      Vary: "Cookie",
      "CDN-Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function redirect(request, path, cookies, status = 303) {
  const headers = new Headers();
  headers.set("Location", new URL(path, request.url).toString());
  headers.set("Cache-Control", "no-store");
  for (const cookie of [].concat(cookies || [])) {
    if (cookie) headers.append("Set-Cookie", cookie);
  }
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
  if (!sameOrigin(request)) return loginResponse(CROSS_SITE_MESSAGE, "", 403);
  const params = await readForm(request);
  if (!params) return loginResponse("That email or password is wrong.", "", 401);
  const email = params.get("email") || params.get("username") || "";
  const password = params.get("password") || "";
  if (!db) {
    if (!authCutover(env) && matchedAccount(email, password, env)) {
      return loginResponse("Sign-in is unavailable.", "", 503);
    }
    return loginResponse("That email or password is wrong.", "", 401);
  }
  const result = await authenticateAccount(db, request, email, password, now, env);
  if (result.throttled) return loginResponse("Too many sign-in attempts. Try again later.", "", 429);
  if (result.unavailable) return loginResponse("Sign-in is unavailable.", "", 503);
  if (result.session) return redirect(request, "/", accountCookies(result.session));
  if (!authCutover(env)) {
    const account = matchedAccount(email, password, env);
    if (account) {
      await revokePresentedSessions(db, request, now, env);
      const token = await createSharedSession(db, account.user, now, account.pass);
      if (!token) return loginResponse("Sign-in is unavailable.", "", 503);
      try {
        await clearLoginFailures(db, request, email);
      } catch {
        // A shared-password sign-in still succeeds if the attempt log cannot be cleared.
      }
      return redirect(request, "/", sharedCookies(token));
    }
  }
  await recordLoginFailure(db, request, email, now);
  return loginResponse("That email or password is wrong.", "", 401);
}

async function inviteResponse(request, env, db, token, now) {
  if (!db) return loginResponse("Sign-in is unavailable.", "", 503);
  if (request.method === "POST") {
    if (!sameOrigin(request)) return htmlResponse(inviteHTML("", token, CROSS_SITE_MESSAGE), 403);
    const params = await readForm(request);
    if (!params) return htmlResponse(inviteHTML("", token, "This link is no longer valid."), 400);
    const result = await acceptInvite(db, token, params.get("password") || "", params.get("confirm") || "", now);
    if (result.session) return redirect(request, "/", accountCookies(result.session));
    return htmlResponse(inviteHTML(result.email || "", token, result.error), 400);
  }
  const invite = await openInvite(db, token, now);
  if (!invite) return htmlResponse(inviteHTML("", token, "This link is no longer valid."), 400);
  return htmlResponse(inviteHTML(invite.email, token, ""));
}

async function adminResponse(request, env, db, session, now) {
  const chrome = settingsChrome(session, "admin");
  if (request.method === "POST" && !sameOrigin(request)) {
    return htmlResponse(adminHTML({ users: [], error: CROSS_SITE_MESSAGE, chrome }), 403);
  }
  if (!chrome.admin) return htmlResponse(deniedHTML(chrome), 403);
  if (request.method !== "GET" && request.method !== "HEAD" && request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: { Allow: "GET, HEAD, POST", "Cache-Control": "no-store" } });
  }
  if (!db) return htmlResponse(adminHTML({ users: [], error: "Accounts are not set up yet.", chrome }), 503);
  let notice = "";
  let error = "";
  let link = "";
  if (request.method === "POST") {
    if (!sameOrigin(request)) {
      return htmlResponse(adminHTML({ users: [], error: CROSS_SITE_MESSAGE, chrome }), 403);
    }
    const params = await readForm(request);
    if (!params) return htmlResponse(adminHTML({ users: await listUsers(db), error: "That form was empty.", chrome }), 400);
    const fields = Object.fromEntries(params.entries());
    const result = await adminAct(db, env, request, fields, now);
    notice = result.notice || "";
    error = result.error || "";
    link = result.link || "";
  }
  return htmlResponse(adminHTML({ users: await listUsers(db), notice, error, link, chrome }));
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
  if (request.method === "POST" && !sameOrigin(request)) {
    return htmlResponse(accountHTML(session && session.user, CROSS_SITE_MESSAGE, "", settingsChrome(session, "account")), 403);
  }
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
      session,
      params.get("current") || "",
      params.get("password") || "",
      params.get("confirm") || "",
      now,
      request,
    );
    if (result.notice) {
      return htmlResponse(accountHTML(session.user, "", result.notice, chrome), 200, result.session ? accountCookies(result.session) : []);
    }
    return htmlResponse(accountHTML(session.user, result.error, "", chrome), result.status || 400);
  }
  return htmlResponse(accountHTML(session.user, "", "", chrome));
}

function packHeaders() {
  return {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "private, no-store",
    Vary: "Cookie",
    "CDN-Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  };
}

function packJSON(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: packHeaders() });
}

// HEARTBEAT_PACKS is read here, after the session check, and nowhere else.
async function packFromBucket(env, pathname) {
  const bucket = env && env.HEARTBEAT_PACKS;
  if (!bucket || typeof bucket.get !== "function") return null;
  const object = await readPackObject(bucket, pathname);
  if (!object) return null;
  return new Response(object.body, { status: 200, headers: packHeaders() });
}

async function apiPackResponse(request, env, pathname) {
  if (request.method !== "GET" && request.method !== "HEAD") return packJSON({ error: "NO DATA" }, 405);
  const rel = packApiPath(pathname);
  if (!rel) return packJSON({ error: "NO DATA" }, 404);
  const bucket = env && env.HEARTBEAT_PACKS;
  const object = await readPackObject(bucket, `/data/${rel}`);
  if (!object) return packJSON({ error: "NO DATA" }, 404);
  if (request.method === "HEAD") return new Response(null, { status: 200, headers: packHeaders() });
  return new Response(object.body, { status: 200, headers: packHeaders() });
}

function sealAuthenticated(response) {
  const headers = new Headers(response.headers);
  headers.set("Cache-Control", "private, no-store");
  if (!headers.has("Vary")) headers.set("Vary", "Cookie");
  headers.set("CDN-Cache-Control", "no-store");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
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
  const jar = [];
  const response = await routeRequest(context, jar);
  if (!jar.length) return withReferrerPolicy(response);
  const headers = new Headers(response.headers);
  for (const cookie of jar) headers.append("Set-Cookie", cookie);
  return withReferrerPolicy(new Response(response.body, { status: response.status, statusText: response.statusText, headers }));
}

function hasAuthCookie(request) {
  const header = (request.headers.get("cookie") || "");
  return /(?:^|;\s*)hb_session=[^;\s]/.test(header) || /(?:^|;\s*)hb_shared=[^;\s]/.test(header);
}

function isStaticAsset(pathname, method) {
  if (method !== "GET" && method !== "HEAD") return false;
  return /\.(?:js|mjs|css|svg|png|ico|gif|webp|map|woff2?|webmanifest|txt)$/i.test(pathname);
}

async function readyAccounts(env) {
  const db = authDb(env);
  if (!db) return null;
  try {
    await ensureSchema(db);
    return db;
  } catch {
    console.error("accounts setup failed");
    return null;
  }
}

async function routeRequest(context, jar = []) {
  const request = context.request;
  const env = (context && context.env) || {};
  const url = new URL(request.url || "https://fulfillment-heartbeat-web.pages.dev/");
  const pathname = url.pathname;
  const now = authNow();

  if (pathname === "/setup" || pathname === "/hb-user" || pathname.startsWith("/scripts/") || pathname.startsWith("/admin-scripts/")) {
    return new Response("Not found", { status: 404, headers: { "Cache-Control": "no-store" } });
  }
  if ((request.method === "GET" || request.method === "HEAD") && pathname === "/favicon.ico") {
    return redirect(request, "/favicon.svg", "", 302);
  }
  if (isStaticAsset(pathname, request.method)) return context.next();
  if ((request.method === "GET" || request.method === "HEAD") && pathname === "/login" && !hasAuthCookie(request)) {
    return loginResponse("", "", 200);
  }

  const readyDb = await readyAccounts(env);

  if (pathname.startsWith("/invite/")) {
    if (request.method !== "GET" && request.method !== "HEAD" && request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405, headers: { Allow: "GET, HEAD, POST", "Cache-Control": "no-store" } });
    }
    let inviteToken = "";
    try {
      inviteToken = decodeURIComponent(pathname.slice("/invite/".length));
    } catch {
      return new Response("Bad Request", { status: 400, headers: { "Cache-Control": "no-store" } });
    }
    return inviteResponse(request, env, readyDb, inviteToken, now);
  }
  if (pathname === "/login" && request.method === "POST") return submitLogin(request, env, readyDb, now);
  if (pathname === "/logout") {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405, headers: { Allow: "POST", "Cache-Control": "no-store" } });
    }
    if (!sameOrigin(request)) return loginResponse(CROSS_SITE_MESSAGE, "", 403);
    if (readyDb) await revokePresentedSessions(readyDb, request, now, env);
    return redirect(request, "/login", clearedCookies(), 303);
  }

  const waitUntil = context && typeof context.waitUntil === "function" ? context.waitUntil.bind(context) : null;
  let session = readyDb ? await readLiveSession(readyDb, request, now, env, true, waitUntil) : null;
  if (session && session.rotate) {
    jar.push(sessionCookie(session.account ? ACCOUNT_COOKIE : SHARED_COOKIE, session.rotate));
  }
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
    const packed = await packFromBucket(env, pathname);
    if (packed) return packed;
  }

  return sealAuthenticated(await context.next());
}
