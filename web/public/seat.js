// Filter seat for scorecards.
// Company (no filter) keeps the cooked chrome headline. That figure is not a
// store average — Sales and Loss dollars are the workbook company tiles.
// Labor at region scope uses the regionTables callout, the same figure as the card.
// Lost revenue below company is Lost $ excl. Missed from this section's rows.
// Other region and division seats use the cooked chrome line.
// District, OM, and Store rebuild from fact rows in scope. They never keep
// the company number. A missing rate stays blank.

import { canonicalDivision, filtersActive, includesScope, matchesDivision, regionForDivision, regionLineInScope } from "./filters.js";

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

function empty(secondary) {
  return { headline: null, secondary, health: "none", storeCount: 0 };
}

function salesRollupYoY(rows) {
  let thisYear = 0;
  let lastYear = 0;
  for (const row of rows) {
    const current = field(row, ["sales_dollars"]);
    const yoy = field(row, ["sales_yoy_pct"]);
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

function salesHealth(yoy) {
  if (yoy == null) return "none";
  if (yoy > 0) return "good";
  if (yoy >= -3) return "watch";
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

export function sectionStoreCount(rows, filters, roster, section) {
  if (!Array.isArray(rows)) return null;
  return rowsInScope(rows, filters, roster, section).length;
}

function countText(count) {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(Number(count));
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
        health: band(pct, 3, 5, true),
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
        health: band(average(values), 5, 6.5, true),
        storeCount: scored.length,
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
        health: band(average(values), 5, 4),
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
        health: band(average(values), 90, 80),
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
        health: band(average(values), 1.9, 2.5, true),
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
      return {
        headline: average(values),
        secondary: `${atGoal} of ${scored.length} at 65 · ${atRisk} below 60`,
        health: band(average(values), 65, 60),
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
      let health = "good";
      if (under > 0 || over > 0) health = "risk";
      else health = band(headline, 90, 90);
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
        health: headline != null && headline >= 80 ? "good" : band(headline, 80, 74),
        storeCount: scored.length,
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
        health: band(headline, 0, 3, true),
        storeCount: scored.length,
      };
    }
    case "picker_scorecard": {
      if (!latest.length) return empty("No shopper rows in this filter");
      const stores = new Set(latest.map((row) => row.store).filter(Boolean));
      return {
        headline: latest.length,
        secondary: `${stores.size} ${stores.size === 1 ? "store" : "stores"}`,
        health: "none",
        storeCount: latest.length,
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

export function seatSummary(section, { company, lines, rows, filters, roster, tables }) {
  if (!filtersActive(filters)) {
    return {
      fixedCompany: true,
      headline: company ? company.headline : null,
      headlineText: null,
      secondary: (company && company.secondary) || "",
      health: (company && company.health) || "none",
      storeCount: (company && company.storeCount) || 0,
    };
  }
  const scoped = rowsInScope(rows, filters, roster, section);
  if (section === "lost_revenue" && !(filters && filters.store)) {
    return lostScopeSeat(scoped);
  }
  const built = summarizeSeat(section, scoped);
  const chrome = chromeSeat(lines, section, filters);
  if (chrome) {
    // regionLines labor is the unweighted average of store Target vs Actual
    // (East -8.59%). The dashboard region card reads regionTables, the cooked
    // labor callout (East -3.97%). Extreme stores pull the unweighted average
    // away from that callout, so the labor page uses the callout at region
    // scope and both surfaces show one number. A division seat stays on
    // regionLines because the callout has no division headline.
    let headlineText = chrome.value;
    if (section === "labor" && chrome.grain === "region") {
      const callout = laborRegionHeadline(tables, chrome.label);
      if (callout) headlineText = callout;
    }
    return {
      fixedCompany: false,
      headline: null,
      headlineText,
      secondary: built.storeCount ? built.secondary : section === "picker_scorecard" ? built.secondary : "",
      health: chrome.health && chrome.health !== "none" ? chrome.health : built.health,
      storeCount: chrome.count || built.storeCount,
    };
  }
  return {
    fixedCompany: false,
    headline: built.headline,
    headlineText: null,
    secondary: built.secondary,
    health: built.health,
    storeCount: built.storeCount,
  };
}
