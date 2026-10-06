// Required-keys check for a cooked web pack directory.
// The Mac push runs this before upload:
//   node web/check_pack.mjs web/public/data
// A failing pack exits non-zero and must not be uploaded.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { SCHEMA_VERSION } from "./public/schema.js";
import { guardHome, PINNED_LIVE_COOK_SHA, rawDivisionName } from "./functions/pack-store.js";

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
  const metadata = value.metadata && typeof value.metadata === "object" ? value.metadata : {};
  const cookedAt = typeof value.cookedAt === "string" ? value.cookedAt : typeof metadata.cookedAt === "string" ? metadata.cookedAt : "";
  return {
    publishedAt: typeof value.publishedAt === "string" ? value.publishedAt : "",
    schemaVersion: value.schemaVersion,
    cookSha: typeof value.cookSha === "string" ? value.cookSha : "",
    cookedAt,
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
    if (stamp && !stamp.cookedAt) {
      const pinned = stamp.cookSha === PINNED_LIVE_COOK_SHA ? " (pinned live cook cannot be republished)" : "";
      errors.push(`${rel} cookedAt missing${pinned}`);
    }
    if (stamp && BANNED_PUBLISHED.some((pattern) => pattern.test(stamp.publishedAt))) {
      errors.push(`${rel} publishedAt ${stamp.publishedAt} is a retired pack`);
    }
    if (stamp && stamp.publishedAt && stamp.schemaVersion === SCHEMA_VERSION && /^[0-9a-f]{40}$/.test(stamp.cookSha)) {
      const key = `${stamp.publishedAt}\0${stamp.schemaVersion}\0${stamp.cookSha}\0${stamp.cookedAt}`;
      if (!expected) expected = key;
      else if (expected !== key) errors.push(`${rel} stamp does not match the rest of the pack`);
    }
  }
  return errors;
}

const MONEY_TEXT = /^\$\d{1,3}(,\d{3})*\.\d{2}$/;

function moneyNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "string" || !value.trim().startsWith("$")) return null;
  const number = Number(value.replace(/[$,\s]/g, ""));
  return Number.isFinite(number) ? number : null;
}

function currencyTextErrors(value, where) {
  if (typeof value !== "string" || !value.includes("$")) return [];
  const text = value.trim();
  if (!text.startsWith("$")) return [];
  return MONEY_TEXT.test(text) ? [] : [`${where} currency ${text}`];
}

export function currencyPrecisionErrors(home) {
  const errors = [];
  const tiles = home && home.companyTiles && typeof home.companyTiles === "object" ? home.companyTiles : {};
  for (const [section, block] of Object.entries(tiles)) {
    const values = block && Array.isArray(block.values) ? block.values : [];
    values.forEach((value, index) => errors.push(...currencyTextErrors(value, `${section} tile ${index}`)));
  }
  for (const line of Array.isArray(home && home.regionLines) ? home.regionLines : []) {
    errors.push(...currencyTextErrors(line && line.value, `${line && line.section} ${line && line.region}`));
    for (const child of (line && line.children) || []) {
      errors.push(...currencyTextErrors(child && child.value, `${line.section} ${child && child.division}`));
    }
  }
  for (const row of Array.isArray(home && home.regionTables) ? home.regionTables : []) {
    errors.push(...currencyTextErrors(row && row.headline, `${row && row.section} ${row && row.region} headline`));
  }
  return errors;
}

export function lostRollupErrors(home, lost) {
  const errors = [];
  const lines = (Array.isArray(home && home.regionLines) ? home.regionLines : []).filter(
    (line) => line && line.section === "lost_revenue",
  );
  const regions = ["East", "South", "California", "West"];
  let excl = 0;
  let counts = 0;
  for (const name of regions) {
    const line = lines.find((item) => item.region === name);
    if (!line) {
      errors.push(`lost region ${name} missing`);
      continue;
    }
    if (line.title !== "Lost $ excl. Missed") errors.push(`lost ${name} title=${line.title}`);
    if (line.missed !== "Not available") errors.push(`lost ${name} missed=${line.missed}`);
    for (const child of line.children || []) {
      if (child.missed !== "Not available") errors.push(`lost ${name} ${child.division} missed=${child.missed}`);
    }
    const value = moneyNumber(line.value);
    if (value == null) errors.push(`lost ${name} value=${line.value}`);
    else excl += value;
    counts += Number(line.count) || 0;
  }
  const rows = lost && Array.isArray(lost.rows) ? lost.rows : [];
  if (counts !== rows.length) errors.push(`lost region stores=${counts} rows=${rows.length}`);
  const tiles = home && home.companyTiles && home.companyTiles.lost_revenue ? home.companyTiles.lost_revenue : {};
  const labels = Array.isArray(tiles.labels) ? tiles.labels : [];
  const values = Array.isArray(tiles.values) ? tiles.values : [];
  const tile = (name) => (labels.includes(name) ? values[labels.indexOf(name)] : null);
  const companyLost = moneyNumber(tile("Lost $"));
  const companyMissed = moneyNumber(tile("Missed"));
  if (companyLost == null || companyMissed == null) errors.push(`company lost tiles Lost=${tile("Lost $")} Missed=${tile("Missed")}`);
  else if (Math.abs(excl + companyMissed - companyLost) > 20) {
    errors.push(`lost rollup excl=${excl} missed=${companyMissed} company=${companyLost}`);
  }
  return errors;
}

