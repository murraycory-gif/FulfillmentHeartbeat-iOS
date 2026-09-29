import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  accessCertsURL,
  authorize,
  clearJwksCache,
  devBypassAllowed,
  emailAllowed,
  objectKeyForPath,
  parseAllowlist,
  verifyAccessJwt,
} from "./functions/gate.js";
import { bannerText, considerPublished, publishClock, updatedLine } from "./public/clock.js";
import {
  canonicalDivision,
  canonicalStore,
  includesScope,
  matchesDistrict,
  matchesDivision,
} from "./public/filters.js";
import {
  bannerMismatch,
  companyMarketNote,
  notScheduled,
  percentHealth,
  qualifies,
  summary,
} from "./public/schedule-math.js";

const root = dirname(fileURLToPath(import.meta.url));
const empty = { region: "", division: "", district: "", om: "", store: "" };

function filters(extra) {
  return { ...empty, ...extra };
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else out.push(path);
  }
  return out;
}

const allow = parseAllowlist(`
# comment
Reader@Example.com

not-an-email
reader@example.com
`);
assert.deepEqual(allow, ["reader@example.com"]);
assert.equal(emailAllowed("Reader@Example.com", allow), true);
assert.equal(emailAllowed("other@example.com", allow), false);
assert.equal(parseAllowlist("# only\n\n").length, 0);

assert.equal(objectKeyForPath("home"), "web-pack/home.json");
assert.equal(objectKeyForPath("/section/sales"), "web-pack/section/sales.json");
assert.equal(objectKeyForPath("presub"), "web-pack/presub.json");
assert.equal(objectKeyForPath("schedule"), "schedule-check.json");
assert.equal(objectKeyForPath("section/not_a_section"), null);
assert.equal(objectKeyForPath("section/../home"), null);
assert.equal(objectKeyForPath("packs/seat/company/all/current.sqlite"), null);
assert.equal(objectKeyForPath("https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite"), null);
assert.equal(objectKeyForPath("home?x=https://example.r2.dev/a"), null);

assert.equal(devBypassAllowed({ HEARTBEAT_WEB_DEV: "1" }, "localhost"), true);
assert.equal(devBypassAllowed({ HEARTBEAT_WEB_DEV: "1" }, "127.0.0.1"), true);
assert.equal(devBypassAllowed({ HEARTBEAT_WEB_DEV: "1" }, "heartbeat.pages.dev"), false);
assert.equal(devBypassAllowed({}, "localhost"), false);
assert.equal(accessCertsURL("Team.CloudflareAccess.com"), "https://team.cloudflareaccess.com/cdn-cgi/access/certs");
assert.equal(accessCertsURL("https://evil.example/cdn-cgi/access/certs"), null);

const stamp = readFileSync(join(root, "../FulfillmentHeartbeat/BuildStamp.swift"), "utf8");
const app = readFileSync(join(root, "public/app.js"), "utf8");
assert.match(stamp, /HB-0828\.494/);
assert.match(app, /HB-0828\.494/);
assert.equal((stamp.match(/HB-0828\.494/g) || []).length, 1);

for (const path of walk(join(root, "public"))) {
  const text = readFileSync(path, "utf8");
  assert.equal(/r2\.dev/i.test(text), false, path);
  assert.equal(text.includes("pub-eafb309f53464d98902d12ac107f0f1e"), false, path);
}
const fn = readFileSync(join(root, "functions/api/[[path]].js"), "utf8");
assert.equal(/r2\.dev/i.test(fn), false);
assert.match(fn, /private, no-store/);
assert.match(fn, /HEARTBEAT_PACKS/);

assert.equal(updatedLine(""), "Updated —");
assert.equal(updatedLine(null), "Updated —");
const noon = new Date(2026, 8, 28, 15, 10, 0);
assert.equal(publishClock(noon), "Mon 9/28 3:10 PM");
assert.equal(bannerText(null, "2026-09-28T16:00:00Z"), null);
const memory = new Map();
const storage = {
  getItem: (key) => (memory.has(key) ? memory.get(key) : null),
  setItem: (key, value) => memory.set(key, value),
};
assert.equal(considerPublished(storage, "hb.web.seenPublishedAt", "2026-09-28T15:00:00Z"), null);
const newer = considerPublished(storage, "hb.web.seenPublishedAt", "2026-09-28T16:00:00Z");
assert.match(newer, /^New data uploaded /);
assert.equal(considerPublished(storage, "hb.web.seenPublishedAt", "2026-09-28T16:00:00Z"), null);

assert.equal(qualifies(29999, 50, 50, 50), false);
assert.equal(qualifies(null, 50, 50, 50), false);
assert.equal(qualifies(30000, 10, 0, 0), true);
assert.equal(qualifies(30000, 9.9, 9, 14.9), false);
assert.equal(qualifies(30000, 0, 9, 0), false);
assert.equal(qualifies(30000, 0, 9.0002, 0), true);
assert.equal(qualifies(30000, 0, 0, 15), true);
assert.equal(notScheduled({ under: 100, eff: 0 }), true);
assert.equal(notScheduled({ under: 100, eff: 1 }), false);
assert.equal(percentHealth(12, true), "none");
assert.equal(percentHealth(0, false), "good");
assert.equal(percentHealth(0.2, false), "risk");

