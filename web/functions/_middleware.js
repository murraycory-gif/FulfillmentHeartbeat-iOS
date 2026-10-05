// Session gate for every Pages request, including static files.
// Master: BASIC_USER + BASIC_PASS. Testers: user "tester" + BASIC_PASS_TESTER.
// BASIC_USER_TESTER, when set, is an extra accepted tester name for the same tester password.
// A signed cookie replaces the Basic Auth prompt so browsers can save the password.
// Nothing here is a password. A missing secret or password fails closed.

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

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => {
    if (char === "&") return "&amp;";
    if (char === "<") return "&lt;";
    if (char === ">") return "&gt;";
    if (char === '"') return "&quot;";
    return "&#39;";
  });
}

function loginHTML(message, username) {
  const alert = message ? `<p class="login-error" role="alert">${escapeHtml(message)}</p>` : "";
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign in · Fulfillment Heartbeat</title>
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/login.css">
  <script src="/nav-boot.js?v=2"></script>
</head>
<body>
  <header class="top">
    <p class="brand-lockup">
      <span class="wordmark" aria-label="Fulfillment Heartbeat"><span class="fulfill">Fulfill</span><span class="ment">ment</span></span>
      <svg class="heart" viewBox="0 0 36 33" aria-hidden="true">
        <defs>
          <linearGradient id="hb-heart" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#9fd4ff"/>
            <stop offset="48%" stop-color="#3d8dff"/>
            <stop offset="100%" stop-color="#00a9e0"/>
          </linearGradient>
        </defs>
        <path fill="url(#hb-heart)" d="M18 32.4C18 27.36 0 20.88 1.8 12.96C3.6 1.44 13.68 1.44 18 7.92C22.32 1.44 32.4 1.44 34.2 12.96C36 20.88 18 27.36 18 32.4Z"/>
      </svg>
      <svg class="pulse" viewBox="0 0 52 22" aria-hidden="true">
        <path fill="none" stroke="#00A9E0" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" d="M0 14.5L5.1 14.5L8.2 17.5L15.3 1.5L21.4 20.5L25.5 14.5Q30.6 7.5 35.7 14.5L51 14.5"/>
      </svg>
    </p>
    <h1>Sign in</h1>
  </header>
  <main class="login-main">
    <form class="login-card" method="POST" action="/login" autocomplete="on">
      <h2>Fulfillment Heartbeat</h2>
      ${alert}
      <label>Username<input name="username" autocomplete="username" autocapitalize="none" autocorrect="off" spellcheck="false" required value="${escapeHtml(username)}"></label>
      <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
      <button type="submit">Sign in</button>
    </form>
  </main>
</body>
</html>`;
}

function loginResponse(message, username, status) {
  return new Response(loginHTML(message, username), {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy":
        "default-src 'self'; style-src 'self'; img-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'",
    },
  });
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

async function submitLogin(request, env) {
  if (!sessionSecret(env)) return loginResponse("Sign-in is unavailable.", "", 503);
  let text = "";
  try {
    text = await request.text();
  } catch {
    text = "";
  }
  if (text.length > 4096) return loginResponse("That username or password is wrong.", "", 401);
  const params = new URLSearchParams(text);
  const username = params.get("username") || "";
  const password = params.get("password") || "";
  const account = matchedAccount(username, password, env);
  if (!account) return loginResponse("That username or password is wrong.", username, 401);
  const token = await createSessionToken(env, account.user, account.pass);
  if (!token) return loginResponse("Sign-in is unavailable.", "", 503);
  return redirect(request, "/", sessionCookie(token));
}

export async function onRequest(context) {
  const request = context.request;
  const env = (context && context.env) || {};
  const url = new URL(request.url || "https://fulfillment-heartbeat-web.pages.dev/");
  const pathname = url.pathname;

  if (request.method === "POST" && pathname === "/login") return submitLogin(request, env);
  if ((request.method === "GET" || request.method === "HEAD" || request.method === "POST") && pathname === "/logout") {
    return redirect(request, "/login", clearCookie(), 302);
  }
  if ((request.method === "GET" || request.method === "HEAD") && pathname === "/favicon.ico") {
    return redirect(request, "/favicon.svg", "", 302);
  }
  if ((request.method === "GET" || request.method === "HEAD") && (pathname === "/login.css" || pathname === "/nav-boot.js" || pathname === "/favicon.svg")) {
    return context.next();
  }

  const session = await readSession(request, env);
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
