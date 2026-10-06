// Filter seat for scorecards.
// Company (no filter) keeps the cooked chrome headline. That figure is not a
// store average — Sales and Loss dollars are the workbook company tiles.
// Labor at region scope uses the regionTables callout, the same figure as the card.
// Lost revenue below company is Lost $ excl. Missed from this section's rows.
// Other region and division seats use the cooked chrome line for the metric.
// Their store counts, and every picker shopper count, come from section rows.
// Picker shoppers are distinct shopperId values in scope.
// District, OM, and Store rebuild from fact rows in scope. They never keep
// the company number. A missing rate stays blank.

import { formatHeadline, pct } from "./clock.js";
import { canonicalDivision, filtersActive, includesScope, matchesDivision, regionForDivision, regionLineInScope } from "./filters.js";

// Averages and shares of the rows on screen. Dynacap, PPH, and 5 Star use
// the company-figure precision. Percent metrics use two decimals.
const ROW_RATE_SECTIONS = new Set([
  "missing_items",
  "five_star",
  "pre_sub_oos",
  "pick_path",
  "prep_not_ready",
  "dynacap",
  "schedule_quality",
  "pph",
]);

export function shownRate(section, value) {
  if (value == null || value === "" || !Number.isFinite(Number(value))) return "—";
  if (
    section === "five_star" ||
    section === "pph" ||
    section === "dynacap" ||
    section === "picker_scorecard" ||
    section === "sales" ||
    section === "lost_revenue" ||
    section === "labor"
  ) {
    return formatHeadline(section, value);
  }
  return pct(value);
}

export function formatCompanyAiv(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "—";
  return `${number.toFixed(2)}%`;
}

function field(row, keys) {
  const payload = (row && row.payload) || {};
  for (const key of keys) {
    if (payload[key] == null || payload[key] === "") continue;
    const number = Number(payload[key]);
    if (!Number.isNaN(number)) return number;
  }
  return null;
}

