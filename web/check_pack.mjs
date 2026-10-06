// Required-keys check for a cooked web pack directory.
// The Mac push runs this before upload:
//   node web/check_pack.mjs web/public/data
// A failing pack exits non-zero and must not be uploaded.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { SCHEMA_VERSION, WORKBOOK_TOTAL_FIELDS } from "./public/schema.js";
import { guardHome, PACK_FILES, PINNED_LIVE_COOK_SHA, rawDivisionName } from "./functions/pack-store.js";

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

function bridgePart(value) {
  if (value == null || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

// The census is this pack's own Labor rows whose four bridge parts add up.
// An absent AIV or wage is zero: the 42 AIV-zero rows still bridge
// (UPLH + 0 + 0 = Target vs Actual). The pinned file has 2,109 rows with all
// four parts present and 42 more once that zero is filled in. Keeping
// two-digit store IDs (include: nil) adds 18 stores and bridges 2,127 of the
// complete rows. A fixed 2,109 rejects that cook. A complete row that does
// not add up still fails, and a labor file with no bridged row fails closed.
// When the store-roster count is passed, also refuse a bridged count under
// 2,000 or under that roster minus 60.
export function laborBridgeCensus(rows, rosterCount) {
  const list = Array.isArray(rows) ? rows : [];
  const errors = [];
  let bridged = 0;
  for (const row of list) {
    const payload = (row && row.payload) || {};
    const uplh = bridgePart(payload.uplh_impact_pct);
    const wage = bridgePart(payload.wage_impact_pct);
    const aiv = bridgePart(payload.aiv_impact_pct);
    const target = bridgePart(payload.target_vs_actual_pct);
    if (uplh != null && wage != null && aiv != null && target != null) {
      if (Math.abs(uplh + wage + aiv - target) > 0.01) {
        errors.push(`labor bridge ${row && row.store}`);
        continue;
      }
      bridged += 1;
      continue;
    }
    if (uplh == null || target == null) continue;
    if (Math.abs(uplh + (wage ?? 0) + (aiv ?? 0) - target) <= 0.01) bridged += 1;
  }
  if (list.length > 0 && bridged === 0) errors.push(`labor bridge rows=${bridged}`);
  else if (rosterCount != null && Number.isFinite(Number(rosterCount))) {
    const roster = Number(rosterCount);
    if (bridged < 2000 || bridged < roster - 60) errors.push(`labor bridge rows=${bridged}`);
  }
  return { bridged, errors };
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
  const present = new Set(files);
  for (const rel of PACK_FILES) {
    if (!present.has(rel)) errors.push(`${rel} is missing`);
  }
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

export function workbookTotalErrors(home) {
  const metadata = home && home.metadata && typeof home.metadata === "object" ? home.metadata : {};
  const cooked =
    (home && typeof home.cookedAt === "string" && home.cookedAt) ||
    (typeof metadata.cookedAt === "string" && metadata.cookedAt) ||
    "";
  if (!cooked) return [];
  const block = home && home.workbookTotal;
  if (!block || typeof block !== "object" || Array.isArray(block)) return ["workbookTotal missing"];
  const errors = [];
  for (const [section, fields] of Object.entries(WORKBOOK_TOTAL_FIELDS)) {
    const row = block[section];
    if (!row || typeof row !== "object" || Array.isArray(row)) {
      errors.push(`workbookTotal ${section} missing`);
      continue;
    }
    for (const field of fields) {
      const value = row[field];
      if (typeof value !== "number" || !Number.isFinite(value)) errors.push(`workbookTotal ${section}.${field} missing`);
    }
  }
  return errors;
}

const REGION_NAMES = ["East", "South", "California", "West"];
const DIVISION_REGION = {
  Shaws: "East",
  "Mid-Atlantic": "East",
  "Jewel Osco": "East",
  Southern: "South",
  United: "South",
  Southwest: "South",
  NorCal: "California",
  SoCal: "California",
  "Mountain West": "West",
  Seattle: "West",
  Haggen: "West",
  Portland: "West",
};
const DIVISION_ALIAS = {
  midatlantic: "Mid-Atlantic",
  jewel: "Jewel Osco",
  jewelosco: "Jewel Osco",
  nocal: "NorCal",
  northerncalifornia: "NorCal",
  norcalifornia: "NorCal",
  southerncalifornia: "SoCal",
  socalifornia: "SoCal",
  southerncal: "SoCal",
  mountainwest: "Mountain West",
  denver: "Mountain West",
  intermountain: "Mountain West",
  unitedtexas: "United",
  unitedsupermarkets: "United",
};

function canonicalDivision(raw) {
  const text = String(raw || "").trim();
  if (!text) return "";
  if (DIVISION_REGION[text]) return text;
  const key = text.toLowerCase().replace(/[^a-z0-9]/g, "");
  if (key.startsWith("united")) return "United";
  return DIVISION_ALIAS[key] || text;
}

function regionOfDivision(raw) {
  return DIVISION_REGION[canonicalDivision(raw)] || "";
}

function tileText(home, section, label) {
  const block = home && home.companyTiles && home.companyTiles[section];
  const labels = block && Array.isArray(block.labels) ? block.labels : [];
  const values = block && Array.isArray(block.values) ? block.values : [];
  const index = labels.indexOf(label);
  return index >= 0 ? values[index] : null;
}

function countNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "string") return null;
  const number = Number(value.replace(/,/g, "").trim());
  return Number.isFinite(number) ? number : null;
}

function percentNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "string") return null;
  const number = Number(value.trim().replace("%", ""));
  return Number.isFinite(number) ? number : null;
}

