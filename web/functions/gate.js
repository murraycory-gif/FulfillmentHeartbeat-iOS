// Access gate for the Pages function. No network except the injected JWKS fetch.
// Fail closed: missing team domain, missing AUD, bad token, or an email that is
// not on the allowlist never reads R2.

const SECTIONS = new Set([
  "sales",
  "lost_revenue",
  "missing_items",
  "five_star",
  "pre_sub_oos",
  "pick_path",
  "prep_not_ready",
  "dynacap",
  "schedule_quality",
  "picker_scorecard",
  "pph",
  "labor",
]);

const jwksCache = new Map();

export function parseAllowlist(text) {
  const out = [];
  const seen = new Set();
  for (const raw of String(text || "").split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, "").trim().toLowerCase();
    if (!line || !line.includes("@")) continue;
    if (seen.has(line)) continue;
    seen.add(line);
    out.push(line);
  }
  return out;
}

export function emailAllowed(email, list) {
  const value = String(email || "").trim().toLowerCase();
  if (!value || !value.includes("@")) return false;
  return list.includes(value);
}

// Only the cooked web pack and the existing schedule object. Never sqlite,
// never a public bucket host, never a path that climbs out of the prefix.
export function objectKeyForPath(raw) {
  const original = String(raw || "");
  if (/r2\.dev/i.test(original) || /:\/\//.test(original)) return null;
  let path = original.split("?")[0].trim();
  try {
    path = decodeURIComponent(path);
  } catch {
    return null;
  }
  path = path.replace(/^\/+/, "");
  if (!path) return null;
  const lower = path.toLowerCase();
  if (lower.includes("..") || path.includes("\\") || path.includes("//")) return null;
  if (lower.includes("://") || lower.includes("r2.dev")) return null;
  if (lower.includes(".sqlite")) return null;
  if (path === "home") return "web-pack/home.json";
  if (path === "presub") return "web-pack/presub.json";
  if (path === "schedule") return "schedule-check.json";
  const match = path.match(/^section\/([a-z0-9_]+)$/);
  if (!match || !SECTIONS.has(match[1])) return null;
  return `web-pack/section/${match[1]}.json`;
}

export function devBypassAllowed(env, hostname) {
  if (!env || String(env.HEARTBEAT_WEB_DEV) !== "1") return false;
  const host = String(hostname || "").toLowerCase();
  return host === "localhost" || host === "127.0.0.1";
}

export function accessCertsURL(teamDomain) {
  const host = String(teamDomain || "")
    .trim()
    .replace(/^https?:\/\//i, "")
    .replace(/\/.*$/, "")
    .toLowerCase();
  if (!/^[a-z0-9.-]+\.cloudflareaccess\.com$/.test(host)) return null;
  return `https://${host}/cdn-cgi/access/certs`;
}

function bytesToBase64Url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlToBytes(value) {
  const pad = value.length % 4 === 0 ? "" : "=".repeat(4 - (value.length % 4));
  const b64 = value.replace(/-/g, "+").replace(/_/g, "/") + pad;
  const binary = atob(b64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i);
  return out;
}

function readJsonPart(part) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(part)));
}

export async function verifyAccessJwt(token, { jwks, aud, now = Date.now() } = {}) {
  if (!aud) return { ok: false, reason: "aud-config" };
  const parts = String(token || "").split(".");
  if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
    return { ok: false, reason: "malformed" };
  }
  let header;
  let payload;
  try {
    header = readJsonPart(parts[0]);
    payload = readJsonPart(parts[1]);
  } catch {
    return { ok: false, reason: "malformed" };
  }
  if (!header || header.alg !== "RS256") return { ok: false, reason: "alg" };
  const claimAud = payload && payload.aud;
  const audOk = claimAud === aud || (Array.isArray(claimAud) && claimAud.includes(aud));
  if (!audOk) return { ok: false, reason: "aud" };
  if (typeof payload.exp !== "number" || payload.exp * 1000 <= now) {
    return { ok: false, reason: "exp" };
  }
  if (typeof payload.nbf === "number" && payload.nbf * 1000 > now) {
    return { ok: false, reason: "nbf" };
  }
  const keys = (jwks && jwks.keys) || [];
  const jwk = keys.find((key) => !header.kid || key.kid === header.kid);
  if (!jwk) return { ok: false, reason: "kid" };
  const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = base64UrlToBytes(parts[2]);
  let key;
  try {
    key = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
  } catch {
    return { ok: false, reason: "jwk" };
  }
  const signed = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, signature, data);
  if (!signed) return { ok: false, reason: "sig" };
  const email = String(payload.email || "").trim().toLowerCase();
  return { ok: true, email };
}

export async function fetchAccessJwks(teamDomain, fetchImpl = fetch, now = Date.now()) {
  const url = accessCertsURL(teamDomain);
  if (!url) return null;
  const hit = jwksCache.get(url);
  if (hit && hit.exp > now) return hit.keys;
  const response = await fetchImpl(url);
  if (!response || !response.ok) return null;
  const keys = await response.json();
  jwksCache.set(url, { exp: now + 60 * 60 * 1000, keys });
  return keys;
}

export function clearJwksCache() {
  jwksCache.clear();
}

export async function authorize(request, env, allowlistText, fetchJwks = fetchAccessJwks) {
  const list = parseAllowlist(allowlistText);
  const url = new URL(request.url);
  if (devBypassAllowed(env, url.hostname)) return { ok: true, email: "dev@localhost" };
  const team = env && env.CF_ACCESS_TEAM_DOMAIN;
  const aud = env && env.CF_ACCESS_AUD;
  if (!team || !aud) return { ok: false, reason: "config" };
  if (list.length === 0) return { ok: false, reason: "allowlist" };
  const token = request.headers.get("Cf-Access-Jwt-Assertion") || "";
  if (!token) return { ok: false, reason: "missing" };
  const jwks = await fetchJwks(team);
  if (!jwks) return { ok: false, reason: "jwks" };
  const verified = await verifyAccessJwt(token, { jwks, aud });
  if (!verified.ok) return verified;
  if (!emailAllowed(verified.email, list)) return { ok: false, reason: "allowlist" };
  return verified;
}

export { bytesToBase64Url };
