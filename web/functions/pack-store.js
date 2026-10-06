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
// That cook stays readable. Nothing may publish it again.

import { SCHEMA_VERSION } from "../public/schema.js";

export const PINNED_LIVE_COOK_SHA = "74d44dde02a0e1c6430a9a78b06034099c84e001";
export const PINNED_LIVE_PUBLISHED_AT = "2026-10-06T01:35:23Z";

export function isPinnedLivePack(cookSha, publishedAt, cookedAt = "") {
  return cookSha === PINNED_LIVE_COOK_SHA && publishedAt === PINNED_LIVE_PUBLISHED_AT && !cookedAt;
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
  if (!cookedAt && !isPinnedLivePack(cookSha, publishedAt, cookedAt)) return null;
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
  if (!entry.cookedAt && !isPinnedLivePack(entry.cookSha, entry.publishedAt, entry.cookedAt)) return false;
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
  const pointerRead = await readJson(bucket, PACK_POINTER_KEY);
  const pointerText = pointerRead ? pointerRead.text : "";
  if (cache.pointer !== pointerText) cache = { pointer: pointerText, entry: null, rejectedPrefix: "", acceptedPrefix: "", acceptedKeys: null };
  const pointer = pointerRead && pointerRead.json && typeof pointerRead.json === "object" ? pointerRead.json : {};
  return { current: pointerEntry(pointer), previous: pointerEntry(pointer.previous) };
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
async function prefixKeys(bucket, entry) {
  if (cache.acceptedPrefix === entry.prefix && cache.acceptedKeys) return cache.acceptedKeys;
  const keys = await listPackKeys(bucket, entry.prefix);
  if (!keys) return null;
  const base = `${entry.prefix.replace(/\/+$/, "")}/`;
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
    if (!entry.cookedAt && !isPinnedLivePack(entry.cookSha, entry.publishedAt, entry.cookedAt)) return null;
  }
  if (!homeSeen) return null;
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
  const { current, previous } = await loadPointer(bucket);
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
    const keys = await prefixKeys(bucket, entry);
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
    if (!object) {
      if (current && entry.prefix === current.prefix) cache.rejectedPrefix = current.prefix;
      cache.acceptedPrefix = "";
      cache.acceptedKeys = null;
      if (target.pin.cookSha) return { missing: true };
      continue;
    }
    cache.entry = entry;
    return object;
  }
  return { missing: true };
}