function closeCents(left, right) {
  return left != null && right != null && Math.abs(left - right) <= 0.02;
}

function payloadSum(rows, key) {
  let total = 0;
  for (const row of rows) {
    const payload = row && row.payload;
    if (!payload || payload[key] == null || payload[key] === "") continue;
    const number = Number(payload[key]);
    if (Number.isFinite(number)) total += number;
  }
  return total;
}

function laborNumber(payload, key) {
  if (!payload || !Object.prototype.hasOwnProperty.call(payload, key)) return null;
  const raw = payload[key];
  if (raw == null || (typeof raw === "string" && !String(raw).trim())) return null;
  const number = Number(raw);
  return Number.isFinite(number) ? number : null;
}

// Same predicates as the cook's Labor source check. The count is a structural
// band, not an Oct 5 total. A blank stays null; a real 0 still counts.
export function laborSourceFlag(row) {
  const payload = (row && row.payload) || {};
  const weight = laborNumber(payload, "weight");
  if (weight == null || weight === 0) return true;
  const act = laborNumber(payload, "act_cost_pct");
  if (act == null || act === 0 || act > 100) return true;
  const cost = laborNumber(payload, "cost_trgt_pct");
  if (cost == null || cost > 100) return true;
  const target = laborNumber(payload, "target_vs_actual_pct");
  if (target != null && target > 100) return true;
  return false;
}

