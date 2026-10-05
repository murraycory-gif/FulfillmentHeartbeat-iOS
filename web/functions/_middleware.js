// Shared team gate for every Pages request, including static files.
// Credentials live in Pages secrets BASIC_USER and BASIC_PASS. Nothing here
// is a password. Missing secrets fail closed.

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

export function basicAuthOk(request, env) {
  const expectedUser = env && typeof env.BASIC_USER === "string" ? env.BASIC_USER : "";
  const expectedPass = env && typeof env.BASIC_PASS === "string" ? env.BASIC_PASS : "";
  if (!expectedUser || !expectedPass) return false;
  const got = basicCredentials(request.headers.get("authorization") || "");
  if (!got) return false;
  const userOk = timingSafeEqualString(got.user, expectedUser);
  const passOk = timingSafeEqualString(got.pass, expectedPass);
  return userOk && passOk;
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
