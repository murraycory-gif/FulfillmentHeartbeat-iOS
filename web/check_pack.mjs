// Required-keys check for a cooked web pack directory.
// The Mac push runs this before upload:
//   node web/check_pack.mjs web/public/data
// A failing pack exits non-zero and must not be uploaded.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { SCHEMA_VERSION } from "./public/schema.js";
import { guardHome, rawDivisionName } from "./functions/pack-store.js";

function readJson(dir, name) {
  const file = join(dir, name);
  if (!existsSync(file)) return { error: `${name} is missing`, value: null };
  try {
    return { error: "", value: JSON.parse(readFileSync(file, "utf8")) };
  } catch {
    return { error: `${name} is not JSON`, value: null };
  }
}

function finite(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function blend(stores, markets, region, field) {
  const scoped = stores.filter((store) => store && store.region === region);
  const divisions = new Set(scoped.map((store) => store.division));
  let weight = 0;
  let total = 0;
  for (const division of divisions) {
    const market = markets.get(division) || {};
    const value = market[field];
    if (value == null) continue;
    const count = scoped.filter((store) => store.division === division).length;
    if (!count) continue;
    weight += count;
    total += Number(value) * count;
  }
  return weight ? total / weight : null;
}

const BANNED_PUBLISHED = [/^2026-09-29/, /^2026-09-30/];

function jsonFiles(dir, rel = "") {
  const out = [];
  for (const name of readdirSync(join(dir, rel))) {
    const next = rel ? `${rel}/${name}` : name;
    const full = join(dir, next);
    if (statSync(full).isDirectory()) out.push(...jsonFiles(dir, next));
    else if (name.endsWith(".json")) out.push(next);
  }
  return out.sort();
}

export function packFileStamp(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return {
    publishedAt: typeof value.publishedAt === "string" ? value.publishedAt : "",
    schemaVersion: value.schemaVersion,
    cookSha: typeof value.cookSha === "string" ? value.cookSha : "",
  };
}

export function packIdentityErrors(dir) {
  const errors = [];
  let files = [];
  try {
    files = jsonFiles(dir);
  } catch {
    return ["pack directory is missing"];
  }
  if (!files.length) return ["pack directory has no json files"];
  let expected = null;
  for (const rel of files) {
    const read = readJson(dir, rel);
    if (read.error) {
      errors.push(read.error);
      continue;
    }
    const stamp = packFileStamp(read.value);
    if (!stamp || stamp.publishedAt.length < 20) errors.push(`${rel} publishedAt missing`);
    if (!stamp || stamp.schemaVersion !== SCHEMA_VERSION) errors.push(`${rel} schemaVersion=${stamp ? stamp.schemaVersion : "missing"}`);
    if (!stamp || !/^[0-9a-f]{40}$/.test(stamp.cookSha)) errors.push(`${rel} cookSha missing`);
    if (stamp && BANNED_PUBLISHED.some((pattern) => pattern.test(stamp.publishedAt))) {
      errors.push(`${rel} publishedAt ${stamp.publishedAt} is a retired pack`);
    }
    if (stamp && stamp.publishedAt && stamp.schemaVersion === SCHEMA_VERSION && /^[0-9a-f]{40}$/.test(stamp.cookSha)) {
      const key = `${stamp.publishedAt}\0${stamp.schemaVersion}\0${stamp.cookSha}`;
      if (!expected) expected = key;
      else if (expected !== key) errors.push(`${rel} stamp does not match the rest of the pack`);
    }
  }
  return errors;
}

export function checkPack(dir) {
  const errors = [...packIdentityErrors(dir)];
  const homeRead = readJson(dir, "home.json");
  const scheduleRead = readJson(dir, "schedule.json");
  const lostRead = readJson(dir, "section/lost_revenue.json");
  const dynacapRead = readJson(dir, "section/dynacap.json");
  const laborRead = readJson(dir, "section/labor.json");
  for (const read of [homeRead, scheduleRead, lostRead, dynacapRead, laborRead]) {
    if (read.error) errors.push(read.error);
  }
  const home = homeRead.value && typeof homeRead.value === "object" && !Array.isArray(homeRead.value) ? homeRead.value : {};
  const schedule = scheduleRead.value && typeof scheduleRead.value === "object" && !Array.isArray(scheduleRead.value) ? scheduleRead.value : {};
  const lost = lostRead.value && typeof lostRead.value === "object" ? lostRead.value : {};
  const dynacap = dynacapRead.value && typeof dynacapRead.value === "object" ? dynacapRead.value : {};
  const laborFile = laborRead.value && typeof laborRead.value === "object" ? laborRead.value : {};
  if (homeRead.value && (typeof homeRead.value !== "object" || Array.isArray(homeRead.value))) {
    errors.push("home.json is not an object");
  }
  if (scheduleRead.value && (typeof scheduleRead.value !== "object" || Array.isArray(scheduleRead.value))) {
    errors.push("schedule.json is not an object");
  }

  errors.push(...guardHome(homeRead.value));

  const labor = home.laborMarket && typeof home.laborMarket === "object" ? home.laborMarket : {};
  if ("weight" in labor && !errors.some((item) => item.includes("weight"))) errors.push("laborMarket has a weight field");
  const aiv = finite(labor.aiv_impact_pct);
  const uplh = finite(labor.uplh_impact_pct);
  const wage = finite(labor.wage_impact_pct);
  const target = finite(labor.target_vs_actual_pct);
  if (aiv == null || uplh == null || wage == null || target == null) {
    errors.push(`laborMarket bridge=${labor.aiv_impact_pct},${labor.uplh_impact_pct},${labor.wage_impact_pct},${labor.target_vs_actual_pct}`);
  } else if (Math.abs(uplh + wage + aiv - target) > 0.01) {
    errors.push("laborMarket bridge does not add up");
  }

  const tiles = home.companyTiles && typeof home.companyTiles === "object" ? home.companyTiles : {};
  const laborTiles = tiles.labor && typeof tiles.labor === "object" ? tiles.labor : {};
  const laborLabels = Array.isArray(laborTiles.labels) ? laborTiles.labels : [];
  const laborValues = Array.isArray(laborTiles.values) ? laborTiles.values : [];
  const aivTile = laborLabels.includes("AIV") ? laborValues[laborLabels.indexOf("AIV")] : null;
  if (aivTile !== "0.00%") errors.push(`AIV tile=${aivTile}`);

  const laborRows = Array.isArray(laborFile.rows) ? laborFile.rows : [];
  let bridged = 0;
  for (const row of laborRows) {
    const payload = row.payload || {};
    const parts = [payload.uplh_impact_pct, payload.wage_impact_pct, payload.aiv_impact_pct, payload.target_vs_actual_pct];
    if (parts.some((part) => part == null)) continue;
    bridged += 1;
    if (Math.abs(Number(parts[0]) + Number(parts[1]) + Number(parts[2]) - Number(parts[3])) > 0.01) {
      errors.push(`labor bridge ${row.store}`);
      break;
    }
  }
  if (bridged !== 2109) errors.push(`labor bridge rows=${bridged}`);

  const flagged = new Map(
    laborRows.filter((row) => row.sourceIssue === "source data issue").map((row) => [String(row.store), row]),
  );
  for (const store of ["233", "4799", "1509"]) {
    if (!flagged.has(store)) errors.push(`missing source data issue ${store}`);
  }
  const plain = laborRows.find((row) => String(row.store) === "1");
  const plainAiv = finite((plain && plain.payload && plain.payload.aiv_impact_pct) ?? null);
  if (!plain || plain.sourceIssue || plainAiv == null || Math.abs(plainAiv - -0.38645958215580284) > 1e-6) {
    errors.push("store 1 AIV changed");
  }
  let weightedNum = 0;
  let weightedDen = 0;
  let simpleNum = 0;
  let simpleCount = 0;
  for (const row of laborRows) {
    const payload = row.payload || {};
    const rowAiv = finite(payload.aiv_impact_pct);
    const rowWeight = finite(payload.weight);
    if (rowAiv == null) continue;
    if (rowWeight == null || rowWeight < 0) {
      errors.push(`labor weight missing ${row.store}`);
      break;
    }
    const cost = finite(payload.cost_trgt_pct);
    if (cost == null) continue;
    weightedNum += rowAiv * rowWeight;
    weightedDen += rowWeight;
    simpleNum += rowAiv;
    simpleCount += 1;
  }
  if (aiv != null && weightedDen > 0) {
    const weighted = weightedNum / weightedDen;
    const simple = simpleCount ? simpleNum / simpleCount : null;
    if (Math.abs(weighted - aiv) > 0.001) {
      errors.push(`labor AIV weighted=${weighted} company=${aiv}`);
    }
    if (simple != null && Math.abs(simple - aiv) <= Math.abs(weighted - aiv)) {
      errors.push(`labor AIV simple average ${simple} is as close as the hours weight`);
    }
  }

  if (!Array.isArray(home.regionTables) || home.regionTables.length < 10) errors.push("regionTables missing");

  const lostTiles = tiles.lost_revenue && typeof tiles.lost_revenue === "object" ? tiles.lost_revenue : {};
  const lostLabels = Array.isArray(lostTiles.labels) ? lostTiles.labels : [];
  const lostValues = Array.isArray(lostTiles.values) ? lostTiles.values : [];
  const lostTile = (name) => (lostLabels.includes(name) ? lostValues[lostLabels.indexOf(name)] : null);
  if (lostTile("Goal %") !== "3.06%") errors.push(`Goal %=${lostTile("Goal %")}`);
  if (lostTile("Lost %") !== "5.19%") errors.push(`Lost %=${lostTile("Lost %")}`);
  if (!String(lostTile("Missed") || "").startsWith("$")) errors.push(`Missed=${lostTile("Missed")}`);

  const summaries = new Map((Array.isArray(home.summaries) ? home.summaries : []).filter((item) => item && typeof item === "object").map((item) => [item.section, item]));
  const pph = summaries.get("pph") || {};
  if (!String(pph.secondary || "").includes("between 74 and 80")) errors.push(`pph secondary=${pph.secondary}`);
  if (pph.health === "risk") errors.push("pph health is risk at a 74+ average");

  const roster = home.filters && Array.isArray(home.filters.stores) ? home.filters.stores : [];
  const byStore = new Map(roster.filter((item) => item && typeof item === "object").map((item) => [String(item.store), item]));
  const expected = {
    233: ["Seattle", "28", "Ryan Burns"],
    339: ["Mountain West", "I5", "Chris Banuelos"],
    879: ["Mountain West", "66", "Ellas Ware"],
    1509: ["Mountain West", "I5", "Chris Banuelos"],
    4799: ["Jewel Osco", "J6", "Mike Macdonald"],
    210: ["United", "U5", "Andrew Quinn"],
    239: ["Southwest", "N0", "Ben Sarmadi"],
  };
  for (const [store, ident] of Object.entries(expected)) {
    const row = byStore.get(store) || {};
    const got = [row.division, row.district, row.om];
    if (got.join("\0") !== ident.join("\0")) errors.push(`roster ${store}=${got.join(",")}`);
  }

  const rosterCounts = new Map();
  for (const item of roster) {
    const division = item && item.division;
    if (!division) continue;
    rosterCounts.set(division, (rosterCounts.get(division) || 0) + 1);
  }
  const lostRows = Array.isArray(lost.rows) ? lost.rows : [];
  if (lostRows.length !== 2167) errors.push(`lost rows=${lostRows.length} sheet=2167`);
  const lostByStore = new Map(lostRows.filter((row) => row && typeof row === "object").map((row) => [String(row.store), row]));
  const loss210 = lostByStore.get("210");
  const loss239 = lostByStore.get("239");
  const loss1509 = lostByStore.get("1509");
  if (!loss210 || loss210.division !== "United" || Number((loss210.payload || {}).lost_revenue) !== 263) {
    errors.push(`lost 210=${loss210 && loss210.division},${loss210 && (loss210.payload || {}).lost_revenue}`);
  }
  if (!loss239 || loss239.division !== "Southwest" || Number((loss239.payload || {}).lost_revenue) !== 239) {
    errors.push(`lost 239=${loss239 && loss239.division},${loss239 && (loss239.payload || {}).lost_revenue}`);
  }
  if ((loss210 && loss210.division === "Haggen") || (loss239 && loss239.division === "Haggen")) {
    errors.push("lost 210/239 labeled Haggen");
  }
  const blankGoal = loss1509 && loss1509.payload ? loss1509.payload.lost_revenue_goal_pct : undefined;
  if (blankGoal != null) errors.push(`store 1509 Goal %=${blankGoal}`);
  const lostCounts = new Map();
  for (const row of lostRows) {
    const division = row && row.division;
    if (!division) continue;
    lostCounts.set(division, (lostCounts.get(division) || 0) + 1);
  }
  const haggenRoster = rosterCounts.get("Haggen") || 0;
  if ((lostCounts.get("Haggen") || 0) > haggenRoster + 5) {
    errors.push(`lost Haggen rows=${lostCounts.get("Haggen") || 0} roster=${haggenRoster}`);
  }
  if (lostCounts.size < 8) errors.push(`lost divisions=${[...lostCounts.keys()].sort()}`);
  for (const [division, count] of rosterCounts) {
    if (count < 20) continue;
    if ((lostCounts.get(division) || 0) <= 0) errors.push(`${division} roster ${count} has no lost rows`);
  }

  const markets = new Map(
    (Array.isArray(schedule.markets) ? schedule.markets : [])
      .filter((item) => item && typeof item === "object")
      .map((item) => [item.label, item]),
  );
  const united = markets.get("United") || {};
  if (united.eff != null || united.under != null || united.over != null) {
    errors.push(`United market=${united.under},${united.over},${united.eff}`);
  }
  if (Number(schedule.week || 0) !== 32) errors.push(`week=${schedule.week}`);
  const scheduleStores = Array.isArray(schedule.stores) ? schedule.stores : [];
  if (scheduleStores.length < 2100) errors.push(`schedule stores=${scheduleStores.length}`);
  const bogusUnder = scheduleStores.filter(
    (store) =>
      store &&
      typeof store === "object" &&
      store.under != null &&
      Number(store.under || 0) >= 99.5 &&
      (store.eff == null || Number(store.eff || 0) <= 0),
  );
  if (bogusUnder.length) errors.push(`100% under with invalid eff=${bogusUnder.length}`);
  const scheduleBy = new Map(scheduleStores.filter((item) => item && typeof item === "object").map((item) => [String(item.store), item]));
  for (const store of ["210", "239"]) {
    const row = scheduleBy.get(store) || {};
    const got = [row.division, row.district, row.om];
    if (got.join("\0") !== expected[store].join("\0")) errors.push(`schedule ${store}=${got.join(",")}`);
  }
  const southEff = blend(scheduleStores, markets, "South Region", "eff");
  const southUnder = blend(scheduleStores, markets, "South Region", "under");
  const southOver = blend(scheduleStores, markets, "South Region", "over");
  if (southEff == null || Math.abs(southEff - 91.04) > 0.02) errors.push(`South eff=${southEff}`);
  if (southUnder == null || Math.abs(southUnder - 3.05) > 0.02) errors.push(`South under=${southUnder}`);
  if (southOver == null || Math.abs(southOver - 5.91) > 0.02) errors.push(`South over=${southOver}`);

  for (const name of ["section/missing_items.json", "section/schedule_quality.json"]) {
    const read = readJson(dir, name);
    if (read.error) {
      errors.push(read.error);
      continue;
    }
    const rows = read.value && Array.isArray(read.value.rows) ? read.value.rows : [];
    const raw = rows.find((row) => row && rawDivisionName(row.division));
    if (raw) errors.push(`${name} division ${raw.division} on store ${raw.store}`);
  }

  const dynRows = Array.isArray(dynacap.rows) ? dynacap.rows : [];
  const unitedDyn = dynRows.filter((row) => row && row.division === "United");
  if (unitedDyn.length !== 71) errors.push(`United dynacap rows=${unitedDyn.length}`);
  if (!unitedDyn.some((row) => String(row.store) === "210")) errors.push("United dynacap is missing roster store 210");
  const missingCaps = unitedDyn.filter((row) => {
    const payload = row.payload || {};
    return !("eot_capacity" in payload) || !("used_capacity" in payload);
  });
  if (missingCaps.length) errors.push(`United dynacap missing EOT/Used on ${missingCaps.length} rows`);

  return { errors, roster: roster.length, schedule: scheduleStores.length, lost: lostRows.length, aivTile, southEff };
}

function main() {
  const dir = process.argv[2];
  if (!dir) {
    console.error("usage: node web/check_pack.mjs <dir>");
    process.exit(2);
  }
  const result = checkPack(resolve(dir));
  if (result.errors.length) {
    console.error(`pack schema check failed:\n- ${result.errors.join("\n- ")}`);
    process.exit(1);
  }
  const south = result.southEff == null ? "none" : result.southEff.toFixed(2);
  console.log(
    `pack schema ok stores=${result.roster} schedule=${result.schedule} lost=${result.lost} aiv=${result.aivTile} south_eff=${south} schema=${SCHEMA_VERSION}`,
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
