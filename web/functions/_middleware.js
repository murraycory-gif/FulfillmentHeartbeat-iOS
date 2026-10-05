// Shared team gate for every Pages request, including static files.
// Master: BASIC_USER + BASIC_PASS. Testers: user "tester" + BASIC_PASS_TESTER.
// BASIC_USER_TESTER, when set, is an extra accepted tester name for the same tester password.
// Nothing here is a password. A missing pair fails closed; the other pair can still match.

const REALM = 'Basic realm="HeartBeat", charset="UTF-8"';

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

export function basicAuthOk(request, env) {
  const got = basicCredentials((request && request.headers && request.headers.get("authorization")) || "");
  const presentedUser = got ? got.user : "";
  const presentedPass = got ? got.pass : "";
  const masterUser = envSecret(env, "BASIC_USER");
  const masterPass = envSecret(env, "BASIC_PASS");
  const testerUser = "tester";
  const testerNamed = envSecret(env, "BASIC_USER_TESTER");
  const testerPass = envSecret(env, "BASIC_PASS_TESTER");
  const masterUserOk = timingSafeEqualString(presentedUser, masterUser);
  const masterPassOk = timingSafeEqualString(presentedPass, masterPass);
  const testerUserOk = timingSafeEqualString(presentedUser, testerUser);
  const testerNamedOk = timingSafeEqualString(presentedUser, testerNamed || testerUser);
  const testerPassOk = timingSafeEqualString(presentedPass, testerPass);
  const masterOk = Boolean(masterUser && masterPass && masterUserOk && masterPassOk);
  const testerOk = Boolean(testerPass && testerPassOk && (testerUserOk || testerNamedOk));
  return Boolean(got) && (masterOk || testerOk);
}

function challenge() {
  return new Response("Authentication required", {
    status: 401,
    headers: {
      "WWW-Authenticate": REALM,
      "Cache-Control": "no-store",
      "Content-Type": "text/plain; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export async function onRequest(context) {
  const env = (context && context.env) || {};
  if (!basicAuthOk(context.request, env)) return challenge();
  return context.next();
}
