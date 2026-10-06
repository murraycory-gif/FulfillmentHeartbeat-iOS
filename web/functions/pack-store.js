// R2 layout for a data-only refresh. The Mac uploads JSON with an R2 token.
// It does not create a Pages deployment.
//
//   heartbeat-packs / web-pack/pointer.json
//     { "current": "<40 hex cookSha>", "previous": "<40 hex cookSha or empty>" }
//   heartbeat-packs / web-pack/packs/<cookSha>/<same path as /data/...>
//     home.json, schedule.json, presub.json, section/<section>.json
//
// pointer.json is written last. A current pack that fails the guard is left
// in the bucket, and reads serve previous. No pointer yet falls through to
// the static /data files from the last full deploy.

import { SCHEMA_VERSION } from "../public/schema.js";

export const PACK_POINTER_KEY = "web-pack/pointer.json";

const SHA = /^[0-9a-f]{40}$/;

export function packObjectKey(cookSha, rel) {
  return `web-pack/packs/${cookSha}/${rel}`;
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

let cache = { pointer: "", sha: "" };

export function resetPackCache() {
  cache = { pointer: "", sha: "" };
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

export async function selectPackSha(bucket) {
  if (!bucket || typeof bucket.get !== "function") return "";
  const pointerRead = await readJson(bucket, PACK_POINTER_KEY);
  const pointerText = pointerRead ? pointerRead.text : "";
  if (cache.pointer === pointerText && cache.sha) return cache.sha;
  const pointer = pointerRead && pointerRead.json && typeof pointerRead.json === "object" ? pointerRead.json : {};
  const candidates = [pointer.current, pointer.previous].filter((sha) => typeof sha === "string" && SHA.test(sha));
  for (const sha of candidates) {
    const home = await readJson(bucket, packObjectKey(sha, "home.json"));
    if (!home || !home.json) continue;
    if (guardHome(home.json).length) continue;
    if (home.json.metadata.cookSha !== sha) continue;
    cache = { pointer: pointerText, sha };
    return sha;
  }
  cache = { pointer: pointerText, sha: "" };
  return "";
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
  if (!rel) return null;
  const sha = await selectPackSha(bucket);
  if (!sha) return null;
  try {
    const object = await bucket.get(packObjectKey(sha, rel));
    return object || null;
  } catch {
    return null;
  }
}
