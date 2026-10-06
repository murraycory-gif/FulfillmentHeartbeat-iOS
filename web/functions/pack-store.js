// R2 layout for a data-only refresh. The Mac uploads JSON with an R2 token.
// It does not create a Pages deployment.
//
//   heartbeat-packs / web-pack/current.json
//     { prefix, cookSha, publishedAt, schemaVersion, previous: { same } }
//   heartbeat-packs / web-pack/<cookSha>-<publishedAt>/<same path as /data/...>
//     home.json, schedule.json, presub.json, section/<section>.json
//
// current.json is written last, after check_pack on the uploaded set. A prefix
// whose home fails the guard, or whose file schemaVersion/cookSha disagrees
// with the pointer, is left in the bucket. Reads keep the last good pointer
// entry. No pointer yet falls through to the static /data files from the last
// full deploy. A bare web-pack/home.json is not a pack.

import { SCHEMA_VERSION } from "../public/schema.js";

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

let cache = { pointer: "", entry: null, rejectedPrefix: "" };

export function resetPackCache() {
  cache = { pointer: "", entry: null, rejectedPrefix: "" };
}

function pointerEntry(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const cookSha = typeof value.cookSha === "string" ? value.cookSha : "";
  const publishedAt = typeof value.publishedAt === "string" ? value.publishedAt : "";
  const schemaVersion = value.schemaVersion;
  const prefix = typeof value.prefix === "string" && value.prefix ? value.prefix : packPrefix(cookSha, publishedAt);
  if (!SHA.test(cookSha) || schemaVersion !== SCHEMA_VERSION) return null;
  if (!prefix.startsWith("web-pack/") || prefix.includes("..") || /[\\]/.test(prefix)) return null;
  return { prefix, cookSha, publishedAt, schemaVersion };
}

function fileStamp(json) {
  const metadata = json.metadata && typeof json.metadata === "object" ? json.metadata : {};
  return {
    schemaVersion: json.schemaVersion != null ? json.schemaVersion : metadata.schemaVersion,
    cookSha: json.cookSha != null ? json.cookSha : metadata.cookSha,
  };
}

function fileMatches(json, entry) {
  if (!json || typeof json !== "object" || Array.isArray(json)) return false;
  const stamp = fileStamp(json);
  return stamp.schemaVersion === entry.schemaVersion && stamp.cookSha === entry.cookSha;
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
  if (cache.pointer !== pointerText) cache = { pointer: pointerText, entry: null, rejectedPrefix: "" };
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

async function homeOk(bucket, entry) {
  const home = await readGuardedObject(bucket, entry, "home.json");
  if (!home) return false;
  let json = null;
  try {
    json = JSON.parse(await home.text());
  } catch {
    return false;
  }
  if (guardHome(json).length) return false;
  const metadata = json.metadata && typeof json.metadata === "object" ? json.metadata : {};
  return metadata.cookSha === entry.cookSha && metadata.schemaVersion === entry.schemaVersion;
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

export async function readPackObject(bucket, pathname) {
  const rel = dataPath(pathname.startsWith("/data/") ? pathname : `/data/${pathname}`);
  if (!rel || !bucket || typeof bucket.get !== "function") return null;
  const { current, previous } = await loadPointer(bucket);
  const candidates = [];
  if (current && cache.rejectedPrefix !== current.prefix) candidates.push(current);
  if (previous && cache.rejectedPrefix !== previous.prefix) candidates.push(previous);
  if (cache.entry) {
    const pinned = candidates.find((item) => item.prefix === cache.entry.prefix);
    if (pinned) {
      candidates.splice(candidates.indexOf(pinned), 1);
      candidates.unshift(pinned);
    }
  }
  for (const entry of candidates) {
    if (!(await homeOk(bucket, entry))) {
      if (current && entry.prefix === current.prefix) cache.rejectedPrefix = current.prefix;
      continue;
    }
    const object = rel === "home.json" ? await readGuardedObject(bucket, entry, "home.json") : await readGuardedObject(bucket, entry, rel);
    if (!object) {
      if (current && entry.prefix === current.prefix) cache.rejectedPrefix = current.prefix;
      continue;
    }
    cache.entry = entry;
    return object;
  }
  return null;
}