assert.equal(matchesDivision("SHAWS", "Shaws"), true);
assert.equal(matchesDivision("MID-ATLANTIC", "Mid Atlantic"), true);
assert.equal(matchesDivision("Shaws", "United"), false);
assert.equal(canonicalDivision("NOR. CALIFORNIA"), "NorCal");
assert.equal(canonicalDivision("SO CALIFORNIA"), "SoCal");
assert.equal(canonicalStore("0117"), "117");
assert.equal(matchesDistrict("03", "3"), true);
assert.equal(matchesDistrict("D3", "3"), false);
assert.equal(
  includesScope({ division: "Shaws", district: "03", om: "Ada", store: "0117" }, filters({ region: "East Region" })),
  true,
);
assert.equal(
  includesScope({ division: "United", district: "03", om: "Ada", store: "200" }, filters({ region: "East Region" })),
  false,
);
assert.equal(
  includesScope({ division: "Jewel Osco", district: "J3", om: "Ada", store: "10" }, filters({ division: "Shaws" })),
  false,
);

const pack = {
  publishedAt: "2026-09-28T12:00:00Z",
  week: 32,
  summaryTitle: "Week 31",
  workbookActionBanner: 468,
  markets: [
    { label: "Total", under: 41.07, over: 4.03 },
    { label: "United", under: null, over: null },
  ],
  stores: [
    { store: "1", region: "South Region", division: "United", district: "U1", om: "A", sales: 40000, under: 20, over: 1, eff: 50, pch: 70, fourUnder: 1 },
    { store: "2", region: "South Region", division: "United", district: "U1", om: "A", sales: 40000, under: 100, over: 0, eff: 0, pch: 0, fourUnder: 0 },
  ],
};
const company = summary(pack, empty);
assert.equal(company.under, 41.07);
assert.equal(company.over, 4.03);
assert.equal(company.usesMarketLook, true);
assert.match(companyMarketNote(company, empty), /Under 60\.00% \/ Over 0\.50%/);
const united = summary(pack, filters({ division: "United" }));
assert.equal(united.usesMarketLook, true);
assert.equal(united.under, null);
assert.equal(united.over, null);
const cut = summary(pack, filters({ division: "United", district: "U1" }));
assert.equal(cut.usesMarketLook, false);
assert.equal(cut.under, 60);
assert.match(bannerMismatch(pack, company, empty), /468/);
assert.match(bannerMismatch(pack, company, empty), /qualifies 2/);

function b64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function b64urlJson(value) {
  return b64url(new TextEncoder().encode(JSON.stringify(value)));
}

const pair = await crypto.subtle.generateKey(
  { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
  true,
  ["sign", "verify"],
);
const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
jwk.kid = "test";
jwk.alg = "RS256";
const header = b64urlJson({ alg: "RS256", kid: "test", typ: "JWT" });
const now = 1_700_000_000_000;

async function token(payload) {
  const body = b64urlJson(payload);
  const data = new TextEncoder().encode(`${header}.${body}`);
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", pair.privateKey, data));
  return `${header}.${body}.${b64url(signature)}`;
}

const good = await token({
  email: "reader@example.com",
  aud: "aud-tag",
  exp: Math.floor(now / 1000) + 60,
});
const verified = await verifyAccessJwt(good, { jwks: { keys: [jwk] }, aud: "aud-tag", now });
assert.equal(verified.ok, true);
assert.equal(verified.email, "reader@example.com");

const flipped = `${good.slice(0, -4)}AAAA`;
assert.equal((await verifyAccessJwt(flipped, { jwks: { keys: [jwk] }, aud: "aud-tag", now })).ok, false);
const wrongAud = await token({ email: "reader@example.com", aud: "other", exp: Math.floor(now / 1000) + 60 });
assert.equal((await verifyAccessJwt(wrongAud, { jwks: { keys: [jwk] }, aud: "aud-tag", now })).reason, "aud");
const expired = await token({ email: "reader@example.com", aud: "aud-tag", exp: Math.floor(now / 1000) - 10 });
assert.equal((await verifyAccessJwt(expired, { jwks: { keys: [jwk] }, aud: "aud-tag", now })).reason, "exp");

clearJwksCache();
const live = await token({
  email: "reader@example.com",
  aud: "aud-tag",
  exp: Math.floor(Date.now() / 1000) + 120,
});
const request = new Request("https://heartbeat.example/api/home", {
  headers: { "Cf-Access-Jwt-Assertion": live },
});
const env = { CF_ACCESS_TEAM_DOMAIN: "team.cloudflareaccess.com", CF_ACCESS_AUD: "aud-tag" };
const allowed = await authorize(request, env, "reader@example.com\n", async () => ({ keys: [jwk] }));
assert.equal(allowed.ok, true);
const denied = await authorize(request, env, "other@example.com\n", async () => ({ keys: [jwk] }));
assert.equal(denied.reason, "allowlist");
const emptyList = await authorize(request, env, "# nobody\n", async () => ({ keys: [jwk] }));
assert.equal(emptyList.reason, "allowlist");
const open = await authorize(new Request("http://localhost/api/home"), { HEARTBEAT_WEB_DEV: "1" }, "", async () => null);
assert.equal(open.ok, true);
const locked = await authorize(new Request("https://heartbeat.pages.dev/api/home"), { HEARTBEAT_WEB_DEV: "1" }, "reader@example.com\n");
assert.equal(locked.ok, false);

const wrangler = readFileSync(join(root, "wrangler.toml"), "utf8");
assert.match(wrangler, /name = "fulfillment-heartbeat-web"/);
assert.match(wrangler, /pages_build_output_dir = "dist"/);
assert.equal(wrangler.includes("heartbeat-web.pages.dev"), false);
const built = spawnSync(process.execPath, ["scripts/stage_pages.mjs"], { cwd: root });
assert.equal(built.status, 0, built.stderr.toString());
const distIndex = readFileSync(join(root, "dist/index.html"), "utf8");
assert.match(distIndex, /HB-0828\.494/);
assert.equal(distIndex.includes("pages.dev"), false);
assert.equal(statSync(join(root, "functions/api/[[path]].js")).isFile(), true);

console.log("web ok");