// Company tiles follow this pack. Workbook Total cells win when the cook
// stored them. Otherwise the tile has to match a recomputation from the
// store rows, to the cent or the displayed percent. Lost rows use the roster
// floor (roster - 60). Missed-filled rows have to stay above zero.
export function packValueErrors(home, salesFile, lostFile) {
  const errors = [];
  const salesRows = salesFile && Array.isArray(salesFile.rows) ? salesFile.rows : [];
  const lostRows = lostFile && Array.isArray(lostFile.rows) ? lostFile.rows : [];
  const roster = home && home.filters && Array.isArray(home.filters.stores) ? home.filters.stores : [];
  const salesDollars = payloadSum(salesRows, "sales_dollars");
  const orders = payloadSum(salesRows, "sales_orders");
  const items = payloadSum(salesRows, "sales_items");
  const salesTile = moneyNumber(tileText(home, "sales", "Sales $"));
  const ordersTile = countNumber(tileText(home, "sales", "Orders"));
  const itemsTile = countNumber(tileText(home, "sales", "Items"));
  if (!closeCents(salesTile, salesDollars)) errors.push(`Sales $ tile=${salesTile} rows=${salesDollars}`);
  if (ordersTile == null || Math.abs(ordersTile - orders) > 0.5) errors.push(`Orders tile=${ordersTile} rows=${orders}`);
  if (itemsTile == null || Math.abs(itemsTile - items) > 0.5) errors.push(`Items tile=${itemsTile} rows=${items}`);
  const workbookSales = home && home.workbookTotal && home.workbookTotal.sales;
  if (workbookSales && typeof workbookSales.sales_dollars === "number" && !closeCents(salesTile, workbookSales.sales_dollars)) {
    errors.push(`Sales $ tile=${salesTile} workbook=${workbookSales.sales_dollars}`);
  }

  const salesLines = (Array.isArray(home && home.regionLines) ? home.regionLines : []).filter(
    (line) => line && line.section === "sales",
  );
  for (const name of REGION_NAMES) {
    if (!salesLines.some((line) => line.region === name)) errors.push(`sales region ${name} missing`);
  }
  let regionDollars = 0;
  let noDivisionZero = 0;
  let noDivisionOther = 0;
  for (const row of salesRows) {
    const payload = row && row.payload;
    if (!payload || payload.sales_dollars == null || payload.sales_dollars === "") continue;
    const dollars = Number(payload.sales_dollars);
    if (!Number.isFinite(dollars)) continue;
    const region = regionOfDivision(row.division);
    if (!region) {
      if (Math.abs(dollars) <= 0.005) noDivisionZero += dollars;
      else noDivisionOther += dollars;
      continue;
    }
    regionDollars += dollars;
  }
  if (Math.abs(noDivisionOther) > 0.02) errors.push(`sales no-division dollars=${noDivisionOther}`);
  if (salesTile != null && !closeCents(regionDollars, salesTile - noDivisionZero)) {
    errors.push(`sales regions=${regionDollars} company=${salesTile} nodiv=${noDivisionZero}`);
  }

  if (roster.length && lostRows.length < roster.length - 60) {
    errors.push(`lost rows=${lostRows.length} floor=${roster.length - 60}`);
  }
  let missedFilled = 0;
  for (const row of lostRows) {
    const payload = row && row.payload;
    if (!payload || !Object.prototype.hasOwnProperty.call(payload, "missed_sales")) continue;
    const missed = payload.missed_sales;
    if (missed == null || missed === "") continue;
    const number = Number(missed);
    if (Number.isFinite(number) && number !== 0) missedFilled += 1;
  }
  if (missedFilled <= 0) errors.push(`lost missed_sales collapsed=${missedFilled}`);

  const lostTile = moneyNumber(tileText(home, "lost_revenue", "Lost $"));
  const missedTile = moneyNumber(tileText(home, "lost_revenue", "Missed"));
  const lostPctTile = percentNumber(tileText(home, "lost_revenue", "Lost %"));
  const goalPctTile = percentNumber(tileText(home, "lost_revenue", "Goal %"));
  const storeLost = payloadSum(lostRows, "lost_revenue");
  const storeMissed = payloadSum(lostRows, "missed_sales");
  const storeEcomm = payloadSum(lostRows, "ecomm_sales");
  const storeGoal = payloadSum(lostRows, "lost_revenue_goal");
  const storeGoalPct = storeEcomm > 0 ? (storeGoal / storeEcomm) * 100 : null;
  const workbookLost = home && home.workbookTotal && home.workbookTotal.lost_revenue;
  const workbookLostDollars = workbookLost && typeof workbookLost.lost_dollars === "number" ? workbookLost.lost_dollars : null;
  const workbookMissed = workbookLost && typeof workbookLost.missed_dollars === "number" ? workbookLost.missed_dollars : null;
  const workbookEcomm = workbookLost && typeof workbookLost.ecomm_dollars === "number" ? workbookLost.ecomm_dollars : null;
  // Without a workbook Total, the pinned tiles are the market total and do not
  // equal the store-row sum. A cooked pack has the Total cells and must match them.
  if (workbookLostDollars != null) {
    if (!closeCents(lostTile, workbookLostDollars)) errors.push(`Lost $ tile=${lostTile} workbook=${workbookLostDollars}`);
  } else if (!(lostTile > 0) && !closeCents(lostTile, storeLost)) {
    errors.push(`Lost $ tile=${lostTile} rows=${storeLost}`);
  }
  if (workbookMissed != null) {
    if (!closeCents(missedTile, workbookMissed)) errors.push(`Missed tile=${missedTile} workbook=${workbookMissed}`);
  } else if (!(missedTile > 0) && !closeCents(missedTile, storeMissed)) {
    errors.push(`Missed tile=${missedTile} rows=${storeMissed}`);
  }
  const workbookPct = workbookEcomm ? (workbookLostDollars / workbookEcomm) * 100 : null;
  const ecommTile = moneyNumber(tileText(home, "lost_revenue", "eComm $"));
  const impliedPct = ecommTile && lostTile != null ? (lostTile / ecommTile) * 100 : null;
  const storeLostPct = storeEcomm > 0 ? (storeLost / storeEcomm) * 100 : null;
  if (workbookPct != null) {
    if (lostPctTile == null || Math.abs(lostPctTile - workbookPct) > 0.02) {
      errors.push(`Lost % tile=${lostPctTile} workbook=${workbookPct}`);
    }
  } else {
    const matchesTiles = impliedPct != null && lostPctTile != null && Math.abs(lostPctTile - impliedPct) <= 0.02;
    const matchesRows = storeLostPct != null && lostPctTile != null && Math.abs(lostPctTile - storeLostPct) <= 0.02;
    if (!matchesTiles && !matchesRows) errors.push(`Lost % tile=${lostPctTile} rows=${storeLostPct}`);
  }
  // Loss Revenue Total column G is the goal rate. 0.035466 is 3.5466%, which prints as 3.55.
  // Column F is goal dollars. F / eComm should match G. Store-row goal/ecomm is only
  // the fallback when this pack has no workbook goal rate.
  const workbookGoalRaw =
    workbookLost && typeof workbookLost.goal_pct === "number"
      ? workbookLost.goal_pct
      : workbookLost && typeof workbookLost.lost_revenue_goal_pct === "number"
        ? workbookLost.lost_revenue_goal_pct
        : null;
  const workbookGoal = workbookGoalRaw == null ? null : Math.abs(workbookGoalRaw) <= 1.5 ? workbookGoalRaw * 100 : workbookGoalRaw;
  if (workbookGoal != null) {
    if (goalPctTile == null || Math.abs(goalPctTile - workbookGoal) > 0.02) {
      errors.push(`Goal % tile=${goalPctTile} workbook=${workbookGoal}`);
    }
  } else if (goalPctTile == null || storeGoalPct == null || Math.abs(goalPctTile - storeGoalPct) > 1) {
    errors.push(`Goal % tile=${goalPctTile} rows=${storeGoalPct}`);
  }
  const goalDollars = workbookLost && typeof workbookLost.goal_dollars === "number" ? workbookLost.goal_dollars : null;
  if (goalDollars != null && workbookEcomm && workbookGoalRaw != null) {
    const fraction = Math.abs(workbookGoalRaw) <= 1.5 ? workbookGoalRaw : workbookGoalRaw / 100;
    if (Math.abs(goalDollars / workbookEcomm - fraction) > 0.0005) {
      errors.push(`Goal dollars=${goalDollars} ecomm=${workbookEcomm} rate=${fraction}`);
    }
  }
  if (missedTile != null && missedTile <= 0) errors.push(`Missed tile collapsed=${missedTile}`);
  return errors;
}