export function storeCountErrors(home, files) {
  const errors = [];
  const summaries = new Map(
    (Array.isArray(home && home.summaries) ? home.summaries : [])
      .filter((item) => item && typeof item === "object")
      .map((item) => [item.section, item]),
  );
  for (const section of ["lost_revenue", "missing_items", "five_star", "pre_sub_oos"]) {
    const summary = summaries.get(section) || {};
    const file = files && files[section];
    const rows = file && Array.isArray(file.rows) ? file.rows : null;
    if (!rows) {
      errors.push(`${section} rows missing`);
      continue;
    }
    if (Number(summary.storeCount) !== rows.length) {
      errors.push(`${section} storeCount=${summary.storeCount} rows=${rows.length}`);
    }
  }
  const company = home && home.pickerRollups && home.pickerRollups.company;
  const picker = files && files.picker_scorecard && Array.isArray(files.picker_scorecard.rows) ? files.picker_scorecard.rows : null;
  if (!picker) {
    errors.push("picker rows missing");
  } else {
    const unique = new Set(picker.map((row) => row && row.store).filter(Boolean));
    const stores = company ? Number(company.stores) : NaN;
    if (stores !== unique.size) errors.push(`picker stores=${company && company.stores} unique=${unique.size}`);
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
  // section/lost_revenue required key. missed_sales is Capacity Reduction (Total Opportunity).
  // A blank cell stays absent. reduced_capacity is not a substitute.
  const LOST_REVENUE_REQUIRED = ["missed_sales"];
  if (!LOST_REVENUE_REQUIRED.includes("missed_sales")) errors.push("lost_revenue required keys dropped missed_sales");
  if (lostTile("Missed") !== "$420,030.87") errors.push(`Missed=${lostTile("Missed")}`);

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
  let missedCount = 0;
  for (const row of lostRows) {
    const payload = row && row.payload;
    if (payload && Object.prototype.hasOwnProperty.call(payload, "missed_sales")) missedCount += 1;
  }
  if (missedCount !== 154) errors.push(`lost missed_sales=${missedCount} required ${LOST_REVENUE_REQUIRED.join(",")}`);
  const loss6 = lostByStore.get("6");
  const missed6 = loss6 && loss6.payload ? loss6.payload.missed_sales : undefined;
  if (missed6 == null || Math.abs(Number(missed6) - 2687.8666987759993) > 1e-6) {
    errors.push(`store 6 missed_sales=${missed6}`);
  }
  if (loss6 && loss6.payload && Number(loss6.payload.reduced_capacity) === Number(missed6)) {
    errors.push("store 6 missed_sales copied from reduced_capacity");
  }
  for (const store of ["1", "210", "239", "1509"]) {
    const row = lostByStore.get(store);
    const payload = row && row.payload;
    if (payload && Object.prototype.hasOwnProperty.call(payload, "missed_sales")) {
      errors.push(`store ${store} missed_sales should be absent`);
    }
  }
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
    const got = [row.region, row.division, row.district, row.om];
    const want = ["South Region", ...expected[store]];
    if (got.join("\0") !== want.join("\0")) errors.push(`schedule ${store}=${got.join(",")}`);
  }
  const southEff = blend(scheduleStores, markets, "South Region", "eff");
  const southUnder = blend(scheduleStores, markets, "South Region", "under");
  const southOver = blend(scheduleStores, markets, "South Region", "over");
  if (southEff == null || Math.abs(southEff - 91.04) > 0.02) errors.push(`South eff=${southEff}`);
  if (southUnder == null || Math.abs(southUnder - 3.05) > 0.02) errors.push(`South under=${southUnder}`);
  if (southOver == null || Math.abs(southOver - 5.91) > 0.02) errors.push(`South over=${southOver}`);

  errors.push(...lostRollupErrors(home, lost));
  errors.push(...currencyPrecisionErrors(home));
  const counted = {};
  for (const section of ["lost_revenue", "missing_items", "five_star", "pre_sub_oos", "picker_scorecard"]) {
    const read = section === "lost_revenue" ? lostRead : readJson(dir, `section/${section}.json`);
    counted[section] = read.value && typeof read.value === "object" ? read.value : null;
    if (read.error && section !== "lost_revenue") errors.push(read.error);
  }
  errors.push(...storeCountErrors(home, counted));

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

export function cookedAtPublishErrors(dir) {
  const errors = packIdentityErrors(dir);
  const missing = errors.filter((item) => item.includes("cookedAt missing"));
  if (missing.length) return missing;
  if (errors.some((item) => item.includes("no json") || item.includes("pack directory is missing"))) return errors;
  return [];
}

function main() {
  const args = process.argv.slice(2);
  const cookedOnly = args[0] === "--cooked-at";
  const dir = cookedOnly ? args[1] : args[0];
  if (!dir) {
    console.error("usage: node web/check_pack.mjs [--cooked-at] <dir>");
    process.exit(2);
  }
  if (cookedOnly) {
    const missing = cookedAtPublishErrors(resolve(dir));
    if (missing.length) {
      console.error(`refusing publish: cookedAt is missing\n- ${missing.join("\n- ")}`);
      process.exit(1);
    }
    console.log("cookedAt present");
    return;
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
