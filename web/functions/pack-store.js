// R2 layout for a data-only refresh. The Mac uploads JSON with an R2 token.
// It does not create a Pages deployment.
//
//   heartbeat-packs / web-pack/current.json
//     { prefix, cookSha, cookedAt, publishedAt, schemaVersion, previous: { same } }
//   heartbeat-packs / web-pack/<cookSha>-<cookedAt>/<same path as /data/...>
//     home.json, schedule.json, presub.json, section/<section>.json
//
// current.json is written last, after check_pack on the uploaded set. The
// prefix is the pointer's stored prefix. A prefix is one cook: if any JSON
// file under it fails the pointer, every read uses the previous pack. A
// missing file is refused or served from that whole previous pack. It is
// not filled from the static /data tree. The client pins the pack id it
// read from home, and later section reads stay on that prefix. A bare
// web-pack/home.json is not a pack.
//
// A pack with no cookedAt is not served, except the live cook pinned below.
// That cook stays readable only at its exact prefix, and only when all 16
// pack files hash to PINNED_FILE_SHA256. Nothing may publish a cookedAt-less pack.
// A missing current.json is absent: /data falls through to the static tree.
// A pointer that exists but cannot be served stays a 404.

import { SCHEMA_VERSION } from "../public/schema.js";

export const PINNED_LIVE_COOK_SHA = "74d44dde02a0e1c6430a9a78b06034099c84e001";
export const PINNED_LIVE_PUBLISHED_AT = "2026-10-06T01:35:23Z";
export const PINNED_LIVE_PREFIX = `web-pack/${PINNED_LIVE_COOK_SHA}-${PINNED_LIVE_PUBLISHED_AT}`;
export const PINNED_HOME_SHA256 = "fece0ad52e54aa5cb3cb7a3637552d831a4e276d28b695ca3b2797172f7d839a";
export const PACK_FILES = [
  "home.json",
  "presub.json",
  "schedule.json",
  "section/dynacap.json",
  "section/five_star.json",
  "section/labor.json",
  "section/lost_revenue.json",
  "section/missing_items.json",
  "section/pick_path.json",
  "section/pick_path_picker.json",
  "section/picker_scorecard.json",
  "section/pph.json",
  "section/pre_sub_oos.json",
  "section/prep_not_ready.json",
  "section/sales.json",
  "section/schedule_quality.json",
];
export const PINNED_FILE_SHA256 = {
  "home.json": "fece0ad52e54aa5cb3cb7a3637552d831a4e276d28b695ca3b2797172f7d839a",
  "presub.json": "4a6dae1b78bc7afdc112cfb01f35f74c030f67a7628f01d532d042c7a7d88012",
  "schedule.json": "355d9380e063a6ed91b10f8eddd5e6b9e3b99029423951da38f685e382c482dd",
  "section/dynacap.json": "74ddae60e9f08890eec74033b23a9b065ae898aded143c7c05e766389f16267f",
  "section/five_star.json": "d897682fab9e9d4c99ef0a2233ac45e51162f7843846f380545151d8f656de1b",
  "section/labor.json": "f5c13b9cfc27045ea956e1c91feb5deb595919ab88f82694a8135f78ff6d3ad6",
  "section/lost_revenue.json": "ea5eb712edbedb5e29faca53711ff411b9e7bc0e4086d81bfb7e52bdae3fc997",
  "section/missing_items.json": "0e36937798275be90eb43ac08c5a252e05faf2c4d72cd499eb0f54294fab0862",
  "section/pick_path.json": "e015cd3fa533e4855ad424c17e9c582222735e2200a5302d6733a8c571adb6c2",
  "section/pick_path_picker.json": "2ffa0122cca2023c22e58ce7cab3e424315d2c12b59f0a8add51a7c88c0b357d",
  "section/picker_scorecard.json": "ed295d81358eb147913c1eb957c526b652b4b229a125605b35b6b00873b6c272",
  "section/pph.json": "58b52591cdedd9369650f6981e0a82c0f60f86dfa0224cadbe841241bb0da40a",
  "section/pre_sub_oos.json": "e991bdc34396bf4c832e117bbe910f22b89e09657f0a8afad4defe846d54094f",
  "section/prep_not_ready.json": "9346af1bde88fd7eef9484218ef8fa0389968e2b6d10ed5c501c1458f718a9ec",
  "section/sales.json": "b75d871813f5f29cbb7930792801c39d1e6533cda2e9f5d7a1ab725055a9eb7c",
  "section/schedule_quality.json": "b77a0309c20cec4084aac27cc2cea3328fc7a0fcad25f8bdd1b0f29a89b0d62d",
};