function scheduleWeekNumbers(text) {
  const found = [];
  const source = String(text || "");
  for (const match of source.matchAll(/WK\s*(\d+)/gi)) found.push(Number(match[1]));
  for (const match of source.matchAll(/Week\s+(\d+)/gi)) found.push(Number(match[1]));
  return found;
}

function scheduleMarketBlend(stores, markets, field) {
  const divisions = new Set(stores.map((store) => store && store.division).filter(Boolean));
  let weight = 0;
  let total = 0;
  for (const division of divisions) {
    const market = markets.get(division) || {};
    const value = market[field];
    if (value == null || value === "") continue;
    const number = Number(value);
    if (!Number.isFinite(number)) continue;
    const count = stores.filter((store) => store && store.division === division).length;
    if (!count) continue;
    weight += count;
    total += number * count;
  }
  return weight ? total / weight : null;
}

// Week comes from the schedule filename or the Summary tab title, not a pinned WK32.
// Company Sch Eff / Under / Over are the store-weighted division markets, and they
// have to match the Summary Total row. United's blank market stays out of that blend.
export function scheduleValueErrors(schedule, rosterCount) {
  const errors = [];
  const week = Number(schedule && schedule.week);
  const named = [...scheduleWeekNumbers(schedule && schedule.filename), ...scheduleWeekNumbers(schedule && schedule.summaryTitle)];
  if (!named.length || !Number.isFinite(week) || named.some((item) => item !== week)) {
    errors.push(`week=${schedule && schedule.week} name=${schedule && schedule.filename} title=${schedule && schedule.summaryTitle}`);
  }
  const stores = schedule && Array.isArray(schedule.stores) ? schedule.stores : [];
  const roster = Number(rosterCount);
  if (Number.isFinite(roster) && roster > 60 && stores.length < roster - 60) {
    errors.push(`schedule stores=${stores.length} floor=${roster - 60}`);
  }
  for (const name of ["East Region", "South Region", "California Region", "West Region"]) {
    if (!stores.some((store) => store && store.region === name)) errors.push(`schedule region ${name} missing`);
  }
  const markets = new Map(
    (Array.isArray(schedule && schedule.markets) ? schedule.markets : [])
      .filter((item) => item && typeof item === "object")
      .map((item) => [item.label, item]),
  );
  const summary = markets.get("Total") || {};
  const labels = { eff: "Sch Eff", under: "Under", over: "Over" };
  for (const field of ["eff", "under", "over"]) {
    const company = scheduleMarketBlend(stores, markets, field);
    const total = summary[field] == null || summary[field] === "" ? null : Number(summary[field]);
    const totalOk = total != null && Number.isFinite(total);
    if (company == null || !totalOk || Math.abs(company - total) > 1) {
      errors.push(`${labels[field]} company=${company} total=${total}`);
    } else if (total < 0 || total > 100) {
      errors.push(`${labels[field]} out of range=${total}`);
    }
  }
  return errors;
}