function average(values) {
  if (!values.length) return null;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function band(value, good, watch, invert = false) {
  if (value == null || Number.isNaN(Number(value))) return "none";
  if (invert) {
    if (value <= good) return "good";
    if (value <= watch) return "watch";
    return "risk";
  }
  if (value >= good) return "good";
  if (value >= watch) return "watch";
  return "risk";
}

// One badge rule for every scope. The badge uses the same headline the card
// shows. One store or one shopper does not flip the scope.
// sales: YoY above 0 is healthy, down to -3 is watch.
// five_star: 4.00 is a passing rating. Healthy does not require 5.00.
// schedule_quality: schedule efficiency. A single store over 5% does not flip it.
// labor: lower is better. Company uses the workbook Total (-4.06), not the unweighted store mean.
// picker_scorecard: mean shopper PPH versus 80 / 74. One opportunity shopper does not flip it.
export const SCOPE_BADGES = {
  sales: { good: 0, watch: -3, invert: false },
  lost_revenue: { good: 3, watch: 5, invert: true },
  missing_items: { good: 5, watch: 6.5, invert: true },
  pre_sub_oos: { good: 5, watch: 6.5, invert: true },
  five_star: { good: 4, watch: 3.5, invert: false },
  pick_path: { good: 90, watch: 80, invert: false },
  prep_not_ready: { good: 1.9, watch: 2.5, invert: true },
  dynacap: { good: 65, watch: 60, invert: false },
  schedule_quality: { good: 90, watch: 85, invert: false },
  pph: { good: 80, watch: 74, invert: false },
  labor: { good: 0, watch: 3, invert: true },
  picker_scorecard: { good: 80, watch: 74, invert: false },
};

export function scopeHealth(section, headline) {
  const rule = SCOPE_BADGES[section];
  if (!rule || headline == null || !Number.isFinite(Number(headline))) return "none";
  return band(Number(headline), rule.good, rule.watch, Boolean(rule.invert));
}

export function pickerScopeHealth(rows) {
  const values = [];
  for (const row of rows || []) {
    const value = field(row, ["pph"]);
    if (value != null) values.push(value);
  }
  return scopeHealth("picker_scorecard", average(values));
}

function empty(secondary) {
  return { headline: null, secondary, health: "none", storeCount: 0 };
}

// Dollar-weighted (or order-weighted) change. This is the YoY the rows support.
export function rollupYoY(rows, currentKeys, yoyKeys) {
  let thisYear = 0;
  let lastYear = 0;
  for (const row of rows || []) {
    const current = field(row, currentKeys);
    const yoy = field(row, yoyKeys);
    if (current == null || current <= 0 || yoy == null || yoy <= -100 || Math.abs(yoy) >= 1000) continue;
    const factor = 1 + yoy / 100;
    if (!(factor > 0)) continue;
    const prior = current / factor;
    if (!(prior > 0)) continue;
    thisYear += current;
    lastYear += prior;
  }
  if (!(lastYear > 0 && thisYear > 0)) return null;
  return (thisYear / lastYear - 1) * 100;
}

function salesRollupYoY(rows) {
  return rollupYoY(rows, ["sales_dollars"], ["sales_yoy_pct"]);
}

function salesHealth(yoy) {
  if (yoy == null) return "none";
  const rule = SCOPE_BADGES.sales;
  if (yoy > rule.good) return "good";
  if (yoy >= rule.watch) return "watch";
  return "risk";
}

// Lost % in this pack is a fraction of sales (0.0519). Some packs already store percent points (5.19).
// Return percent points: 5.19 means 5.19%. Scale only when the stored figure matches the dollar ratio.
export function lossPercentPoints(sample, dollars, sales) {
  const stored = sample == null || Number.isNaN(Number(sample)) ? null : Number(sample);
  const salesN = Number(sales);
  const dollarsN = dollars == null || dollars === "" ? null : Number(dollars);
  const ratio =
    salesN > 0 && dollarsN != null && Number.isFinite(dollarsN) && dollarsN !== 0 ? dollarsN / salesN : null;
  const scaled = ratio == null ? null : ratio * 100;
  if (stored == null) return scaled;
  if (ratio != null && Math.abs(stored) <= 1.5 && Math.abs(ratio - stored) <= Math.abs(scaled - stored)) {
    return scaled;
  }
  return stored;
}

function lossPct(dollars, sales, stored) {
  const sample = average((stored || []).filter((value) => Number.isFinite(value)));
  return lossPercentPoints(sample, dollars, sales);
}

export function rowsInScope(rows, filters, roster, section) {
  return (rows || []).filter((row) => row && row.store && includesScope(row, filters, roster, section));
}

export function shopperIdKey(row) {
  return String((row && row.shopperId) || "").trim();
}

// One picker count: distinct shopperId on the rows in scope.
export function distinctShopperCount(rows) {
  const ids = new Set();
  for (const row of rows || []) {
    const id = shopperIdKey(row);
    if (id) ids.add(id);
  }
  return ids.size;
}

const PICKER_HEALTH_RANK = { none: 0, good: 1, watch: 2, risk: 3 };

function starHealth(value, full, half, invert) {
  if (value == null || Number.isNaN(Number(value))) return "none";
  if (invert) {
    if (value < full) return "good";
    if (value <= half) return "watch";
    return "risk";
  }
  if (value >= full) return "good";
  if (value >= half) return "watch";
  return "risk";
}

function pickerHasVolume(row) {
  const orders = field(row, ["orders"]);
  const picks = field(row, ["picks"]);
  const hours = field(row, ["pick_hours"]);
  if (orders != null && orders > 0) return true;
  if (picks != null && picks > 0) return true;
  if (hours != null && hours > 0) return true;
  return field(row, ["pph"]) != null;
}

function pickerRowHealth(row) {
  const flags = [];
  const pph = field(row, ["pph"]);
  if (pph != null) flags.push(band(pph, 80, 74));
  const presub = field(row, ["presub_pct"]);
  if (presub != null) flags.push(starHealth(presub, 5, 6, true));
  const oos = field(row, ["oos_pct"]);
  if (oos != null) flags.push(starHealth(oos, 3, 5, true));
  const oth = field(row, ["oth5_pct"]);
  if (oth != null) flags.push(starHealth(oth, 92, 78, false));
  const coe = field(row, ["coe_pct"]);
  if (coe != null) flags.push(starHealth(coe, 20, 0, false));
  const ott = field(row, ["ott_pct"]);
  if (ott != null) flags.push(starHealth(ott, 95, 90, false));
  if (flags.includes("risk")) return "risk";
  if (flags.includes("watch")) return "watch";
  if (flags.includes("good")) return "good";
  return "none";
}

function pickerStatusTone(row) {
  const health = pickerRowHealth(row);
  if (health === "none" && pickerHasVolume(row)) return "watch";
  return health;
}

// Worst tone per shopperId, so Healthy + Watch + At Risk equals the shopper count.
export function pickerShopperBands(rows) {
  const worst = new Map();
  for (const row of rows || []) {
    const id = shopperIdKey(row);
    if (!id) continue;
    const tone = pickerStatusTone(row);
    const prev = worst.get(id);
    if (!prev || PICKER_HEALTH_RANK[tone] > PICKER_HEALTH_RANK[prev]) worst.set(id, tone);
  }
  let healthy = 0;
  let watch = 0;
  let risk = 0;
  for (const tone of worst.values()) {
    if (tone === "good") healthy += 1;
    else if (tone === "watch") watch += 1;
    else if (tone === "risk") risk += 1;
  }
  return { shoppers: worst.size, healthy, watch, risk };
}

export function sectionStoreCount(rows, filters, roster, section) {
  if (!Array.isArray(rows)) return null;
  return rowsInScope(rows, filters, roster, section).length;
}

function countText(count) {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(Number(count));
}

// "2,089 of 2,164" when a store-average tile skips stores that lack the metric.
export function partialCountLine(have, total) {
  const present = Number(have);
  const all = Number(total);
  if (!Number.isFinite(present) || !Number.isFinite(all)) return "";
  if (present <= 0 || all <= 0 || present >= all) return "";
  return `${countText(present)} of ${countText(all)}`;
}

export function metricCountLine(rows, keys) {
  const list = Array.isArray(rows) ? rows : [];
  let have = 0;
  for (const row of list) {
    if (field(row, keys) != null) have += 1;
  }
  return partialCountLine(have, list.length);
}

// Division filter on the Regions card. Sales dollars are a sum of the stores
// in that division. Labor stays an unweighted store average.
export function divisionChipTitle(section, title) {
  const name = String(title || "");
  if (section === "labor") return `${name} store average`;
  if (section === "sales") return `${name} store sum`;
  return name;
}

// A dashboard store count is either "Loading…" or the section-row count.
// The placeholder has no digits, so a pack storeCount cannot flash first.
export function companyCountText(count, pending) {
  if (pending) return "Loading…";
  const number = Number(count);
  if (!Number.isFinite(number) || number <= 0) return "";
  return `${countText(number)} stores`;
}

// Browse counts use the same rule: a placeholder with no digits until section rows exist.
export function browseCountText(count, pending) {
  if (pending) return "Loading…";
  if (count == null || count === "") return "";
  const number = Number(count);
  if (!Number.isFinite(number) || number < 0) return "";
  return countText(number);
}

export function reportedStoreLine(count, secondary, pending) {
  if (pending || count == null || !Number.isFinite(Number(count))) return "Loading…";
  const rest = String(secondary || "")
    .split("·")
    .slice(1)
    .join("·")
    .trim();
  const lead = `${countText(count)} stores reported`;
  return rest ? `${lead} · ${rest}` : lead;
}

export function figureAbsent(text) {
  const value = String(text ?? "").trim();
  return value === "" || value === "—" || value.toLowerCase() === "no data";
}

// Cooked region or division line. District / OM / Store have no chrome grade.
export function chromeSeat(lines, section, filters) {
  if (!filters || filters.district || filters.om || filters.store) return null;
  if (!filters.region && !filters.division) return null;
  const visible = (lines || []).filter(
    (line) => line && line.section === section && regionLineInScope(line, filters, []),
  );
  if (filters.division) {
    for (const line of visible) {
      for (const child of line.children || []) {
        if (!matchesDivision(child.division, filters.division)) continue;
        return {
          grain: "division",
          label: child.division,
          value: child.value,
          count: child.count,
          health: child.health || "none",
        };
      }
    }
    return null;
  }
  const line = visible[0];
  if (!line) return null;
  return {
    grain: "region",
    label: line.region,
    value: line.value,
    count: line.count,
    health: line.health || "none",
  };
}

export function summarizeSeat(section, rows) {
  const latest = rows || [];
  switch (section) {
    case "sales": {
      const scored = latest.filter((row) => field(row, ["sales_dollars"]) != null);
      if (!scored.length) return empty("No Sales rows in this filter");
      let up = 0;
      let flat = 0;
      let down = 0;
      for (const row of scored) {
        const yoy = field(row, ["sales_yoy_pct"]);
        if (yoy == null) continue;
        if (yoy > 0) up += 1;
        else if (yoy >= -3) flat += 1;
        else down += 1;
      }
      const dollars = scored.reduce((sum, row) => sum + field(row, ["sales_dollars"]), 0);
      return {
        headline: dollars,
        secondary: `${up} up · ${flat} flat · ${down} down`,
        health: salesHealth(salesRollupYoY(scored)),
        storeCount: scored.length,
      };
    }
    case "lost_revenue": {
      const scored = latest.filter((row) => field(row, ["lost_revenue"]) != null);
      if (!scored.length) return empty("No Lost Revenue rows in this filter");
      let dollars = 0;
      let sales = 0;
      const stored = [];
      let watch = 0;
      let risk = 0;
      for (const row of scored) {
        const lost = field(row, ["lost_revenue"]);
        dollars += lost;
        const pct = field(row, ["lost_revenue_pct"]);
        if (pct != null) stored.push(pct);
        const ecomm = field(row, ["ecomm_sales"]);
        if (ecomm != null && ecomm >= 20) sales += ecomm;
        const rowHealth = band(lossPercentPoints(pct, lost, ecomm), 3, 5, true);
        if (rowHealth === "watch") watch += 1;
        if (rowHealth === "risk") risk += 1;
      }
      const pct = lossPct(dollars, sales, stored);
      const secondary =
        pct == null ? "Total Lost Revenue % (Total Opportunity)" : `${pct.toFixed(2)}% of opportunity`;
      return {
        headline: dollars,
        secondary,
        health: scopeHealth("lost_revenue", pct),
        storeCount: scored.length,
        watchCount: watch,
        riskCount: risk,
      };
    }
    case "missing_items":
    case "pre_sub_oos": {
      const key = section === "pre_sub_oos" ? ["oos_pct", "mi_pct"] : ["mi_pct"];
      const scored = latest.filter((row) => field(row, key) != null);
      const label = section === "pre_sub_oos" ? "Pre-Sub OOS" : "Missing Items";
      if (!scored.length) return empty(`No ${label} rows in this filter`);
      let healthy = 0;
      let watch = 0;
      let risk = 0;
      const values = [];
      for (const row of scored) {
        const value = field(row, key);
        values.push(value);
        const tone = band(value, 5, 6.5, true);
        if (tone === "good") healthy += 1;
        else if (tone === "watch") watch += 1;
        else if (tone === "risk") risk += 1;
      }
      return {
        headline: average(values),
        secondary: `${healthy} healthy · ${watch} watch · ${risk} over 6.50%`,
        health: scopeHealth(section, average(values)),
        storeCount: scored.length,
        healthyCount: healthy,
        watchCount: watch,
        riskCount: risk,
      };
    }
    case "five_star": {
      const scored = latest.filter((row) => field(row, ["star_rating"]) != null);
      if (!scored.length) return empty("No 5 Star rows in this filter");
      const values = scored.map((row) => field(row, ["star_rating"]));
      const five = values.filter((value) => value >= 4.95).length;
      const pass = values.filter((value) => value >= 4).length;
      const fail = values.filter((value) => value < 4).length;
      return {
        headline: average(values),
        secondary: `${five} of ${scored.length} at 5.00 · ${pass} pass · ${fail} fail`,
        health: scopeHealth("five_star", average(values)),
        storeCount: scored.length,
      };
    }
    case "pick_path": {
      const scored = latest.filter((row) => field(row, ["compliance_pct"]) != null);
      if (!scored.length) return empty("No Pick Path rows in this filter");
      const values = scored.map((row) => field(row, ["compliance_pct"]));
      const atGoal = values.filter((value) => value >= 90).length;
      const atRisk = values.filter((value) => value < 80).length;
      return {
        headline: average(values),
        secondary: `${atGoal} of ${scored.length} at 90% · ${atRisk} below 80%`,
        health: scopeHealth("pick_path", average(values)),
        storeCount: scored.length,
      };
    }
    case "prep_not_ready": {
      const scored = latest.filter((row) => field(row, ["pnr_rate_pct", "prep_not_ready_pct"]) != null);
      if (!scored.length) return empty("No Prep rows in this filter");
      const values = scored.map((row) => field(row, ["pnr_rate_pct", "prep_not_ready_pct"]));
      const atGoal = values.filter((value) => value <= 1.9).length;
      const atRisk = values.filter((value) => value > 2.5).length;
      return {
        headline: average(values),
        secondary: `${atGoal} of ${scored.length} at 1.9% · ${atRisk} above 2.5%`,
        health: scopeHealth("prep_not_ready", average(values)),
        storeCount: scored.length,
      };
    }
    case "dynacap": {
      const scored = latest.filter((row) => field(row, ["dynacap_rate", "pieces_per_hour"]) != null);
      const capacity = latest.filter((row) => field(row, ["eot_capacity", "used_capacity"]) != null);
      if (!scored.length && capacity.length) {
        return {
          headline: null,
          secondary: "No Pcs/Hr in this scope. EOT and Used Capacity are on the store rows.",
          health: "none",
          storeCount: capacity.length,
        };
      }
      if (!scored.length) return empty("No Dynacap rows in this filter");
      const values = scored.map((row) => field(row, ["dynacap_rate", "pieces_per_hour"]));
      const atGoal = values.filter((value) => value >= 65).length;
      const atRisk = values.filter((value) => value < 60).length;
      const capacityOnly = capacity.filter((row) => field(row, ["dynacap_rate", "pieces_per_hour"]) == null);
      const gap = capacityOnly.length ? ` · ${capacityOnly.length} stores have capacity but no Pcs/Hr` : "";
      return {
        headline: average(values),
        secondary: `${atGoal} of ${scored.length} at 65 · ${atRisk} below 60${gap}`,
        health: scopeHealth("dynacap", average(values)),
        storeCount: scored.length,
      };
    }
    case "schedule_quality": {
      const scored = latest.filter((row) => field(row, ["schedule_efficiency_pct"]) != null);
      if (!scored.length) return empty("No Schedule rows in this filter");
      const values = scored.map((row) => field(row, ["schedule_efficiency_pct"]));
      const atGoal = values.filter((value) => value >= 90).length;
      const under = latest.filter((row) => (field(row, ["under_schedule_pct", "under_scheduled"]) || 0) > 5).length;
      const over = latest.filter((row) => (field(row, ["over_schedule_pct", "over_scheduled"]) || 0) > 5).length;
      const headline = average(values);
      const health = scopeHealth("schedule_quality", headline);
      return {
        headline,
        secondary: `${atGoal} of ${scored.length} at 90% · ${under} stores under above 5% · ${over} stores over above 5%`,
        health,
        storeCount: scored.length,
      };
    }
    case "pph": {
      const scored = latest.filter((row) => field(row, ["pph"]) != null);
      if (!scored.length) return empty("No stores in view");
      const values = scored.map((row) => field(row, ["pph"]));
      const atGoal = values.filter((value) => value >= 80).length;
      const between = values.filter((value) => value >= 74 && value < 80).length;
      const atRisk = values.filter((value) => value < 74).length;
      const headline = average(values);
      return {
        headline,
        secondary: `${atGoal} of ${scored.length} at 80 · ${between} between 74 and 80 · ${atRisk} below 74`,
        health: scopeHealth("pph", headline),
        storeCount: scored.length,
        atGoalCount: atGoal,
        betweenCount: between,
        riskCount: atRisk,
      };
    }
    case "labor": {
      const scored = latest.filter((row) => !row.sourceIssue && field(row, ["target_vs_actual_pct"]) != null);
      if (!scored.length) return empty("No Labor rows in this filter");
      const values = scored.map((row) => field(row, ["target_vs_actual_pct"]));
      let healthy = 0;
      let watch = 0;
      let risk = 0;
      for (const value of values) {
        if (value <= 0) healthy += 1;
        else if (value <= 3) watch += 1;
        else risk += 1;
      }
      const headline = values.length === 1 ? values[0] : average(values);
      return {
        headline,
        secondary: `${healthy} healthy · ${watch} watch · ${risk} over 3%`,
        health: scopeHealth("labor", headline),
        storeCount: scored.length,
      };
    }
    case "picker_scorecard": {
      if (!latest.length) return empty("No shopper rows in this filter");
      const bands = pickerShopperBands(latest);
      const health = pickerScopeHealth(latest);
      return {
        headline: bands.shoppers,
        secondary: `${bands.risk} opportunity · ${bands.watch} watch · ${bands.healthy} doing well`,
        health,
        storeCount: bands.shoppers,
        healthyCount: bands.healthy,
        watchCount: bands.watch,
        riskCount: bands.risk,
      };
    }
    default:
      return empty("No rows in this filter");
  }
}

function laborRegionHeadline(tables, region) {
  const row = (tables || []).find(
    (item) => item && item.section === "labor" && item.region === region && item.headline != null && String(item.headline).trim() !== "",
  );
  return row ? String(row.headline) : "";
}

export const LOST_EXCL_LABEL = "Lost $ excl. Missed";

const LOST_REGIONS = ["East", "South", "California", "West"];

function lostParts(row) {
  const lost = field(row, ["lost_revenue"]);
  const missed = field(row, ["missed_sales"]);
  return (lost == null ? 0 : lost) - (missed == null ? 0 : missed);
}

export function lostExclMissed(rows) {
  let sum = 0;
  for (const row of rows || []) sum += lostParts(row);
  return { sum, count: (rows || []).length };
}

function lostScopeSeat(rows) {
  const roll = lostExclMissed(rows);
  return {
    fixedCompany: false,
    headline: roll.sum,
    headlineText: null,
    figureLabel: LOST_EXCL_LABEL,
    missed: "Not available",
    secondary: "",
    health: "none",
    storeCount: roll.count,
  };
}

export function laborGrainValue(tables, row) {
  if (!row || row.grain !== "region") return row && row.value != null ? row.value : "";
  const callout = laborRegionHeadline(tables, row.label);
  return callout || (row.value != null ? row.value : "");
}

export function lostGrainRows(rows, filters, roster) {
  if (!filters || filters.district || filters.om || filters.store) return [];
  const scoped = rowsInScope(rows, filters, roster, "lost_revenue");
  const grouped = new Map();
  for (const row of scoped) {
    const division = canonicalDivision(row.division) || row.division || "";
    const region = String(regionForDivision(division) || "").replace(/\s*region$/i, "");
    if (!LOST_REGIONS.includes(region)) continue;
    if (!grouped.has(region)) grouped.set(region, new Map());
    const divisions = grouped.get(region);
    if (!divisions.has(division)) divisions.set(division, { sum: 0, count: 0 });
    const slot = divisions.get(division);
    slot.sum += lostParts(row);
    slot.count += 1;
  }
  const out = [];
  for (const region of LOST_REGIONS) {
    const divisions = grouped.get(region);
    if (!divisions) continue;
    let sum = 0;
    let count = 0;
    const children = [];
    for (const [division, slot] of divisions) {
      if (filters.division && !matchesDivision(division, filters.division)) continue;
      sum += slot.sum;
      count += slot.count;
      children.push({
        grain: "division",
        label: division,
        value: slot.sum,
        count: slot.count,
        region,
        title: LOST_EXCL_LABEL,
      });
    }
    if (!children.length) continue;
    if (!filters.division) {
      out.push({ grain: "region", label: region, value: sum, count, title: LOST_EXCL_LABEL });
    }
    out.push(...children);
  }
  return out;
}

function regionLabel(raw) {
  return String(raw || "").replace(/\s*region$/i, "");
}

function chromeGrainValue(lines, section, region, division) {
  const line = (lines || []).find((item) => item && item.section === section && regionLabel(item.region) === region);
  if (!line) return "";
  if (!division) return line.value != null ? line.value : "";
  const child = (line.children || []).find((item) => matchesDivision(item.division, division));
  if (!child || child.value == null) return "";
  return child.value;
}

function grainMetric(section, bucket, lines, region, division) {
  const count = section === "picker_scorecard" ? distinctShopperCount(bucket) : bucket.length;
  if (section === "picker_scorecard") {
    return { value: `${countText(count)} shoppers`, count, workbook: false };
  }
  if (section === "sales" && division) {
    const built = summarizeSeat(section, bucket);
    return {
      value: built.headline == null ? "Not available" : shownRate(section, built.headline),
      count,
      workbook: false,
    };
  }
  if (section === "sales") {
    return { value: chromeGrainValue(lines, section, region, ""), count, workbook: true };
  }
  if (section === "labor" && !division) {
    return { value: chromeGrainValue(lines, section, region, ""), count, workbook: false };
  }
  if (ROW_RATE_SECTIONS.has(section) || (section === "labor" && division)) {
    const built = summarizeSeat(section, bucket);
    return { value: shownRate(section, built.headline), count, workbook: false };
  }
  return { value: chromeGrainValue(lines, section, region, division), count, workbook: false };
}

function orderedDivisionKeys(lines, section, region, divisionMap) {
  const line = (lines || []).find((item) => item && item.section === section && regionLabel(item.region) === region);
  const names = [];
  const seen = new Set();
  for (const child of (line && line.children) || []) {
    const label = canonicalDivision(child.division) || child.division;
    const key = [...divisionMap.keys()].find((item) => matchesDivision(item, label));
    if (!key || seen.has(key)) continue;
    seen.add(key);
    names.push(key);
  }
  for (const key of divisionMap.keys()) {
    if (!seen.has(key)) names.push(key);
  }
  return names;
}

// Region and division counts from section rows. Lost revenue keeps lostGrainRows.
// Picker's value is the same distinct shopperId count, labeled shoppers.
// Other values stay on the cooked metric line; the count does not.
export function sectionRowGrain(section, rows, filters, roster, lines) {
  if (!filters || filters.district || filters.om || filters.store) return [];
  const scoped = rowsInScope(rows, filters, roster, section);
  const grouped = new Map();
  for (const row of scoped) {
    const division = canonicalDivision(row.division) || row.division || "";
    const region = regionLabel(regionForDivision(division));
    if (!LOST_REGIONS.includes(region) || !division) continue;
    if (!grouped.has(region)) grouped.set(region, new Map());
    const divisions = grouped.get(region);
    if (!divisions.has(division)) divisions.set(division, []);
    divisions.get(division).push(row);
  }
  const out = [];
  for (const region of LOST_REGIONS) {
    const divisions = grouped.get(region);
    if (!divisions) continue;
    const regionRows = [];
    const children = [];
    for (const division of orderedDivisionKeys(lines, section, region, divisions)) {
      if (filters.division && !matchesDivision(division, filters.division)) continue;
      const bucket = divisions.get(division) || [];
      if (!bucket.length) continue;
      regionRows.push(...bucket);
      const counted = grainMetric(section, bucket, lines, region, division);
      children.push({
        grain: "division",
        label: division,
        value: counted.value,
        count: counted.count,
        workbook: counted.workbook,
        region,
      });
    }
    if (!children.length) continue;
    if (!filters.division) {
      const counted = grainMetric(section, regionRows, lines, region, "");
      out.push({
        grain: "region",
        label: region,
        value: counted.value,
        count: counted.count,
        workbook: counted.workbook,
      });
    }
    out.push(...children);
  }
  return out;
}

export function seatSummary(section, { company, lines, rows, filters, roster, tables }) {
  if (!filtersActive(filters)) {
    const built = Array.isArray(rows) && rows.length ? summarizeSeat(section, rows) : null;
    let health = built && built.health ? built.health : "none";
    // Labor's card shows the workbook Total. The unweighted store mean must not paint the badge.
    if (section === "labor") {
      health = company && company.headline != null ? scopeHealth("labor", company.headline) : "none";
    }
    if (section === "picker_scorecard") {
      health = Array.isArray(rows) && rows.length ? pickerScopeHealth(rows) : "none";
    }
    return {
      fixedCompany: true,
      headline: company ? company.headline : null,
      headlineText: null,
      secondary: (company && company.secondary) || "",
      health,
      storeCount: (company && company.storeCount) || 0,
    };
  }
  const scoped = rowsInScope(rows, filters, roster, section);
  if (section === "lost_revenue" && !(filters && filters.store)) {
    return lostScopeSeat(scoped);
  }
  const built = summarizeSeat(section, scoped);
  // A rate that is an average of these rows is that average. The pack line
  // stays only when this scope has no rows yet.
  if (ROW_RATE_SECTIONS.has(section) && scoped.length && built.headline != null) {
    return {
      fixedCompany: false,
      headline: built.headline,
      headlineText: shownRate(section, built.headline),
      secondary: built.secondary,
      health: built.health,
      storeCount: built.storeCount,
      workbook: false,
    };
  }
  // Picker chrome value and count are cooked shopper totals. The card uses
  // distinct shopperId from these rows instead.
  const chrome = section === "picker_scorecard" ? null : chromeSeat(lines, section, filters);
  if (chrome) {
    // regionLines labor is the unweighted average of store Target vs Actual
    // (East -8.59%). The region callout is the weighted workbook figure
    // (East -3.97%). It cannot be rebuilt from the rows, so the region seat
    // keeps the callout and the page labels it workbook total. A division seat is
    // the average of that division's rows. Sales at division scope is that
    // division's own row sum, never the parent region dollar.
    let headlineText = chrome.value;
    let workbook = section === "sales";
    let calloutHealth = null;
    if (section === "labor" && chrome.grain === "region") {
      const callout = laborRegionHeadline(tables, chrome.label);
      if (callout) {
        headlineText = callout;
        workbook = true;
        const number = Number(String(callout).replace(/[%,\s]/g, ""));
        calloutHealth = scopeHealth("labor", number);
      }
    }
    if (
      (section === "labor" || section === "sales") &&
      chrome.grain === "division" &&
      scoped.length &&
      built.headline != null
    ) {
      return {
        fixedCompany: false,
        headline: built.headline,
        headlineText: shownRate(section, built.headline),
        secondary: built.secondary,
        health: built.health,
        storeCount: built.storeCount,
        workbook: false,
      };
    }
    return {
      fixedCompany: false,
      headline: null,
      headlineText,
      secondary: built.storeCount ? built.secondary : section === "picker_scorecard" ? built.secondary : "",
      // Same rows as the chip. A region line's health must not paint the badge a different color.
      health: calloutHealth || (scoped.length ? built.health : chrome.health && chrome.health !== "none" ? chrome.health : built.health),
      storeCount: chrome.count || built.storeCount,
      workbook,
    };
  }
  return {
    fixedCompany: false,
    headline: built.headline,
    headlineText: built.headline != null && ROW_RATE_SECTIONS.has(section) ? shownRate(section, built.headline) : null,
    secondary: built.secondary,
    health: built.health,
    storeCount: built.storeCount,
    workbook: false,
  };
}