export function isPinnedLivePack(cookSha, publishedAt, cookedAt = "", prefix = "") {
  return (
    cookSha === PINNED_LIVE_COOK_SHA &&
    publishedAt === PINNED_LIVE_PUBLISHED_AT &&
    !cookedAt &&
    prefix === PINNED_LIVE_PREFIX
  );
}

export async function sha256Hex(text) {
  const bytes = new TextEncoder().encode(String(text ?? ""));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
export const PACK_POINTER_KEY = "web-pack/current.json";

const SHA = /^[0-9a-f]{40}$/;

export function packPrefix(cookSha, publishedAt) {
  const sha = String(cookSha || "");
  const published = String(publishedAt || "");
  if (!SHA.test(sha) || !published || /[\\/]/.test(published) || published.includes("..")) return "";
  return `web-pack/${sha}-${published}`;
}

export function packObjectKey(prefix, rel) {
  const base = String(prefix || "").replace(/\/+$/, "");
  const path = String(rel || "").replace(/^\/+/, "");
  if (!base.startsWith("web-pack/") || base.includes("..") || path.includes("..")) return "";
  return `${base}/${path}`;
}

function finite(value) {
  return typeof value === "number" && Number.isFinite(value);
}

// schemaVersion, cookSha, and the keys a page cannot paint without.
// Week-specific goldens stay in check_pack.mjs so next week's pack can upload.
export function guardHome(home) {
  const errors = [];
  if (!home || typeof home !== "object" || Array.isArray(home)) {
    errors.push("home.json is not an object");
    return errors;
  }
  const metadata = home.metadata && typeof home.metadata === "object" ? home.metadata : {};
  if (metadata.schemaVersion !== SCHEMA_VERSION) {
    errors.push(`schemaVersion=${metadata.schemaVersion ?? "missing"} expected ${SCHEMA_VERSION}`);
  }
  if (typeof metadata.cookSha !== "string" || !SHA.test(metadata.cookSha)) {
    errors.push("cookSha missing");
  }
  const labor = home.laborMarket && typeof home.laborMarket === "object" ? home.laborMarket : null;
  if (!labor) {
    errors.push("laborMarket missing");
  } else {
    if ("weight" in labor) errors.push("laborMarket has a weight field");
    const aiv = labor.aiv_impact_pct;
    const uplh = labor.uplh_impact_pct;
    const wage = labor.wage_impact_pct;
    const target = labor.target_vs_actual_pct;
    if (!finite(aiv) || !finite(uplh) || !finite(wage) || !finite(target)) {
      errors.push("laborMarket bridge missing");
    } else if (Math.abs(uplh + wage + aiv - target) > 0.01) {
      errors.push("laborMarket bridge does not add up");
    }
  }
  if (!Array.isArray(home.regionTables) || home.regionTables.length < 1) errors.push("regionTables missing");
  if (!Array.isArray(home.summaries) || home.summaries.length < 1) errors.push("summaries missing");
  if (!home.companyTiles || typeof home.companyTiles !== "object" || Array.isArray(home.companyTiles)) {
    errors.push("companyTiles missing");
  }
  const stores = home.filters && home.filters.stores;
  if (!Array.isArray(stores) || stores.length < 1) errors.push("filters.stores missing");
  return errors;
}

const RAW_DIVISIONS = new Set([
  "DENVER",
  "INTERMOUNTAIN",
  "JEWEL",
  "SO CALIFORNIA",
  "NOR. CALIFORNIA",
  "NOR CALIFORNIA",
]);

export function rawDivisionName(value) {
  return RAW_DIVISIONS.has(String(value || "").trim().toUpperCase());
}

let cache = { pointer: "", entry: null, rejectedPrefix: "", acceptedPrefix: "", acceptedKeys: null };

export function resetPackCache() {
  cache = { pointer: "", entry: null, rejectedPrefix: "", acceptedPrefix: "", acceptedKeys: null };
}

function pointerEntry(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const cookSha = typeof value.cookSha === "string" ? value.cookSha : "";
  const publishedAt = typeof value.publishedAt === "string" ? value.publishedAt : "";
  const cookedAt = typeof value.cookedAt === "string" ? value.cookedAt : "";
  const schemaVersion = value.schemaVersion;
  const prefix = typeof value.prefix === "string" && value.prefix ? value.prefix : packPrefix(cookSha, publishedAt);
  if (!SHA.test(cookSha) || schemaVersion !== SCHEMA_VERSION) return null;
  if (!prefix.startsWith("web-pack/") || prefix.includes("..") || /[\\]/.test(prefix)) return null;
  if (!cookedAt && !isPinnedLivePack(cookSha, publishedAt, cookedAt, prefix)) return null;
  return { prefix, cookSha, publishedAt, cookedAt, schemaVersion };
}

function fileStamp(json) {
  const metadata = json.metadata && typeof json.metadata === "object" ? json.metadata : {};
  const cookedAt = typeof json.cookedAt === "string" ? json.cookedAt : typeof metadata.cookedAt === "string" ? metadata.cookedAt : "";
  const publishedAt = typeof json.publishedAt === "string" ? json.publishedAt : typeof metadata.publishedAt === "string" ? metadata.publishedAt : "";
  return {
    schemaVersion: json.schemaVersion != null ? json.schemaVersion : metadata.schemaVersion,
    cookSha: json.cookSha != null ? json.cookSha : metadata.cookSha,
    publishedAt,
    cookedAt,
  };
}

function fileMatches(json, entry) {
  if (!json || typeof json !== "object" || Array.isArray(json)) return false;
  const stamp = fileStamp(json);
  if (stamp.schemaVersion !== entry.schemaVersion || stamp.cookSha !== entry.cookSha) return false;
  if ((stamp.cookedAt || "") !== (entry.cookedAt || "")) return false;
  if (!entry.cookedAt && !isPinnedLivePack(entry.cookSha, entry.publishedAt, entry.cookedAt, entry.prefix)) return false;
  if (!stamp.cookedAt && stamp.publishedAt && stamp.publishedAt !== entry.publishedAt) return false;
  return true;
}

async function readJson(bucket, key) {
  let object;
  try {
    object = await bucket.get(key);
  } catch {
    return null;
  }
  if (!object) return null;
  let text = "";
  try {
    text = typeof object.text === "function" ? await object.text() : "";
  } catch {
    return null;
  }
  try {
    return { json: JSON.parse(text), text };
  } catch {
    return { json: null, text };
  }
}

async function loadPointer(bucket) {
  let object;
  try {
    object = await bucket.get(PACK_POINTER_KEY);
  } catch {
    return { absent: false, current: null, previous: null };
  }
  if (!object) {
    cache = { pointer: "", entry: null, rejectedPrefix: "", acceptedPrefix: "", acceptedKeys: null };
    return { absent: true, current: null, previous: null };
  }
  let text = "";
  try {
    text = typeof object.text === "function" ? await object.text() : "";
  } catch {
    return { absent: false, current: null, previous: null };
  }
  if (cache.pointer !== text) cache = { pointer: text, entry: null, rejectedPrefix: "", acceptedPrefix: "", acceptedKeys: null };
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  // Empty or corrupt JSON is a pointer that exists. It is not absent.
  if (!json || typeof json !== "object" || Array.isArray(json)) return { absent: false, current: null, previous: null };
  return { absent: false, current: pointerEntry(json), previous: pointerEntry(json.previous) };
}

async function readGuardedObject(bucket, entry, rel) {
  const key = packObjectKey(entry.prefix, rel);
  if (!key) return null;
  const read = await readJson(bucket, key);
  if (!read || !fileMatches(read.json, entry)) return null;
  return { body: read.text, text: async () => read.text };
}

async function listPackKeys(bucket, prefix) {
  if (!bucket || typeof bucket.list !== "function") return null;
  const base = `${String(prefix || "").replace(/\/+$/, "")}/`;
  const keys = [];
  let cursor = undefined;
  do {
    let page;
    try {
      page = await bucket.list(cursor ? { prefix: base, cursor } : { prefix: base });
    } catch {
      return null;
    }
    const objects = page && Array.isArray(page.objects) ? page.objects : [];
    for (const object of objects) {
      const key = typeof object === "string" ? object : object && object.key;
      if (typeof key === "string" && key.endsWith(".json") && key.startsWith(base)) keys.push(key);
    }
    cursor = page && page.truncated && page.cursor ? page.cursor : "";
  } while (cursor);
  return keys;
}

// Every JSON object under the prefix has to match the pointer. One bad file
// rejects the whole prefix so a later read cannot serve a sibling from it.
async function prefixKeys(bucket, entry, seenPointer) {
  if (seenPointer != null && cache.pointer !== seenPointer) return null;
  if (cache.acceptedPrefix === entry.prefix && cache.acceptedKeys) return cache.acceptedKeys;
  const keys = await listPackKeys(bucket, entry.prefix);
  if (!keys) return null;
  const base = `${entry.prefix.replace(/\/+$/, "")}/`;
  if (!entry.cookedAt) {
    if (!isPinnedLivePack(entry.cookSha, entry.publishedAt, entry.cookedAt, entry.prefix)) return null;
    const present = new Set(keys.map((key) => key.slice(base.length)));
    for (const rel of PACK_FILES) {
      if (!present.has(rel)) return null;
      const read = await readJson(bucket, `${base}${rel}`);
      if (!read || !read.json || !fileMatches(read.json, entry)) return null;
      if ((await sha256Hex(read.text)) !== PINNED_FILE_SHA256[rel]) return null;
    }
  }
  let homeSeen = false;
  for (const key of keys) {
    const rel = key.slice(base.length);
    const read = await readJson(bucket, key);
    if (!read || !read.json || !fileMatches(read.json, entry)) return null;
    if (rel !== "home.json") continue;
    homeSeen = true;
    if (guardHome(read.json).length) return null;
    const metadata = read.json.metadata && typeof read.json.metadata === "object" ? read.json.metadata : {};
    if (metadata.cookSha !== entry.cookSha || metadata.schemaVersion !== entry.schemaVersion) return null;
    if (fileStamp(read.json).cookedAt !== entry.cookedAt) return null;
  }
  if (!homeSeen) return null;
  if (seenPointer != null && cache.pointer !== seenPointer) return null;
  cache.acceptedPrefix = entry.prefix;
  cache.acceptedKeys = new Set(keys);
  return cache.acceptedKeys;
}

export function dataPath(pathname) {
  const rel = String(pathname || "").replace(/^\/data\//, "");
  if (!rel || rel.includes("..") || rel.includes("\\") || !/^[\w./-]+$/.test(rel) || !rel.endsWith(".json")) return "";
  return rel;
}

// /api/<name> is the same guarded pack as /data/<name>.json. It is not a
// bucket key. Callers must not turn this into web-pack/home.json.
export function packApiPath(pathname) {
  const rest = String(pathname || "")
    .replace(/^\/api\/?/, "")
    .split("?")[0]
    .replace(/\/+$/, "");
  if (!rest || rest.includes("..") || rest.includes("\\") || rest.includes("//")) return "";
  if (/r2\.dev/i.test(rest) || /sqlite/i.test(rest) || /:\/\//.test(rest)) return "";
  if (rest === "home" || rest === "presub" || rest === "schedule") return `${rest}.json`;
  const match = rest.match(/^section\/([a-z0-9_]+)$/);
  if (!match) return "";
  return `section/${match[1]}.json`;
}

function requestTarget(url) {
  let parsed;
  try {
    parsed = new URL(url, "https://fulfillment-heartbeat-web.pages.dev");
  } catch {
    return null;
  }
  let pathname = parsed.pathname;
  if (pathname.startsWith("/api/")) {
    const rel = packApiPath(pathname);
    if (!rel) return null;
    pathname = `/data/${rel}`;
  }
  const pin = {
    cookSha: parsed.searchParams.get("cookSha") || "",
    publishedAt: parsed.searchParams.get("publishedAt") || "",
    cookedAt: parsed.searchParams.get("cookedAt") || "",
  };
  return { rel: dataPath(pathname), pin };
}

function samePinnedPack(entry, pin) {
  if (!pin.cookSha) return false;
  return (
    entry.cookSha === pin.cookSha &&
    entry.publishedAt === pin.publishedAt &&
    (entry.cookedAt || "") === (pin.cookedAt || "")
  );
}

export async function readPackObject(bucket, url) {
  const target = requestTarget(url);
  if (!target || !target.rel || !bucket || typeof bucket.get !== "function") return null;
  const loaded = await loadPointer(bucket);
  if (loaded.absent) return { absent: true };
  const seenPointer = cache.pointer;
  const { current, previous } = loaded;
  const candidates = [];
  if (current && cache.rejectedPrefix !== current.prefix) candidates.push(current);
  if (previous && cache.rejectedPrefix !== previous.prefix) candidates.push(previous);
  let list = candidates;
  if (target.pin.cookSha) {
    list = candidates.filter((entry) => samePinnedPack(entry, target.pin));
    if (!list.length) return { missing: true };
  } else if (cache.entry) {
    const pinned = list.find((item) => item.prefix === cache.entry.prefix);
    if (pinned) {
      list.splice(list.indexOf(pinned), 1);
      list.unshift(pinned);
    }
  }
  for (const entry of list) {
    const keys = await prefixKeys(bucket, entry, seenPointer);
    if (cache.pointer !== seenPointer) return { missing: true };
    if (target.pin.cookSha && !samePinnedPack(entry, target.pin)) return { missing: true };
    if (!keys) {
      if (cache.acceptedPrefix === entry.prefix) {
        cache.acceptedPrefix = "";
        cache.acceptedKeys = null;
      }
      if (current && entry.prefix === current.prefix) cache.rejectedPrefix = current.prefix;
      if (target.pin.cookSha) return { missing: true };
      continue;
    }
    const key = packObjectKey(entry.prefix, target.rel);
    if (!key || !keys.has(key)) {
      // This prefix is one cook. A missing file is not filled from static /data.
      // Without a client pin, the whole previous pack is the only fallback.
      if (target.pin.cookSha) return { missing: true };
      continue;
    }
    const object = await readGuardedObject(bucket, entry, target.rel);
    if (cache.pointer !== seenPointer) return { missing: true };
    if (target.pin.cookSha && !samePinnedPack(entry, target.pin)) return { missing: true };
    if (!object) {
      if (current && entry.prefix === current.prefix) cache.rejectedPrefix = current.prefix;
      cache.acceptedPrefix = "";
      cache.acceptedKeys = null;
      if (target.pin.cookSha) return { missing: true };
      continue;
    }
    if (cache.pointer !== seenPointer) return { missing: true };
    if (target.pin.cookSha && !samePinnedPack(entry, target.pin)) return { missing: true };
    cache.entry = entry;
    return object;
  }
  return { missing: true };
}