// Oct 5 store, schedule, and labor pins. A later cook must not have to match these.
// Callers run it only on that pack.
export function octoberStoreFixture(home, lost, schedule, laborFile) {
  const sha = (home && home.metadata && home.metadata.cookSha) || (home && home.cookSha) || "";
  if (sha !== PINNED_LIVE_COOK_SHA) return ["october fixture runs only on the pinned Oct 5 pack"];
  const errors = [];
  const roster = home && home.filters && Array.isArray(home.filters.stores) ? home.filters.stores : [];
  const byStore = new Map(roster.filter((item) => item && typeof item === "object").map((item) => [String(item.store), item]));
  const expected = {
    210: ["United", "U5", "Andrew Quinn"],
    239: ["Southwest", "N0", "Ben Sarmadi"],
  };
  for (const [store, ident] of Object.entries(expected)) {
    const row = byStore.get(store) || {};
    const got = [row.division, row.district, row.om];
    if (got.join("\0") !== ident.join("\0")) errors.push(`roster ${store}=${got.join(",")}`);
  }
  const lostRows = lost && Array.isArray(lost.rows) ? lost.rows : [];
  const lostByStore = new Map(lostRows.filter((row) => row && typeof row === "object").map((row) => [String(row.store), row]));
  const loss210 = lostByStore.get("210");
  const loss239 = lostByStore.get("239");
  if (!loss210 || loss210.division !== "United" || Number((loss210.payload || {}).lost_revenue) !== 263) {
    errors.push(`lost 210=${loss210 && loss210.division},${loss210 && (loss210.payload || {}).lost_revenue}`);
  }
  if (!loss239 || loss239.division !== "Southwest" || Number((loss239.payload || {}).lost_revenue) !== 239) {
    errors.push(`lost 239=${loss239 && loss239.division},${loss239 && (loss239.payload || {}).lost_revenue}`);
  }
  const loss6 = lostByStore.get("6");
  const missed6 = loss6 && loss6.payload ? loss6.payload.missed_sales : undefined;
  if (missed6 == null || Math.abs(Number(missed6) - 2687.8666987759993) > 1e-6) {
    errors.push(`store 6 missed_sales=${missed6}`);
  }
  if (loss6 && loss6.payload && Number(loss6.payload.reduced_capacity) === Number(missed6)) {
    errors.push("store 6 missed_sales copied from reduced_capacity");
  }
  for (const store of ["210", "239"]) {
    const row = lostByStore.get(store);
    const payload = row && row.payload;
    if (payload && Object.prototype.hasOwnProperty.call(payload, "missed_sales")) {
      errors.push(`store ${store} missed_sales should be absent`);
    }
  }
  const scheduleStores = schedule && Array.isArray(schedule.stores) ? schedule.stores : [];
  const scheduleBy = new Map(scheduleStores.filter((item) => item && typeof item === "object").map((item) => [String(item.store), item]));
  for (const store of ["210", "239"]) {
    const row = scheduleBy.get(store) || {};
    const got = [row.region, row.division, row.district, row.om];
    const want = ["South Region", ...expected[store]];
    if (got.join("\0") !== want.join("\0")) errors.push(`schedule ${store}=${got.join(",")}`);
  }
  const rosterExpected = {
    233: ["Seattle", "28", "Ryan Burns"],
    339: ["Mountain West", "I5", "Chris Banuelos"],
    879: ["Mountain West", "66", "Ellas Ware"],
    1509: ["Mountain West", "I5", "Chris Banuelos"],
    4799: ["Jewel Osco", "J6", "Mike Macdonald"],
  };
  for (const [store, ident] of Object.entries(rosterExpected)) {
    const row = byStore.get(store) || {};
    const got = [row.division, row.district, row.om];
    if (got.join("\0") !== ident.join("\0")) errors.push(`roster ${store}=${got.join(",")}`);
  }
  if (Number(schedule && schedule.week) !== 32) errors.push(`week=${schedule && schedule.week}`);
  const fixtureMarkets = new Map(
    (Array.isArray(schedule && schedule.markets) ? schedule.markets : [])
      .filter((item) => item && typeof item === "object")
      .map((item) => [item.label, item]),
  );
  const southEff = blend(scheduleStores, fixtureMarkets, "South Region", "eff");
  const southUnder = blend(scheduleStores, fixtureMarkets, "South Region", "under");
  const southOver = blend(scheduleStores, fixtureMarkets, "South Region", "over");
  if (southEff == null || Math.abs(southEff - 91.04) > 0.02) errors.push(`South eff=${southEff}`);
  if (southUnder == null || Math.abs(southUnder - 3.05) > 0.02) errors.push(`South under=${southUnder}`);
  if (southOver == null || Math.abs(southOver - 5.91) > 0.02) errors.push(`South over=${southOver}`);
  const laborRows = laborFile && Array.isArray(laborFile.rows) ? laborFile.rows : [];
  const flagged = new Set(
    laborRows.filter((row) => row && row.sourceIssue === "source data issue").map((row) => String(row.store)),
  );
  for (const store of ["233", "4799", "1509"]) {
    if (!flagged.has(store)) errors.push(`missing source data issue ${store}`);
  }
  const plain = laborRows.find((row) => String(row.store) === "1");
  const plainAiv = finite((plain && plain.payload && plain.payload.aiv_impact_pct) ?? null);
  if (!plain || plain.sourceIssue || plainAiv == null || Math.abs(plainAiv - -0.38645958215580284) > 1e-6) {
    errors.push("store 1 AIV changed");
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
  errors.push(...workbookTotalErrors(homeRead.value));

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
  const storeRoster = home.filters && Array.isArray(home.filters.stores) ? home.filters.stores : [];
  errors.push(...laborBridgeCensus(laborRows, storeRoster.length).errors);

  const laborFlags = laborRows.filter(laborSourceFlag).length;
  if (laborFlags < 40 || laborFlags > 80) errors.push(`labor flagged=${laborFlags}`);
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

  // missed_sales is Capacity Reduction. A blank cell stays absent. It is not written as 0,
  // and reduced_capacity is not a substitute. The Oct 5 store 6 dollar pin lives in octoberStoreFixture.
  const salesRead = readJson(dir, "section/sales.json");
  if (salesRead.error) errors.push(salesRead.error);
  const salesFile = salesRead.value && typeof salesRead.value === "object" ? salesRead.value : {};
  errors.push(...packValueErrors(home, salesFile, lost));

  const summaries = new Map((Array.isArray(home.summaries) ? home.summaries : []).filter((item) => item && typeof item === "object").map((item) => [item.section, item]));
  const pph = summaries.get("pph") || {};
  if (!String(pph.secondary || "").includes("between 74 and 80")) errors.push(`pph secondary=${pph.secondary}`);
  if (pph.health === "risk") errors.push("pph health is risk at a 74+ average");

  const roster = storeRoster;
  const rosterCounts = new Map();
  for (const item of roster) {
    const division = item && item.division;
    if (!division) continue;
    rosterCounts.set(division, (rosterCounts.get(division) || 0) + 1);
  }
  const lostRows = Array.isArray(lost.rows) ? lost.rows : [];
  const lostByStore = new Map(lostRows.filter((row) => row && typeof row === "object").map((row) => [String(row.store), row]));
  const loss210 = lostByStore.get("210");
  const loss239 = lostByStore.get("239");
  const loss1509 = lostByStore.get("1509");
  if ((loss210 && loss210.division === "Haggen") || (loss239 && loss239.division === "Haggen")) {
    errors.push("lost 210/239 labeled Haggen");
  }
  const blankGoal = loss1509 && loss1509.payload ? loss1509.payload.lost_revenue_goal_pct : undefined;
  if (blankGoal != null) errors.push(`store 1509 Goal %=${blankGoal}`);
  for (const store of ["1", "1509"]) {
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
  const scheduleStores = Array.isArray(schedule.stores) ? schedule.stores : [];
  errors.push(...scheduleValueErrors(schedule, roster.length));
  const bogusUnder = scheduleStores.filter(
    (store) =>
      store &&
      typeof store === "object" &&
      store.under != null &&
      Number(store.under || 0) >= 99.5 &&
      (store.eff == null || Number(store.eff || 0) <= 0),
  );
  if (bogusUnder.length) errors.push(`100% under with invalid eff=${bogusUnder.length}`);
  const southEff = blend(scheduleStores, markets, "South Region", "eff");

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
