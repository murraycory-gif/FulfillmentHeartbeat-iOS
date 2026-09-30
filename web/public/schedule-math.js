// Upcoming Weeks Schedule Check. Same gates as ScheduleCheckMath.
import { includesScope, filtersActive } from "./filters.js";
import { pct } from "./clock.js";

export const SALES_GATE = 30_000;
export const UNDER_GATE = 10;
export const FOUR_UNDER_GATE = 9;
export const OVER_GATE = 15;
export const EFF_GOAL = 90;

const DIVISION_ORDER = [
  "Shaws",
  "Mid-Atlantic",
  "Jewel Osco",
  "Southern",
  "United",
  "Southwest",
  "NorCal",
  "SoCal",
  "Mountain West",
  "Seattle",
  "Haggen",
  "Portland",
];

export function qualifies(sales, under, fourUnder, over) {
  if (sales == null || Number(sales) < SALES_GATE) return false;
  if (under != null && Number(under) >= UNDER_GATE) return true;
  if (fourUnder != null && Number(fourUnder) - FOUR_UNDER_GATE > 0.0001) return true;
  if (over != null && Number(over) >= OVER_GATE) return true;
  return false;
}

export function qualifiesStore(store) {
  return qualifies(store.sales, store.under, store.fourUnder, store.over);
}

export function notScheduled(store) {
  if (store.under == null || store.eff == null) return false;
  return Number(store.under) >= 99.5 && Math.abs(Number(store.eff)) < 0.05;
}

export function effHealth(value, unscheduled) {
  if (unscheduled) return "none";
  if (value == null || Number.isNaN(Number(value))) return "none";
  return Number(value) >= EFF_GOAL ? "good" : "risk";
}

export function percentHealth(value, unscheduled) {
  if (unscheduled) return "none";
  if (value == null || Number.isNaN(Number(value))) return "none";
  return Number(value) <= 0.0001 ? "good" : "risk";
}

function average(values) {
  const nums = values.filter((value) => value != null && !Number.isNaN(Number(value))).map(Number);
  if (!nums.length) return null;
  return nums.reduce((sum, value) => sum + value, 0) / nums.length;
}

function marketLabeled(pack, name) {
  return (pack.markets || []).find(
    (market) => String(market.label || "").toLowerCase() === String(name || "").toLowerCase(),
  );
}

export function scopedStores(pack, filters) {
  return (pack.stores || []).filter((store) => includesScope(store, filters));
}

export function summary(pack, filters) {
  const rows = scopedStores(pack, filters);
  const storeUnder = average(rows.map((row) => row.under));
  const storeOver = average(rows.map((row) => row.over));
  const cutInside = Boolean(filters.district || filters.om || filters.store);
  let market = null;
  if (!filtersActive(filters)) market = marketLabeled(pack, "Total") || null;
  else if (!cutInside && filters.division) market = marketLabeled(pack, filters.division) || null;
  const usesMarket = market != null;
  return {
    under: usesMarket ? (market.under ?? null) : storeUnder,
    over: usesMarket ? (market.over ?? null) : storeOver,
    pch: average(rows.map((row) => row.pch)),
    eff: average(rows.map((row) => row.eff)),
    underCount: rows.filter((row) => Number(row.under) > 0).length,
    overCount: rows.filter((row) => Number(row.over) > 0).length,
    scope: rows.length,
    usesMarketLook: usesMarket,
    storeUnder,
    storeOver,
    actionCount: rows.filter(qualifiesStore).length,
  };
}

export function companyMarketNote(card, filters) {
  if (!card.usesMarketLook || filtersActive(filters)) return null;
  if (card.storeUnder == null || card.storeOver == null) return null;
  return `Market Look Total under/over. Stores Current Week average is Under ${pct(card.storeUnder)} / Over ${pct(card.storeOver)}.`;
}

export function bannerMismatch(pack, card, filters) {
  if (filtersActive(filters)) return null;
  if (pack.workbookActionBanner == null) return null;
  if (Number(pack.workbookActionBanner) === card.actionCount) return null;
  return `Workbook banner said ${pack.workbookActionBanner} stores. This cook qualifies ${card.actionCount}.`;
}

export function actionGroups(pack, filters) {
  const rows = scopedStores(pack, filters).filter(qualifiesStore);
  const grouped = new Map();
  for (const row of rows) {
    const name = row.division || "";
    if (!grouped.has(name)) grouped.set(name, []);
    grouped.get(name).push(row);
  }
  const names = [...grouped.keys()].sort((lhs, rhs) => {
    const left = DIVISION_ORDER.indexOf(lhs);
    const right = DIVISION_ORDER.indexOf(rhs);
    const a = left === -1 ? DIVISION_ORDER.length : left;
    const b = right === -1 ? DIVISION_ORDER.length : right;
    if (a !== b) return a - b;
    return lhs.localeCompare(rhs);
  });
  return names.map((name) => ({
    division: name,
    region: (grouped.get(name)[0] && grouped.get(name)[0].region) || "",
    stores: grouped.get(name).slice().sort((lhs, rhs) => Number(rhs.under || -1) - Number(lhs.under || -1)),
  }));
}

export function rankedRegions(pack, filters) {
  const rows = scopedStores(pack, filters);
  const names = [...new Set(rows.map((row) => row.region).filter(Boolean))];
  return names
    .map((name) => {
      const group = rows.filter((row) => row.region === name);
      return {
        region: name,
        under: average(group.map((row) => row.under)),
        over: average(group.map((row) => row.over)),
        pch: average(group.map((row) => row.pch)),
        eff: average(group.map((row) => row.eff)),
        scope: group.length,
      };
    })
    .sort((lhs, rhs) => {
      if (lhs.eff == null && rhs.eff != null) return 1;
      if (lhs.eff != null && rhs.eff == null) return -1;
      if (lhs.eff != null && rhs.eff != null && lhs.eff !== rhs.eff) return lhs.eff - rhs.eff;
      return lhs.region.localeCompare(rhs.region);
    });
}

export function rankedDivisions(pack, filters) {
  const rows = scopedStores(pack, filters);
  const cutInside = Boolean(filters.district || filters.om || filters.store);
  const names = [...new Set(rows.map((row) => row.division).filter(Boolean))];
  return names
    .map((name) => {
      const group = rows.filter((row) => row.division === name);
      const market = cutInside ? null : marketLabeled(pack, name);
      return {
        division: name,
        region: (group[0] && group[0].region) || "",
        under: market ? (market.under ?? null) : average(group.map((row) => row.under)),
        over: market ? (market.over ?? null) : average(group.map((row) => row.over)),
        pch: average(group.map((row) => row.pch)),
        eff: average(group.map((row) => row.eff)),
        scope: group.length,
      };
    })
    .sort((lhs, rhs) => {
      if (lhs.eff == null && rhs.eff != null) return 1;
      if (lhs.eff != null && rhs.eff == null) return -1;
      if (lhs.eff != null && rhs.eff != null && lhs.eff !== rhs.eff) return lhs.eff - rhs.eff;
      return lhs.division.localeCompare(rhs.division);
    });
}
