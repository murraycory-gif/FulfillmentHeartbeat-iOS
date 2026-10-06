import { updatedLine, considerPublished, pct, money, num, formatHeadline, publishStamp, buildLabel } from "./clock.js";
import { schemaWarning } from "./schema.js?v=1";
import {
  emptyFilters,
  filtersActive,
  includesScope,
  scheduleDistrictNote,
  emptyScopeNote,
  shownDistrict,
  scopeLabel,
  finestScope,
  searchScope,
  cascadePick,
  scopeChips,
  filtersUpTo,
  browseLevel,
  browseScope,
  canonicalStore,
  canonicalDivision,
  regionForDivision,
} from "./filters.js";
import { packURL } from "./packs.js";
import { healthWord, mailtoURL, shareBrief, shareEml, shareHtml, sharePages, shareSubject } from "./share.js";
import { browseCountText, chromeSeat, companyCountText, distinctShopperCount, figureAbsent, formatCompanyAiv, laborGrainValue, LOST_EXCL_LABEL, lossPercentPoints, lostExclMissed, lostGrainRows, reportedStoreLine, rowsInScope, seatSummary, sectionRowGrain, sectionStoreCount, summarizeSeat } from "./seat.js";
import { metricsInSource, pphBar, shopperHoursText, shopperIdentity, shopperMatchesQuery, shopperPph, sortShoppersByPph } from "./shoppers.js";
import {
  summary as scheduleSummary,
  scheduleVisibleTitle,
  companyMarketNote,
  scheduleGapNote,
  actionGroups,
  rankedDivisions,
  rankedRegions,
  notScheduled,
  barelyScheduled,
  percentHealth,
  effHealth,
} from "./schedule-math.js?v=4";

let packStamp = "";
const APP_VERSION = "41";
const BUILD_SHA = "__BUILD_SHA__";

const PAGES = [
  { id: "dashboard", title: "Dashboard" },
  { id: "sales", title: "Sales", section: "sales" },
  { id: "lost_revenue", title: "Lost Revenue", section: "lost_revenue" },
  { id: "missing_items", title: "Missing Items", section: "missing_items" },
  { id: "five_star", title: "5 Star", section: "five_star" },
  { id: "pre_sub_oos", title: "Pre-Sub", section: "pre_sub_oos" },
  { id: "pick_path", title: "Pick Path", section: "pick_path" },
  { id: "prep_not_ready", title: "Prep", section: "prep_not_ready" },
  { id: "dynacap", title: "Dynacap", section: "dynacap" },
  { id: "schedule_quality", title: "Schedule Quality", section: "schedule_quality" },
  { id: "schedule", title: "Schedule Check" },
  { id: "picker_scorecard", title: "Picker", section: "picker_scorecard" },
  { id: "pph", title: "PPH", section: "pph" },
  { id: "labor", title: "Labor", section: "labor" },
];

const COLUMNS = {
  sales: [
    ["Sales", ["sales_dollars"], money],
    ["YoY %", ["sales_yoy_pct"], pct],
    ["Orders", ["sales_orders"], (value) => num(value, 0)],
  ],
  lost_revenue: [
    ["Lost", ["lost_revenue"], money],
    ["Lost %", ["lost_revenue_pct"], (value, row) => pct(lossPercentPoints(value, cell(row, ["lost_revenue"]), cell(row, ["ecomm_sales"])))],
    ["Goal %", ["lost_revenue_goal_pct"], (value, row) => pct(lossPercentPoints(value, cell(row, ["lost_revenue_goal"]), cell(row, ["ecomm_sales"])))],
    ["eComm", ["ecomm_sales"], money],
    ["Missed", ["missed_sales"], money],
  ],
  missing_items: [["Rate", ["mi_pct"], pct]],
  five_star: [
    ["Rating", ["star_rating"], (value) => num(value, 2)],
    ["Flash", ["flash_pct"], pct],
    ["COE", ["coe_pct"], pct],
    ["OTT", ["ott_pct"], pct],
    ["Pre-Sub", ["presub_pct"], pct],
    ["OTH", ["oth5_pct"], pct],
  ],
  pre_sub_oos: [["Rate", ["oos_pct", "mi_pct"], pct]],
  pick_path: [
    ["Path %", ["compliance_pct"], pct],
    ["PPH", ["pph"], (value) => num(value, 1)],
  ],
  prep_not_ready: [["PNR %", ["pnr_rate_pct", "prep_not_ready_pct"], pct]],
  dynacap: [
    ["Pcs/Hr", ["dynacap_rate", "pieces_per_hour"], (value) => num(value, 1)],
    ["Util %", ["utilization_pct", "pickup_util_pct"], pct],
    ["EOT", ["eot_capacity"], (value) => num(value, 0)],
    ["Used", ["used_capacity"], (value) => num(value, 0)],
  ],
  schedule_quality: [
    ["Quality Sch Eff", ["schedule_efficiency_pct"], pct],
    ["Under", ["under_schedule_pct", "under_scheduled"], pct],
    ["Over", ["over_schedule_pct", "over_scheduled"], pct],
  ],
  pph: [["PPH", ["pph"], (value) => num(value, 1)]],
  labor: [
    ["Vs Target", ["target_vs_actual_pct"], pct],
    ["Act Cost", ["act_cost_pct"], pct],
    ["Cost Tgt", ["cost_trgt_pct"], pct],
    ["Labor Sch Eff", ["schedule_efficiency_pct"], pct],
    ["UPLH", ["uplh_impact_pct"], pct],
    ["Wage", ["wage_impact_pct"], pct],
    ["AIV", ["aiv_impact_pct"], pct],
  ],
};

const ROW_PAGE = 80;

const state = {
  page: "dashboard",
  filters: emptyFilters(),
  scopeQuery: "",
  browseOpen: false,
  home: null,
  homeError: "",
  packs: new Map(),
  scheduleTab: "summary",
  bannerTimer: 0,
  tableWindow: ROW_PAGE,
  shopperWindow: ROW_PAGE,
  shopperQuery: "",
  shopperPrepared: [],
  shopperColumns: [],
  failedPacks: new Set(),
};

const drawer = document.querySelector("#drawer");
const scrim = document.querySelector("#scrim");
const main = document.querySelector("#main");
const scopeSearch = document.querySelector("#scope-search");
const scopeResults = document.querySelector("#scope-results");
const scopeChipsBox = document.querySelector("#scope-chips");
const browseOpen = document.querySelector("#browse-open");
const browseRoot = document.querySelector("#browse");
const browseList = document.querySelector("#browse-list");
const browseTitle = document.querySelector("#browse-title");
const browseBack = document.querySelector("#browse-back");
const browseClose = document.querySelector("#browse-close");
const clearFilters = document.querySelector("#clear-filters");
const title = document.querySelector("#page-title");
const updated = document.querySelector("#updated");
const banner = document.querySelector("#banner");
const navToggle = document.querySelector("#nav-toggle");
const shareRoot = document.querySelector("#share");
const shareOpen = document.querySelector("#share-open");
const shareClose = document.querySelector("#share-close");
const shareSend = document.querySelector("#share-send");
const shareScope = document.querySelector("#share-scope");
const sharePicks = document.querySelector("#share-picks");
const shareError = document.querySelector("#share-error");
const shareTo = document.querySelector("#share-to");

function esc(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function badge(health) {
  const tone = health === "good" || health === "watch" || health === "risk" ? health : "none";
  const label = tone === "good" ? "Healthy" : tone === "watch" ? "Watch" : tone === "risk" ? "At risk" : "NO DATA";
  return `<span class="badge ${tone}">${label}</span>`;
}

function pageById(id) {
  return PAGES.find((page) => page.id === id) || PAGES[0];
}

function roster() {
  return (state.home && state.home.filters && state.home.filters.stores) || [];
}

function summaryFor(section) {
  const list = (state.home && state.home.summaries) || [];
  return list.find((item) => item.section === section) || null;
}

function tilesFor(section) {
  const tiles = state.home && state.home.companyTiles;
  return (tiles && tiles[section]) || null;
}

function raiseBanner(text, sticky = false) {
  if (!text) return;
  banner.hidden = false;
  banner.textContent = text;
  clearTimeout(state.bannerTimer);
  if (sticky) return;
  state.bannerTimer = setTimeout(() => {
    banner.hidden = true;
  }, 5000);
}

function packWait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function authBlocked(response, text) {
  if (!response) return true;
  if (response.status === 401 || response.status === 403) return true;
  const type = (response.headers.get("content-type") || "").toLowerCase();
  if (type.includes("text/html")) return true;
  return String(text || "").trim().startsWith("<");
}

async function readPack(url) {
  const response = await fetch(url, { cache: "no-store", credentials: "same-origin" });
  const text = await response.text();
  const trimmed = text.trim();
  if (authBlocked(response, trimmed) || !response.ok) {
    const error = new Error("NO DATA");
    error.authBlocked = authBlocked(response, trimmed);
    throw error;
  }
  if (!trimmed) throw new Error("NO DATA");
  let data;
  try {
    data = JSON.parse(trimmed);
  } catch {
    const error = new Error("NO DATA");
    error.authBlocked = trimmed.startsWith("<");
    throw error;
  }
  if (!data || typeof data !== "object") throw new Error("NO DATA");
  return data;
}

const inflight = new Map();

async function load(path) {
  if (state.packs.has(path)) return state.packs.get(path);
  const pending = inflight.get(path);
  if (pending) return pending;
  const job = fetchPack(path);
  inflight.set(path, job);
  try {
    return await job;
  } finally {
    inflight.delete(path);
  }
}

async function fetchPack(path) {
  const relative = packURL(path);
  if (!relative) throw new Error("NO DATA");
  const url = new URL(relative, location.origin).href;
  let last = new Error("NO DATA");
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      const data = await readPack(url);
      state.packs.set(path, data);
      state.failedPacks.delete(path);
      if (state.browseOpen) paintBrowse();
      return data;
    } catch (error) {
      last = error instanceof Error ? error : new Error("NO DATA");
      console.error("pack fetch failed", url, last);
      if (last.authBlocked || attempt === 7) break;
      await packWait(400 * (attempt + 1));
    }
  }
  throw last;
}

async function loadOptional(path) {
  if (state.failedPacks.has(path)) return null;
  try {
    return await load(path);
  } catch {
    state.failedPacks.add(path);
    if (state.browseOpen) paintBrowse();
    return null;
  }
}

const NAV_ICON = {
  dashboard: `<rect x="3" y="3" width="6" height="6" rx="1"/><rect x="11" y="3" width="6" height="6" rx="1"/><rect x="3" y="11" width="6" height="6" rx="1"/><rect x="11" y="11" width="6" height="6" rx="1"/>`,
  sales: `<path d="M3 14l4.5-4.5 3 3L17 5"/><path d="M12 5h5v5"/>`,
  lost_revenue: `<path d="M3 6l4.5 4.5 3-3L17 15"/><path d="M12 15h5v-5"/>`,
  missing_items: `<path d="M4 8l6-3 6 3v7l-6 3-6-3z"/><path d="M4 8l6 3 6-3"/><path d="M10 11v7"/>`,
  five_star: `<path d="M10 3.2l1.8 3.8 4.2.6-3 3 .7 4.2L10 13.6 6.3 14.8 7 10.6l-3-3 4.2-.6z"/>`,
  pre_sub_oos: `<circle cx="7" cy="7" r="2.4"/><circle cx="13" cy="13" r="2.4"/><path d="M14.5 5.5l-9 9"/>`,
  pick_path: `<circle cx="5" cy="5" r="1.6"/><circle cx="15" cy="15" r="1.6"/><path d="M6.4 6.2C8 9 8 11 10 12s4 2 3.6 3.8"/>`,
  prep_not_ready: `<circle cx="10" cy="10" r="6.5"/><path d="M10 6.5V10l2.5 2"/>`,
  dynacap: `<path d="M4 13a6.5 6.5 0 0 1 12 0"/><path d="M10 13l3.2-3.2"/><path d="M6 15h8"/>`,
  schedule_quality: `<rect x="4" y="4" width="12" height="12" rx="2"/><path d="M7 10.2l2 2 4-4.2"/>`,
  schedule: `<rect x="4" y="3.5" width="12" height="13" rx="2"/><path d="M7 2.5v3M13 2.5v3M4 7.5h12"/>`,
  picker_scorecard: `<circle cx="10" cy="7" r="2.4"/><path d="M5.5 16.2v-1.1a4.5 4.5 0 0 1 9 0v1.1"/>`,
  pph: `<path d="M4 15V9M10 15V5M16 15v-4"/>`,
  labor: `<circle cx="7" cy="7" r="2"/><circle cx="13.5" cy="7.5" r="1.7"/><path d="M3.2 15.5v-.8a3.8 3.8 0 0 1 7.2-1.2M11 15.5v-.6a3 3 0 0 1 5.3-1"/>`,
};

function pageHealth(page) {
  if (!page.section) return "none";
  const health = (summaryFor(page.section) || {}).health;
  return health === "good" || health === "watch" || health === "risk" ? health : "none";
}

function navIcon(page) {
  const shape = NAV_ICON[page.id] || NAV_ICON.dashboard;
  const tone = pageHealth(page);
  return `<svg class="nav-icon ${tone}" viewBox="0 0 20 20" aria-hidden="true">${shape}</svg>`;
}

let accountSession = null;

function settingsNav() {
  const links = [];
  if (accountSession && accountSession.role === "admin") {
    links.push(`<li><a href="/admin">User management</a></li>`);
  }
  if (accountSession && accountSession.account) {
    links.push(`<li><a href="/account">Account</a></li>`);
  }
  if (!links.length) return "";
  return `<p class="drawer-label">Settings</p><ul class="pages drawer-settings">${links.join("")}</ul>`;
}

function renderNav() {
  const items = PAGES.map(
    (page) =>
      `<li><button type="button" data-page="${page.id}" aria-current="${page.id === state.page ? "page" : "false"}">${navIcon(page)}<span>${esc(page.title)}</span></button></li>`,
  ).join("");
  const buildLine = buildLabel(BUILD_SHA, APP_VERSION);
  const buildHtml = buildLine ? `<p id="build-stamp" class="drawer-stamp">Build ${esc(buildLine)}</p>` : "";
  drawer.innerHTML = `<div class="drawer-head"><p class="drawer-title">Pages</p><button type="button" class="drawer-close" data-close-drawer>Close</button></div><ul class="pages">${items}</ul><div class="drawer-foot">${buildHtml}<p id="stamp" class="drawer-stamp">${esc(packStamp)}</p>${settingsNav()}<button type="button" class="drawer-logout" data-logout>Logout</button></div>`;
}

function loadAccountSession() {
  const url = new URL("/session", location.origin);
  return fetch(url, { credentials: "same-origin", cache: "no-store" })
    .then((response) => (response.ok ? response.json() : null))
    .then((payload) => {
      accountSession = payload;
      renderNav();
    })
    .catch(() => {});
}

function logout() {
  window.location.assign(new URL("/logout", location.origin).href);
}

let searchHits = [];
let browseHits = [];

function scopeFromPick(pick) {
  const cascaded = cascadePick(roster(), pick);
  const order = ["region", "division", "district", "om", "store"];
  const next = emptyFilters();
  const index = order.indexOf(pick.kind);
  for (const key of order) {
    const place = order.indexOf(key);
    if (place < index) next[key] = state.filters[key] || cascaded[key] || "";
    else if (place === index) next[key] = cascaded[key] || "";
  }
  return next;
}

function scrollChromeToTop() {
  window.scrollTo(0, 0);
  document.documentElement.scrollTop = 0;
  document.body.scrollTop = 0;
  const shell = document.querySelector(".shell");
  if (shell) shell.scrollTop = 0;
}

function applyScope(next) {
  state.filters = next;
  state.scopeQuery = "";
  if (scopeSearch) scopeSearch.value = "";
  state.tableWindow = ROW_PAGE;
  state.shopperWindow = ROW_PAGE;
  state.shopperQuery = "";
  if (!shareRoot.hidden) shareScope.textContent = `Filters · ${scopeLabel(next)}`;
  scrollChromeToTop();
  render();
}

function hideResults() {
  if (!scopeResults) return;
  scopeResults.hidden = true;
  scopeResults.innerHTML = "";
  if (scopeSearch) scopeSearch.setAttribute("aria-expanded", "false");
}

function paintResults() {
  if (!scopeResults || !scopeSearch) return;
  const query = state.scopeQuery.trim();
  if (!query) {
    hideResults();
    return;
  }
  const groups = searchScope(roster(), state.filters, query);
  searchHits = groups.flatMap((group) => group.hits);
  if (!searchHits.length) {
    scopeResults.hidden = false;
    scopeSearch.setAttribute("aria-expanded", "true");
    scopeResults.innerHTML = `<p class="scope-group">No matches</p>`;
    return;
  }
  let index = 0;
  scopeResults.innerHTML = groups
    .map((group) => {
      const rows = group.hits
        .map((hit) => {
          const detail = hit.detail ? `<small>${esc(hit.detail)}</small>` : "";
          const html = `<button type="button" class="scope-hit" data-hit="${index}">${esc(hit.label)}${detail}</button>`;
          index += 1;
          return html;
        })
        .join("");
      return `<p class="scope-group">${esc(group.group)}</p>${rows}`;
    })
    .join("");
  scopeResults.hidden = false;
  scopeSearch.setAttribute("aria-expanded", "true");
}

function parentScope(filters) {
  if (filters.store) return filtersUpTo(filters, "om");
  if (filters.om) return filtersUpTo(filters, "district");
  if (filters.district) return filtersUpTo(filters, "division");
  if (filters.division) return filtersUpTo(filters, "region");
  return emptyFilters();
}

function paintBrowse() {
  if (!browseRoot || !browseList) return;
  const open = state.browseOpen;
  browseRoot.hidden = !open;
  if (browseOpen) browseOpen.setAttribute("aria-expanded", open ? "true" : "false");
  if (!open) return;
  const level = browseLevel(roster(), state.filters);
  browseHits = level.rows;
  if (browseTitle) browseTitle.textContent = level.title;
  if (browseBack) browseBack.hidden = !filtersActive(state.filters);
  browseList.innerHTML = level.rows
    .map((item, index) => {
      const count = browseCountLabel(item);
      const small = count ? `<small>${esc(count)}</small>` : "";
      return `<button type="button" class="browse-row" data-browse="${index}">${esc(item.label)}${small}</button>`;
    })
    .join("");
}

function browseCountLabel(item) {
  const section = pageById(state.page).section || "";
  if (!section) return `${num(item.count, 0)} roster stores`;
  if (sectionPackPending(section)) return browseCountText(null, true);
  const rows = sectionRows(section);
  if (!rows) return "";
  const scope = browseScope(state.filters, item.kind, item.value);
  if (section === "picker_scorecard") {
    return browseCountText(distinctShopperCount(rowsInScope(rows, scope, roster(), section)), false);
  }
  const count = sectionStoreCount(rows, scope, roster(), section);
  return browseCountText(count, false);
}

function paintChips() {
  if (!scopeChipsBox) return;
  const chips = scopeChips(state.filters);
  const last = chips.length - 1;
  const reset = filtersActive(state.filters)
    ? `<button type="button" class="scope-reset" data-clear-scope aria-label="Clear scope">×</button>`
    : "";
  scopeChipsBox.innerHTML =
    chips
      .map(
        (chip, index) =>
          `<button type="button" class="scope-chip" data-scope="${esc(chip.level)}"${index === last ? ' aria-current="true"' : ""}>${esc(chip.label)}</button>`,
      )
      .join("") + reset;
}

function renderFilters() {
  paintChips();
  paintResults();
  paintBrowse();
  if (clearFilters) {
    clearFilters.textContent = "Clear all";
    clearFilters.hidden = !filtersActive(state.filters);
  }
}

function setUpdated(raw) {
  updated.textContent = updatedLine(raw);
}

function packBannerTime(home) {
  if (home && home.cookedAt) return home.cookedAt;
  return home && home.publishedAt;
}

function applyPackStamp(raw) {
  const next = publishStamp(raw);
  if (!next) return;
  packStamp = next;
  const node = document.querySelector("#stamp");
  if (node) node.textContent = next;
}

function parseTileNumber(raw) {
  const number = Number(String(raw ?? "").replace(/[$,%\s]/g, ""));
  return Number.isFinite(number) ? number : null;
}

// Cooked Lost % strings are the fraction with a % sign ("0.05%"). Goal % uses the same scale.
function lostTileValues(labels, values) {
  const next = (values || []).slice();
  const index = (name) => labels.indexOf(name);
  const lostPct = index("Lost %");
  const goal = index("Goal %");
  if (lostPct < 0) return next;
  const parsed = parseTileNumber(next[lostPct]);
  const dollars = parseTileNumber(next[index("Lost $")]);
  const sales = parseTileNumber(next[index("eComm $")]);
  const points = lossPercentPoints(parsed, dollars, sales);
  const scaled = points != null && parsed != null && Math.abs(points - parsed) > 0.05;
  if (scaled) next[lostPct] = pct(points);
  if (scaled && goal >= 0) {
    const goalNumber = parseTileNumber(next[goal]);
    if (goalNumber != null && Math.abs(goalNumber) <= 1.5) next[goal] = pct(goalNumber * 100);
  }
  return next;
}

function sectionTone(section) {
  const health = (summaryFor(section) || {}).health;
  return health === "good" || health === "watch" || health === "risk" ? health : "";
}

function tileUsesSectionTone(label) {
  return /yoy/i.test(String(label || ""));
}

const METRIC_NOTES = {
  labor:
    "Labor Sch Eff is schedule efficiency from the Labor workbook company total. It is not Schedule Quality’s average schedule efficiency.",
  schedule_quality:
    "Quality Sch Eff is the average schedule efficiency on the Schedule Quality sheet. It is not Labor Sch Eff.",
  picker_scorecard:
    "Shoppers are distinct shopper IDs on the picker rows in this scope. Browse, the region table, and the card use that count.",
};

function shownTileLabel(section, label) {
  if (section === "labor" && label === "Sch Eff") return "Labor Sch Eff";
  if (section === "schedule_quality" && label === "Sch Eff") return "Quality Sch Eff";
  if (section === "sales" && (label === "Orders" || label === "Items")) return `${label} workbook total`;
  return label;
}

const ROW_COUNT_TILES = {
  missing_items: new Set(["Healthy", "Watch", "At Risk"]),
  pre_sub_oos: new Set(["Healthy", "Watch", "At Risk"]),
  pph: new Set(["At Goal", "Below 74"]),
  picker_scorecard: new Set(["Shoppers", "Healthy", "Watch", "At Risk"]),
};

function rowCountTile(section, label) {
  const wanted = ROW_COUNT_TILES[section];
  if (!wanted || !wanted.has(label)) return null;
  const rows = sectionRows(section);
  if (!rows) return sectionPackPending(section) ? "Loading…" : "—";
  const built = summarizeSeat(section, rowsInScope(rows, state.filters, roster(), section));
  let count = null;
  if (section === "picker_scorecard" && label === "Shoppers") count = built.storeCount;
  else if (section === "pph" && label === "At Goal") count = built.atGoalCount;
  else if (section === "pph" && label === "Below 74") count = built.riskCount;
  else if (label === "Healthy") count = built.healthyCount;
  else if (label === "Watch") count = built.watchCount;
  else if (label === "At Risk") count = built.riskCount;
  if (count == null || !Number.isFinite(Number(count))) return "—";
  return num(count, 0);
}

function shownTileValue(section, label, raw) {
  const fromRows = rowCountTile(section, label);
  if (fromRows != null) return fromRows;
  if (section === "labor" && label === "AIV") {
    const market = state.home && state.home.laborMarket;
    const aiv = market && market.aiv_impact_pct;
    if (typeof aiv === "number" && Number.isFinite(aiv)) return formatCompanyAiv(aiv);
  }
  if (raw == null || raw === "") return "—";
  const text = String(raw).trim();
  return text.startsWith("$") ? money(raw) : text;
}

function cookedTiles(section) {
  const tiles = tilesFor(section);
  if (!tiles || !Array.isArray(tiles.labels) || !tiles.labels.length) return "";
  const labels = tiles.labels;
  const values = section === "lost_revenue" ? lostTileValues(labels, tiles.values || []) : tiles.values || [];
  const tone = sectionTone(section);
  return `<div class="tiles">${labels
    .map((label, index) => {
      const raw = values[index];
      const name = shownTileLabel(section, label);
      const shown = shownTileValue(section, label, raw);
      const title = shown.startsWith("$") ? String(name || "").replace(/\s*\$+\s*$/, "") : name;
      const toneClass = tone && tileUsesSectionTone(label) ? ` tone-${tone}` : "";
      return `<div class="chip${toneClass}"><span>${esc(title)}</span><strong>${esc(shown)}</strong></div>`;
    })
    .join("")}</div>`;
}

function seatFor(section) {
  const pack = state.packs.get(`section/${section}`);
  return seatSummary(section, {
    company: summaryFor(section),
    lines: (state.home && state.home.regionLines) || [],
    tables: (state.home && state.home.regionTables) || [],
    rows: (pack && pack.rows) || [],
    filters: state.filters,
    roster: roster(),
  });
}

function shownStoreSentence(section, text, count) {
  if (section !== "lost_revenue" || !text || !count) return text || "";
  return String(text).replace(/^[\d,]+ stores reported/, `${num(count, 0)} stores reported`);
}

function shownSecondary(section, text) {
  if (section !== "schedule_quality" || !text) return text || "";
  return String(text).replace(
    /(\d[\d,]*) of (\d[\d,]*) at 90% · (\d[\d,]*) under · (\d[\d,]*) over/,
    "$1 of $2 at 90% · $3 stores under above 5% · $4 stores over above 5%",
  );
}

function seatReady(section) {
  if (section === "lost_revenue" && filtersActive(state.filters)) return state.packs.has("section/lost_revenue");
  if (section === "picker_scorecard") {
    return state.packs.has("section/picker_scorecard") || state.failedPacks.has("section/picker_scorecard");
  }
  if (!filtersActive(state.filters)) return true;
  if (state.packs.has(`section/${section}`)) return true;
  return Boolean(chromeSeat((state.home && state.home.regionLines) || [], section, state.filters));
}

function headerStoreCount(section) {
  const rows = sectionRows(section);
  if (!rows) return null;
  if (section === "picker_scorecard") return distinctShopperCount(rowsInScope(rows, state.filters, roster(), section));
  return sectionStoreCount(rows, state.filters, roster(), section);
}

function sectionPackPending(section) {
  const path = `section/${section}`;
  return !state.packs.has(path) && !state.failedPacks.has(path);
}

function sectionRows(section) {
  const pack = state.packs.get(`section/${section}`);
  if (!pack || !Array.isArray(pack.rows)) return null;
  return pack.rows;
}

function companyCountLabel(section) {
  if (section === "picker_scorecard") {
    const rows = sectionRows(section);
    if (!rows) return sectionPackPending(section) ? "Loading…" : "";
    const count = distinctShopperCount(rowsInScope(rows, state.filters, roster(), section));
    return count ? `${num(count, 0)} shoppers` : "";
  }
  if (filtersActive(state.filters)) {
    const counted = headerStoreCount(section);
    if (counted == null || !counted) return "";
    return `${num(counted, 0)} stores`;
  }
  if (sectionPackPending(section)) return companyCountText(null, true);
  const rows = sectionRows(section);
  if (!rows) return "";
  return companyCountText(sectionStoreCount(rows, state.filters, roster(), section), false);
}

function companySecondaryText(section, seat) {
  if (section === "picker_scorecard") {
    if (sectionPackPending(section)) return "Loading…";
    const rows = sectionRows(section);
    if (!rows) return "";
    const built = summarizeSeat(section, rowsInScope(rows, state.filters, roster(), section));
    return built.secondary || "";
  }
  const cooked = shownSecondary(section, seat.secondary);
  if (filtersActive(state.filters)) return shownStoreSentence(section, cooked, headerStoreCount(section));
  if (sectionPackPending(section)) return "Loading…";
  const rows = sectionRows(section);
  if (!rows) return "";
  if (section === "lost_revenue") {
    return reportedStoreLine(sectionStoreCount(rows, state.filters, roster(), section), seat.secondary, false);
  }
  const built = summarizeSeat(section, rowsInScope(rows, state.filters, roster(), section));
  return shownSecondary(section, built.secondary || "");
}

function companyBlock(section, title) {
  if (!seatReady(section)) {
    const name = title ? `<h2>${esc(title)}</h2>` : "";
    return `<div class="score-face">${name}<p class="note">Loading…</p></div>`;
  }
  const seat = seatFor(section);
  const tiles = filtersActive(state.filters) ? "" : cookedTiles(section);
  if (!summaryFor(section) && !tiles && !filtersActive(state.filters)) return `<p class="nodata">NO DATA</p>`;
  const health = seat.health || "none";
  const counted = headerStoreCount(section);
  const countLabel = companyCountLabel(section);
  const pickerRows = section === "picker_scorecard" ? sectionRows(section) : null;
  const pickerFigure = pickerRows
    ? formatHeadline(section, distinctShopperCount(rowsInScope(pickerRows, state.filters, roster(), section)))
    : "";
  const figureText = pickerRows
    ? pickerFigure
    : seat.headlineText != null && seat.headlineText !== ""
      ? seat.headlineText
      : seat.headline != null && seat.headline !== ""
        ? formatHeadline(section, seat.headline)
        : filtersActive(state.filters)
          ? "—"
          : "";
  const tone = health === "good" || health === "watch" || health === "risk" ? health : "none";
  const hideEmptyBadge =
    counted > 0 &&
    tone === "none" &&
    (section === "picker_scorecard" || (section === "dynacap" && seat.headline == null));
  const badgeHtml = tone === "none" && (hideEmptyBadge || !figureAbsent(figureText) || Boolean(tiles)) ? "" : badge(tone);
  const name = title ? `<h2>${esc(title)}</h2>` : "";
  const figureLabel = !tiles && seat.figureLabel ? `<p class="eyebrow">${esc(seat.figureLabel)}</p>` : "";
  const figure = !tiles && figureText ? `<p class="figure">${esc(figureText)}</p>` : "";
  const missedLine = !tiles && seat.missed ? `<p class="secondary">Missed $ ${esc(seat.missed)}</p>` : "";
  const secondaryText = companySecondaryText(section, seat);
  const secondary = secondaryText ? `<p class="secondary">${esc(secondaryText)}</p>` : "";
  const definition = METRIC_NOTES[section] ? `<p class="note">${esc(METRIC_NOTES[section])}</p>` : "";
  const scope = filtersActive(state.filters)
    ? `<p class="scope">In this scope: ${esc(countLabel || "no cooked grade")}.</p>`
    : "";
  return `<div class="score-face">${name}${badgeHtml}${countLabel ? `<p class="sub">${esc(countLabel)}</p>` : ""}${figureLabel}${figure}${missedLine}${tiles}${secondary}${definition}${scope}</div>`;
}

function cell(row, keys) {
  const payload = row.payload || {};
  for (const key of keys) {
    if (payload[key] != null && payload[key] !== "") return payload[key];
  }
  return null;
}

function rosterByStore() {
  const map = new Map();
  for (const row of roster()) {
    if (row && row.store) map.set(canonicalStore(row.store), row);
  }
  return map;
}

function displayDivision(row, known) {
  const match = known.get(canonicalStore(row.store));
  const fromRoster = match && canonicalDivision(match.division);
  if (fromRoster) return fromRoster;
  return canonicalDivision(row.division) || row.division || "—";
}

function shownMetric(section, row, column) {
  if (section === "labor" && row.sourceIssue) return "source data issue";
  const value = cell(row, column[1]);
  if ((column[1] || []).includes("pick_hours")) return shopperHoursText(value, (hours) => column[2](hours, row));
  return column[2](value, row);
}

function table(section, rows) {
  const columns = COLUMNS[section] || [];
  const known = rosterByStore();
  const knownRoster = roster();
  const matched = rows.filter((row) => row.store && includesScope(row, state.filters, knownRoster, section));
  if (!matched.length) {
    const honest = emptyScopeNote(section, state.filters, knownRoster, matched.length);
    return `<p class="note">${esc(honest || "No stores in this scope.")}</p>`;
  }
  const shown = matched.slice(0, state.tableWindow);
  const head = ["Store", "Division", "District", "OM", ...columns.map((column) => column[0])]
    .map((label) => `<th>${esc(label)}</th>`)
    .join("");
  const body = shown
    .map((row) => {
      const metrics = columns
        .map((column) => `<td>${esc(shownMetric(section, row, column))}</td>`)
        .join("");
      const division = displayDivision(row, known);
      const district = shownDistrict(section, row.district, (known.get(canonicalStore(row.store)) || {}).district);
      return `<tr><td>${esc(canonicalStore(row.store))}</td><td>${esc(division)}</td><td>${esc(district)}</td><td>${esc(row.om || "—")}</td>${metrics}</tr>`;
    })
    .join("");
  const more =
    matched.length > shown.length
      ? `<p class="note">${num(shown.length, 0)} of ${num(matched.length, 0)} stores</p><button type="button" class="more" data-more="1">Show more</button>`
      : `<p class="note">${num(matched.length, 0)} stores in this scope.</p>`;
  const cards = shown
    .map((row) => {
      const metrics = columns
        .map(
          (column) =>
            `<div class="metric"><span>${esc(column[0])}</span><strong>${esc(shownMetric(section, row, column))}</strong></div>`,
        )
        .join("");
      const division = displayDivision(row, known);
      const district = shownDistrict(section, row.district, (known.get(canonicalStore(row.store)) || {}).district);
      const manager = row.om || "—";
      const place = section === "schedule_quality"
        ? `${esc(division)} · ${esc(district)} · OM ${esc(manager)}`
        : `${esc(division)} · ${esc(district)} · ${esc(manager)}`;
      return `<li class="store-card"><p class="store-id">${esc(canonicalStore(row.store))}</p><p class="sub">${place}</p><div class="metric-row">${metrics}</div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
}

function grainShown(section, row) {
  if (section === "labor" && row.grain === "region") {
    const callout = laborGrainValue((state.home && state.home.regionTables) || [], row);
    if (callout) return String(callout);
  }
  if (typeof row.value === "number") return section === "lost_revenue" ? money(row.value) : String(row.value);
  const text = String(row.value ?? "");
  return text.trim().startsWith("$") ? money(text) : text;
}

function grainBlock(section) {
  const pack = state.packs.get(`section/${section}`);
  if (!pack || !Array.isArray(pack.rows)) return "";
  const rows =
    section === "lost_revenue"
      ? lostGrainRows(pack.rows, state.filters, roster())
      : sectionRowGrain(section, pack.rows, state.filters, roster(), (state.home && state.home.regionLines) || []);
  if (!rows.length) return "";
  const body = rows
    .map((row) => {
      const value = grainShown(section, row);
      return `<tr><td>${esc(row.grain === "region" ? "Region" : "Division")}</td><td>${esc(row.label)}</td><td>${esc(value)}</td><td>${esc(row.count)}</td></tr>`;
    })
    .join("");
  const cards = rows
    .map((row) => {
      const value = grainShown(section, row);
      const extra = String(value ?? "").replace(/[^\d]/g, "") === String(row.count ?? "") ? "" : `<span>${esc(row.count)}</span>`;
      return `<li class="line-card"><div><p class="eyebrow">${esc(row.grain === "region" ? "Region" : "Division")}</p><p class="line-title">${esc(row.label)}</p></div><div class="line-value"><strong>${esc(value)}</strong>${extra}</div></li>`;
    })
    .join("");
  const heading = filtersActive(state.filters) ? scopeLabel(state.filters) : "Regions";
  const valueHead = section === "lost_revenue" ? LOST_EXCL_LABEL : "Value";
  return `<section class="grain"><h2>${esc(heading)}</h2><div class="desk-only scroll"><table><thead><tr><th>Grain</th><th>Name</th><th>${esc(valueHead)}</th><th>Count</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only line-cards">${cards}</ul></section>`;
}

const REGION_CARD_ORDER = ["East", "South", "California", "West"];

function regionVisible(name) {
  if (state.filters.district || state.filters.om || state.filters.store) return false;
  if (state.filters.region) {
    const wanted = String(state.filters.region).replace(/\s*region$/i, "");
    if (wanted !== name) return false;
  }
  if (state.filters.division) {
    const home = String(regionForDivision(state.filters.division) || "").replace(/\s*region$/i, "");
    if (home !== name) return false;
  }
  return true;
}

function lostRegionRollup(regionName) {
  const pack = state.packs.get("section/lost_revenue");
  if (!pack || !Array.isArray(pack.rows)) return null;
  const wanted = String(regionName || "").replace(/\s*region$/i, "");
  const rows = pack.rows.filter((row) => {
    const division = canonicalDivision(row.division) || row.division;
    const region = String(regionForDivision(division) || "").replace(/\s*region$/i, "");
    return region === wanted;
  });
  return lostExclMissed(rows);
}

function regionCardsHtml() {
  const tables = (state.home && state.home.regionTables) || [];
  if (!tables.length) return "";
  const byRegion = new Map();
  for (const row of tables) {
    if (!row || !row.region) continue;
    if (!byRegion.has(row.region)) byRegion.set(row.region, []);
    byRegion.get(row.region).push(row);
  }
  const cards = REGION_CARD_ORDER.filter((name) => byRegion.has(name) && regionVisible(name))
    .map((name) => {
      const rows = byRegion.get(name);
      const lostRoll = lostRegionRollup(name);
      const storeLine = sectionPackPending("lost_revenue")
        ? companyCountText(null, true)
        : companyCountText(lostRoll ? lostRoll.count : 0, false);
      const chips = rows
        .map((row) => {
          let title = row.title;
          let raw = row.headline;
          if (row.section === "lost_revenue" && lostRoll) {
            title = LOST_EXCL_LABEL;
            raw = lostRoll.sum;
          }
          const missing = raw == null || String(raw).trim() === "" || String(raw).trim() === "—" || (row.section !== "lost_revenue" && row.health === "none");
          const tone = missing ? "none" : row.health === "good" || row.health === "watch" || row.health === "risk" ? row.health : "none";
          const text = raw == null ? "" : String(raw).trim();
          const shown = missing ? "No data" : typeof raw === "number" || text.startsWith("$") ? money(raw) : text;
          return `<div class="chip bar-${tone}"><span>${esc(title)}</span><strong>${esc(shown)}</strong></div>`;
        })
        .join("");
      return `<article class="scorecard"><div class="score-face"><h2>${esc(name)}</h2>${storeLine ? `<p class="sub">${esc(storeLine)}</p>` : ""}<div class="tiles">${chips}</div></div></article>`;
    })
    .join("");
  if (!cards) return "";
  const note =
    state.filters.district || state.filters.om || state.filters.store
      ? `<p class="note">District, OM, and store seats stay on the store rows.</p>`
      : "";
  const legend = `<p class="region-legend" aria-label="Red is at risk, amber is watch, green is healthy, gray is no data"><i class="risk"></i><i class="watch"></i><i class="good"></i><i class="none"></i></p>`;
  return `<section class="region-cards" id="pack-lines"><h2>Regions</h2>${legend}${note}${cards}</section>`;
}

function scheduleDashCard(pack) {
  if (!state.packs.has("schedule") && !state.failedPacks.has("schedule")) {
    return `<article class="scorecard"><button class="link" type="button" data-page="schedule"><div class="score-face"><h2>Schedule Check</h2><p class="note">Loading…</p></div></button></article>`;
  }
  if (!pack || scheduleIsEmpty(pack)) {
    return `<article class="scorecard none"><button class="link" type="button" data-page="schedule"><div class="score-face"><h2>Schedule Check</h2><p class="nodata">NO DATA</p></div></button></article>`;
  }
  const card = scheduleSummary(pack, state.filters, roster());
  const week = pack.week ? `Week ${pack.week}` : scheduleVisibleTitle(pack.summaryTitle, pack.week) || "Schedule";
  return `<article class="scorecard"><button class="link" type="button" data-page="schedule"><div class="score-face"><h2>Schedule Check</h2><p class="sub">${esc(week)}</p><p class="figure">${esc(num(card.actionCount, 0))} to review</p><p class="secondary">Sales at least $30,000, and under at least 10%, 4-week under above 9%, or over at least 15%.</p></div></button></article>`;
}

function renderDashboard() {
  const schedulePack = state.packs.get("schedule");
  const cards = PAGES.filter((page) => page.id !== "dashboard")
    .map((page) => {
      if (page.id === "schedule") return scheduleDashCard(schedulePack);
      const health = (summaryFor(page.section) || {}).health || "none";
      return `<article class="scorecard ${health}"><button class="link" type="button" data-page="${page.id}">${companyBlock(page.section, page.title)}</button></article>`;
    })
    .join("");
  main.innerHTML = `<div class="cards">${cards}</div>${regionCardsHtml()}`;
}

function shopperSeat(filters) {
  return Boolean(filters.division || filters.district || filters.om || filters.store);
}

const SHOPPER_COLUMNS = {
  pph: [
    ["PPH", ["pph"], (value) => num(value, 1)],
    ["Hours", ["pick_hours"], (value) => num(value, 1)],
    ["Orders", ["orders"], (value) => num(value, 0)],
  ],
  path: [
    ["Path %", ["compliance_pct"], pct],
    ["PPH", ["pph"], (value) => num(value, 1)],
    ["Orders", ["orders"], (value) => num(value, 0)],
  ],
  scorecard: [
    ["PPH", ["pph"], (value) => num(value, 1)],
    ["Hours", ["pick_hours"], (value) => num(value, 1)],
    ["Orders", ["orders"], (value) => num(value, 0)],
    ["Presub", ["presub_pct"], pct],
    ["OOS", ["oos_pct"], pct],
    ["OTT", ["ott_pct"], pct],
    ["OTH", ["oth5_pct"], pct],
    ["COE", ["coe_pct"], pct],
  ],
};

function shopperListHtml() {
  const query = state.shopperQuery || "";
  const filtered = (state.shopperPrepared || []).filter((row) => shopperMatchesQuery(row, query));
  if (!filtered.length) {
    const message = query.trim() ? "No shoppers match this search." : "No shopper data";
    return `<p class="note">${esc(message)}</p>`;
  }
  const columns = state.shopperColumns || [];
  const shown = filtered.slice(0, state.shopperWindow);
  const more =
    filtered.length > shown.length
      ? `<p class="note">${num(shown.length, 0)} of ${num(filtered.length, 0)} shoppers</p><button type="button" class="more" data-more="shoppers">Show more</button>`
      : `<p class="note">${num(filtered.length, 0)} shoppers in this scope.</p>`;
  const head = ["", "Shopper", "Store", ...columns.map((column) => column.label)]
    .map((label) => `<th${label ? "" : ' class="bar"'}>${esc(label)}</th>`)
    .join("");
  const hoursText = (column, row) => {
    const value = cell(row, column.keys);
    if ((column.keys || []).includes("pick_hours")) return shopperHoursText(value, (hours) => column.format(hours));
    return column.format(value);
  };
  const body = shown
    .map((row) => {
      const tone = pphBar(shopperPph(row));
      const metrics = columns.map((column) => `<td>${esc(hoursText(column, row))}</td>`).join("");
      const name = shopperIdentity(row) || "—";
      return `<tr><td class="bar bar-${tone}"></td><td>${esc(name)}</td><td>${esc(canonicalStore(row.store))}</td>${metrics}</tr>`;
    })
    .join("");
  const cards = shown
    .map((row) => {
      const tone = pphBar(shopperPph(row));
      const metrics = columns
        .map(
          (column) =>
            `<div class="metric"><span>${esc(column.label)}</span><strong>${esc(hoursText(column, row))}</strong></div>`,
        )
        .join("");
      const name = shopperIdentity(row) || "—";
      return `<li class="store-card bar-${tone}"><p class="store-id">${esc(name)}</p><p class="sub">Store ${esc(canonicalStore(row.store))}</p><div class="metric-row">${metrics}</div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
}

function paintShopperList() {
  const slot = document.querySelector("[data-shopper-list]");
  if (slot) slot.innerHTML = shopperListHtml();
}

function shopperBlock(rows, columns, sourceNote) {
  const matched = sortShoppersByPph(
    (rows || []).filter(
      (row) => row.store && (row.shopper || row.shopperId) && includesScope(row, state.filters, roster()),
    ),
  );
  const shaped = (columns || []).map((column) => ({ label: column[0], keys: column[1], format: column[2] }));
  state.shopperPrepared = matched;
  state.shopperColumns = metricsInSource(matched, shaped);
  if (!matched.length) return `<h2>Shoppers</h2><p class="note">No shopper data</p>`;
  const search =
    matched.length > ROW_PAGE
      ? `<input class="shopper-find" data-shopper-search type="search" enterkeyhint="search" value="${esc(state.shopperQuery)}" placeholder="Search shopper or store" aria-label="Search shopper or store">`
      : "";
  const note = sourceNote ? `<p class="note">${esc(sourceNote)}</p>` : "";
  return `<section class="shoppers"><h2>Shoppers</h2>${note}${search}<div data-shopper-list>${shopperListHtml()}</div></section>`;
}

function renderPicker() {
  const summary = summaryFor("picker_scorecard");
  const path = "section/picker_scorecard";
  const loaded = state.packs.has(path);
  const pack = state.packs.get(path);
  const rows = (pack && pack.rows) || [];
  const waiting = shopperSeat(state.filters) && !loaded && !state.failedPacks.has(path);
  if (!summary && !tilesFor("picker_scorecard") && !rows.length && !filtersActive(state.filters) && !waiting) {
    main.innerHTML = `<p class="nodata">NO DATA</p>`;
    return;
  }
  const health = rows.length && ((summary && summary.health) || "none") === "none" ? "" : (summary && summary.health) || "none";
  let note = `<p class="note">Shopper rows open from a division, district, OM, or store.</p>`;
  if (shopperSeat(state.filters)) {
    if (waiting) note = `<p class="note">Loading…</p>`;
    else if (!loaded) note = `<h2>Shoppers</h2><p class="note">No shopper data</p>`;
    else note = shopperBlock(rows, SHOPPER_COLUMNS.scorecard, "");
  }
  main.innerHTML = `<article class="scorecard ${health}">${companyBlock("picker_scorecard", "Picker")}</article>${grainBlock("picker_scorecard")}${note}`;
}

function renderPresub(pack) {
  if (state.home && state.home.preSubItemTabPresent === false) {
    return `<h2>Top 10 Pre-Sub OOS items</h2><p class="note">Item detail not in this upload</p>`;
  }
  const scopes = (pack && pack.scopes) || {};
  const key = finestScope(state.filters);
  const direct = key && Object.prototype.hasOwnProperty.call(scopes, key) ? scopes[key] : null;
  const foundKey = direct
    ? key
    : Object.keys(scopes).find((name) => key && name.toLowerCase() === key.toLowerCase());
  const items = direct || (foundKey ? scopes[foundKey] : null);
  if (!items) return `<h2>Top 10 Pre-Sub OOS items</h2><p class="note">No cooked list for this scope.</p>`;
  if (!items.length) return `<h2>Top 10 Pre-Sub OOS items</h2><p class="note">No items in this scope.</p>`;
  const shown = items.slice(0, 10);
  const body = shown
    .map(
      (item) =>
        `<tr><td>${esc(item.name || "—")}</td><td>${esc(item.code || "—")}</td><td>${esc(pct(item.percent))}</td><td>${esc(num(item.count, 0))}</td></tr>`,
    )
    .join("");
  const cards = shown
    .map(
      (item) =>
        `<li class="line-card"><div><p class="eyebrow">${esc(item.code || "Item")}</p><p class="line-title">${esc(item.name || "—")}</p></div><div class="line-value"><strong>${esc(pct(item.percent))}</strong><span>${esc(num(item.count, 0))}</span></div></li>`,
    )
    .join("");
  return `<h2>Top 10 Pre-Sub OOS items</h2><div class="desk-only scroll"><table><thead><tr><th>Item</th><th>Code</th><th>Pre-Sub OOS %</th><th>Count</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only line-cards">${cards}</ul>`;
}

function toneClass(health) {
  return health === "good" || health === "risk" || health === "none" ? health : "";
}

function scheduleTabs() {
  return ["summary", "action", "detail"]
    .map((id) => {
      const label = id === "action" ? "Action Needed" : id === "summary" ? "Summary" : "Store Detail";
      return `<button type="button" data-tab="${id}" aria-pressed="${state.scheduleTab === id ? "true" : "false"}">${label}</button>`;
    })
    .join("");
}

function scheduleIsEmpty(pack) {
  if (!pack || pack.empty) return true;
  const stores = Array.isArray(pack.stores) ? pack.stores : [];
  const markets = Array.isArray(pack.markets) ? pack.markets : [];
  return stores.length === 0 && markets.length === 0;
}

function renderSchedule(pack) {
  const tabs = `<div class="seg">${scheduleTabs()}</div>`;
  if (scheduleIsEmpty(pack)) {
    main.innerHTML = `${tabs}<article class="scorecard none"><div class="score-face"><h2>Schedule Check</h2><p class="nodata">NO DATA</p><p class="note">This pack has no Schedule Check rows.</p></div></article>`;
    return;
  }
  const card = scheduleSummary(pack, state.filters, roster());
  const summaryTitle = scheduleVisibleTitle(pack.summaryTitle, pack.week);
  const week = summaryTitle || (pack.week ? `Week ${pack.week}` : "Schedule");
  const gap = scheduleGapNote(pack, state.filters, roster());
  const hero = `<article class="scorecard"><div class="score-face"><h2>Schedule Check</h2><p class="sub">${esc(week)}</p><p class="figure">${esc(num(card.actionCount, 0))} to review</p><p class="secondary">Sales at least $30,000, and under at least 10%, 4-week under above 9%, or over at least 15%. Not scheduled yet and barely scheduled stay off this list.</p>${gap ? `<p class="note">${esc(gap)}</p>` : ""}<p class="note">Summary “Any under” counts stores above 0% this week. Schedule Quality counts stores under above 5%.</p></div></article>`;
  let body = "";
  if (state.scheduleTab === "summary") body = scheduleSummaryHtml(pack, card);
  else if (state.scheduleTab === "detail") body = scheduleDetailHtml(pack);
  else body = scheduleActionHtml(pack, card);
  main.innerHTML = `${hero}${tabs}${body}`;
}

function scheduleSeat(store) {
  const known = rosterByStore().get(canonicalStore(store.store)) || {};
  const division = canonicalDivision(known.division || store.division) || known.division || store.division || "";
  const region = String(store.region || "").trim() || regionForDivision(division) || "";
  return {
    region: region || "—",
    division: division || "—",
    district: known.district || store.district || "—",
    om: known.om || store.om || "—",
  };
}

function seatText(store) {
  const seat = scheduleSeat(store);
  return `${seat.region} · ${seat.division} · ${seat.district} · OM ${seat.om}`;
}

function whyFlags(store) {
  const flags = [];
  if (Number(store.under) >= 10) flags.push("Under");
  if (store.fourUnder != null && Number(store.fourUnder) - 9 > 0.0001) flags.push("4-week");
  if (Number(store.over) >= 15) flags.push("Over");
  return flags.join(", ") || "—";
}

function scheduleActionHtml(pack, card) {
  const groups = actionGroups(pack, state.filters, roster());
  const groupsHtml = groups.length
    ? groups
        .map((group) => {
          const rows = group.stores
            .slice(0, 80)
            .map((store) => {
              const seat = scheduleSeat(store);
              return `<tr><td>${esc(store.store)}</td><td>${esc(seat.region)}</td><td>${esc(seat.division)}</td><td>${esc(seat.district)}</td><td>${esc(seat.om)}</td><td>${esc(pct(store.under))}</td><td>${esc(pct(store.over))}</td><td>${esc(whyFlags(store))}</td></tr>`;
            })
            .join("");
          const cards = group.stores
            .slice(0, 80)
            .map(
              (store) =>
                `<li class="store-card"><p class="store-id">${esc(store.store)}</p><p class="sub">${esc(seatText(store))}</p><div class="metric-row"><div class="metric"><span>Under</span><strong>${esc(pct(store.under))}</strong></div><div class="metric"><span>Over</span><strong>${esc(pct(store.over))}</strong></div><div class="metric"><span>Why</span><strong>${esc(whyFlags(store))}</strong></div></div></li>`,
            )
            .join("");
          return `<section class="group"><h3>${esc(canonicalDivision(group.division) || group.division || "—")} · ${group.stores.length}</h3><div class="desk-only scroll"><table><thead><tr><th>Store</th><th>Region</th><th>Division</th><th>District</th><th>OM</th><th>Under</th><th>Over</th><th>Why</th></tr></thead><tbody>${rows}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul></section>`;
        })
        .join("")
    : `<p class="note">No stores qualify in this scope.</p>`;
  const countLabel = `${card.actionCount} to review`;
  return `<p class="note">${countLabel}. Sales at least $30,000, and under at least 10%, 4-week under above 9%, or over at least 15%.</p>${groupsHtml}`;
}

function scheduleMetricsBlank(row) {
  return row.under == null && row.over == null && row.eff == null;
}

function schedulePct(value, blank) {
  return blank ? "No data" : pct(value);
}

function scheduleRate(store, value) {
  if (notScheduled(store)) return "—";
  return schedulePct(value, scheduleMetricsBlank(store));
}

function scheduleSummaryHtml(pack, card) {
  const blankCard = scheduleMetricsBlank(card);
  const kpis = [
    ["Under", schedulePct(card.under, blankCard), blankCard ? "" : percentHealth(card.under, false)],
    ["Over", schedulePct(card.over, blankCard), blankCard ? "" : percentHealth(card.over, false)],
    ["Pch vs Sch", pct(card.pch), ""],
    ["Sch Eff", schedulePct(card.eff, blankCard), blankCard ? "" : effHealth(card.eff, false)],
    ["Any under", num(card.underCount, 0), ""],
    ["Any over", num(card.overCount, 0), ""],
    ["Schedule stores", num(card.scope, 0), ""],
  ]
    .map(
      ([label, value, health]) =>
        `<div class="kpi ${health || ""}"><span>${label}</span><strong>${esc(value)}</strong></div>`,
    )
    .join("");
  const market = companyMarketNote(card, state.filters);
  const divisions = rankedDivisions(pack, state.filters, roster())
    .map(
      (row) =>
        `<tr><td>${esc(row.division)}</td><td>${esc(schedulePct(row.under, scheduleMetricsBlank(row)))}</td><td>${esc(schedulePct(row.over, scheduleMetricsBlank(row)))}</td><td>${esc(schedulePct(row.eff, scheduleMetricsBlank(row)))}</td><td>${esc(num(row.scope, 0))}</td></tr>`,
    )
    .join("");
  const regionRows = rankedRegions(pack, state.filters, roster())
    .map(
      (row) =>
        `<tr><td>${esc(row.region)}</td><td>${esc(schedulePct(row.under, scheduleMetricsBlank(row)))}</td><td>${esc(schedulePct(row.over, scheduleMetricsBlank(row)))}</td><td>${esc(schedulePct(row.eff, scheduleMetricsBlank(row)))}</td><td>${esc(num(row.scope, 0))}</td></tr>`,
    )
    .join("");
  const regionCards = rankedRegions(pack, state.filters, roster())
    .map(
      (row) =>
        `<li class="line-card"><div><p class="eyebrow">Region</p><p class="line-title">${esc(row.region)}</p></div><div class="line-value"><strong>${esc(schedulePct(row.eff, scheduleMetricsBlank(row)))} eff</strong><span>${esc(schedulePct(row.under, scheduleMetricsBlank(row)))} under · ${esc(schedulePct(row.over, scheduleMetricsBlank(row)))} over · ${esc(num(row.scope, 0))} schedule stores</span></div></li>`,
    )
    .join("");
  const divisionCards = rankedDivisions(pack, state.filters, roster())
    .map(
      (row) =>
        `<li class="line-card"><div><p class="eyebrow">Division</p><p class="line-title">${esc(row.division)}</p></div><div class="line-value"><strong>${esc(schedulePct(row.eff, scheduleMetricsBlank(row)))} eff</strong><span>${esc(schedulePct(row.under, scheduleMetricsBlank(row)))} under · ${esc(schedulePct(row.over, scheduleMetricsBlank(row)))} over · ${esc(num(row.scope, 0))} schedule stores</span></div></li>`,
    )
    .join("");
  return `<div class="tiles">${kpis}</div><p class="note">Any under: stores on this week above 0% under. Not the review list, and not Schedule Quality’s stores under above 5%. Schedule stores follow the workbook, not the site roster.</p>${market ? `<p class="note">${esc(market)}</p>` : ""}<h2>Regions</h2><div class="desk-only scroll"><table><thead><tr><th>Region</th><th>Under</th><th>Over</th><th>Eff</th><th>Schedule stores</th></tr></thead><tbody>${regionRows}</tbody></table></div><ul class="phone-only line-cards">${regionCards}</ul><h2>Divisions</h2><div class="desk-only scroll"><table><thead><tr><th>Division</th><th>Under</th><th>Over</th><th>Eff</th><th>Schedule stores</th></tr></thead><tbody>${divisions}</tbody></table></div><ul class="phone-only line-cards">${divisionCards}</ul>`;
}

function scheduleDetailHtml(pack) {
  const matched = (pack.stores || []).filter((store) => includesScope(store, state.filters, roster()));
  if (!matched.length) return `<p class="note">No schedule stores in this scope.</p>`;
  const rows = matched.slice(0, state.tableWindow);
  const more =
    matched.length > rows.length
      ? `<p class="note">${num(rows.length, 0)} of ${num(matched.length, 0)} schedule stores</p><button type="button" class="more" data-more="1">Show more</button>`
      : "";
  const body = rows
    .map((store) => {
      const unscheduled = notScheduled(store);
      const thin = barelyScheduled(store);
      const quiet = unscheduled || thin;
      const name = esc(canonicalStore(store.store));
      const tag = unscheduled
        ? ` <span class="unscheduled">Not scheduled yet</span>`
        : thin
          ? ` <span class="unscheduled">Barely scheduled</span>`
          : "";
      const seat = scheduleSeat(store);
      return `<tr><td>${name}${tag}</td><td>${esc(seat.region)}</td><td>${esc(seat.division)}</td><td>${esc(seat.district)}</td><td>${esc(seat.om)}</td><td class="${toneClass(percentHealth(store.under, quiet))}">${esc(scheduleRate(store, store.under))}</td><td class="${toneClass(percentHealth(store.over, quiet))}">${esc(scheduleRate(store, store.over))}</td><td class="${toneClass(effHealth(store.eff, quiet))}">${esc(scheduleRate(store, store.eff))}</td><td>${esc(pct(store.pch))}</td><td>${esc(money(store.sales))}</td></tr>`;
    })
    .join("");
  const cards = rows
    .map((store) => {
      const unscheduled = notScheduled(store);
      const thin = barelyScheduled(store);
      const quiet = unscheduled || thin;
      const tag = unscheduled
        ? ` <span class="unscheduled">Not scheduled yet</span>`
        : thin
          ? ` <span class="unscheduled">Barely scheduled</span>`
          : "";
      return `<li class="store-card"><p class="store-id">${esc(canonicalStore(store.store))}${tag}</p><p class="sub">${esc(seatText(store))}</p><div class="metric-row"><div class="metric"><span>Under</span><strong>${esc(scheduleRate(store, store.under))}</strong></div><div class="metric"><span>Over</span><strong>${esc(scheduleRate(store, store.over))}</strong></div><div class="metric"><span>Eff</span><strong>${esc(scheduleRate(store, store.eff))}</strong></div><div class="metric"><span>Sales</span><strong>${esc(money(store.sales))}</strong></div></div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr><th>Store</th><th>Region</th><th>Division</th><th>District</th><th>OM</th><th>Under</th><th>Over</th><th>Eff</th><th>Pch</th><th>Sales</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
}

let renderToken = 0;
let paintedPage = "";

function shopperPackPath(section) {
  if (section === "pph") return "section/picker_scorecard";
  if (section === "pick_path") return "section/pick_path_picker";
  return "";
}

function shopperNote(section) {
  const path = shopperPackPath(section);
  if (!path) return "";
  if (!shopperSeat(state.filters)) {
    return `<p class="note">Shopper rows open from a division, district, OM, or store.</p>`;
  }
  if (!state.packs.has(path)) {
    if (state.failedPacks.has(path)) return `<h2>Shoppers</h2><p class="note">No shopper data</p>`;
    return `<h2>Shoppers</h2><p class="note">Loading…</p>`;
  }
  const pack = state.packs.get(path);
  const columns = SHOPPER_COLUMNS[section === "pph" ? "pph" : "path"];
  const sourceNote = section === "pph" ? "Shopper PPH, hours, and orders are from the Picker ScoreCard." : "";
  return shopperBlock((pack && pack.rows) || [], columns, sourceNote);
}

function presubNote() {
  if (state.packs.has("presub")) return renderPresub(state.packs.get("presub"));
  if (state.failedPacks.has("presub")) {
    return state.home && state.home.preSubItemTabPresent === false
      ? `<p class="note">Item detail not in this upload</p>`
      : `<p class="note">NO DATA</p>`;
  }
  return `<h2>Top 10 Pre-Sub OOS items</h2><p class="note">Loading…</p>`;
}

function scorecardHtml(page, pendingStores) {
  const health = (summaryFor(page.section) || {}).health || "none";
  const pack = state.packs.get(`section/${page.section}`);
  const missing = !pendingStores && !pack;
  const storeTable = pendingStores
    ? `<p class="note">Loading…</p>`
    : missing
      ? `<p class="note">Store rows are not in this upload.</p>`
      : table(page.section, (pack && pack.rows) || []);
  const extra = page.section === "pre_sub_oos" ? presubNote() : "";
  const shoppers = page.section === "pph" || page.section === "pick_path" ? shopperNote(page.section) : "";
  return `<article class="scorecard ${health}">${companyBlock(page.section, page.title)}</article>${grainBlock(page.section)}${extra}${storeTable}${shoppers}`;
}

function warmDashboard(token) {
  const refresh = () => {
    if (token === renderToken && state.page === "dashboard") renderDashboard();
  };
  const jobs = [];
  if (!state.packs.has("schedule") && !state.failedPacks.has("schedule")) jobs.push(loadOptional("schedule"));
  if (!state.packs.has("section/lost_revenue") && !state.failedPacks.has("section/lost_revenue")) {
    jobs.push(loadOptional("section/lost_revenue"));
  }
  for (const page of PAGES) {
    if (!page.section) continue;
    const path = `section/${page.section}`;
    if (state.packs.has(path) || state.failedPacks.has(path)) continue;
    jobs.push(loadOptional(path));
  }
  if (jobs.length) Promise.all(jobs).then(refresh);
  const pickerPath = "section/picker_scorecard";
  if (seatReady("picker_scorecard") || state.packs.has(pickerPath) || state.failedPacks.has(pickerPath)) return;
  loadOptional(pickerPath).then(refresh);
}

async function renderMetric(page, token) {
  const path = `section/${page.section}`;
  const pending = !state.packs.has(path) && !state.failedPacks.has(path);
  if (pending) {
    main.innerHTML = `<p class="note">Loading…</p>`;
    await loadOptional(path);
    if (token !== renderToken) return;
  }
  main.innerHTML = scorecardHtml(page, false);
  if (page.section === "pre_sub_oos" && !state.packs.has("presub") && !state.failedPacks.has("presub")) {
    await loadOptional("presub");
    if (token !== renderToken) return;
    main.innerHTML = scorecardHtml(page, false);
  }
  const shopperPath = shopperPackPath(page.section);
  if (shopperPath && shopperSeat(state.filters) && !state.packs.has(shopperPath) && !state.failedPacks.has(shopperPath)) {
    await loadOptional(shopperPath);
    if (token !== renderToken) return;
    main.innerHTML = scorecardHtml(page, false);
  }
}

// Home chrome paints before section files. Shopper tape stays parked until a seat opens it.
async function render() {
  const token = ++renderToken;
  const page = pageById(state.page);
  if (paintedPage !== page.id) {
    paintedPage = page.id;
    scrollChromeToTop();
  }
  title.textContent = page.title;
  renderNav();
  renderFilters();
  if (!state.home) {
    setUpdated(null);
    main.innerHTML = `<p class="nodata">NO DATA</p>`;
    return;
  }
  if (page.id === "schedule") {
    setUpdated(state.home.publishedAt);
    let pack = state.packs.get("schedule") || null;
    if (!pack && !state.failedPacks.has("schedule")) {
      main.innerHTML = `<p class="note">Loading…</p>`;
      pack = await loadOptional("schedule");
      if (token !== renderToken) return;
    }
    setUpdated((pack && pack.publishedAt) || state.home.publishedAt);
    if (pack) raiseBanner(considerPublished(sessionStorage, "hb.web.seenScheduleAt", packBannerTime(pack)));
    renderSchedule(pack);
    return;
  }
  setUpdated(packBannerTime(state.home));
  if (page.id === "dashboard") {
    renderDashboard();
    warmDashboard(token);
    return;
  }
  if (page.section === "picker_scorecard") {
    renderPicker();
    const path = "section/picker_scorecard";
    if (!state.packs.has(path) && !state.failedPacks.has(path)) {
      loadOptional(path).then(() => {
        if (token !== renderToken || state.page !== "picker_scorecard") return;
        renderPicker();
        paintBrowse();
      });
    }
    return;
  }
  await renderMetric(page, token);
}

function desktopNav() {
  return window.matchMedia("(min-width: 801px)").matches;
}

function syncNavToggle() {
  navToggle.textContent = "Pages";
  if (!desktopNav()) return;
  const collapsed = document.documentElement.classList.contains("nav-collapsed");
  navToggle.setAttribute("aria-expanded", collapsed ? "false" : "true");
}

function closeDrawer() {
  drawer.classList.remove("open");
  scrim.hidden = true;
  if (!desktopNav()) navToggle.setAttribute("aria-expanded", "false");
}

async function ensureSeatRows(pages) {
  const shared = Array.isArray(pages) ? pages : [];
  const needPicker = shared.some((page) => page.section === "picker_scorecard");
  const regionOnly =
    Boolean(state.filters.region) &&
    !state.filters.division &&
    !state.filters.district &&
    !state.filters.om &&
    !state.filters.store;
  const rendered = [];
  for (const page of shared) {
    if (page && page.id === "dashboard") rendered.push(...PAGES);
    else if (page) rendered.push(page);
  }
  const sections = [];
  const seen = new Set();
  for (const page of rendered.filter((page) => page.section && (needPicker || page.section !== "picker_scorecard"))) {
    if (seen.has(page.section)) continue;
    seen.add(page.section);
    // Region chrome already paints this seat. Load a section file only when the share has to render its rows.
    if (regionOnly && seatReady(page.section)) continue;
    sections.push(`section/${page.section}`);
  }
  await Promise.all(sections.map((path) => load(path).catch(() => null)));
}

function seatFigure(section, seat) {
  if (section === "picker_scorecard") {
    const rows = sectionRows(section);
    if (!rows) return "";
    const count = distinctShopperCount(rowsInScope(rows, state.filters, roster(), section));
    return count ? formatHeadline(section, count) : "";
  }
  let text = "";
  if (seat.headlineText != null && seat.headlineText !== "") text = String(seat.headlineText);
  else if (seat.headline != null && seat.headline !== "") text = formatHeadline(section, seat.headline);
  if (seat.figureLabel && text) return `${seat.figureLabel} ${text}`;
  return text;
}

function shareCount(section) {
  const rows = sectionRows(section);
  if (!rows) return "";
  if (section === "picker_scorecard") {
    const count = distinctShopperCount(rowsInScope(rows, state.filters, roster(), section));
    return count ? `${num(count, 0)} shoppers` : "";
  }
  const count = sectionStoreCount(rows, state.filters, roster(), section);
  return count ? `${num(count, 0)} stores` : "";
}

function companyTilePairs(section) {
  if (filtersActive(state.filters)) return [];
  const tiles = tilesFor(section);
  if (!tiles || !Array.isArray(tiles.labels) || !tiles.labels.length) return [];
  const labels = tiles.labels;
  const values = section === "lost_revenue" ? lostTileValues(labels, tiles.values || []) : tiles.values || [];
  return labels.map((label, index) => {
    const raw = values[index];
    return { label: shownTileLabel(section, label), value: shownTileValue(section, label, raw) };
  });
}

function metricShareBlock(page, withTiles) {
  const seat = seatFor(page.section);
  const secondary = companySecondaryText(page.section, seat);
  return {
    title: page.title,
    status: healthWord(seat.health || (summaryFor(page.section) || {}).health),
    count: shareCount(page.section),
    figure: seatFigure(page.section, seat),
    note: [seat.missed ? `Missed $ ${seat.missed}` : "", secondary, METRIC_NOTES[page.section]].filter(Boolean).join(" "),
    metrics: withTiles ? companyTilePairs(page.section) : [],
  };
}

function scheduleShareBlock() {
  const pack = state.packs.get("schedule");
  if (!pack || scheduleIsEmpty(pack)) return { title: "Schedule Check", note: "NO DATA" };
  const card = scheduleSummary(pack, state.filters, roster());
  return {
    title: "Schedule Check",
    status: scheduleVisibleTitle(pack.summaryTitle, pack.week) || (pack.week ? `Week ${pack.week}` : "Schedule"),
    figure: `${num(card.actionCount, 0)} to review`,
    note: "Sales at least $30,000, and under at least 10%, 4-week under above 9%, or over at least 15%.",
  };
}

function dashboardShareBlocks() {
  return PAGES.filter((page) => page.id !== "dashboard").map((page) =>
    page.id === "schedule" ? scheduleShareBlock() : metricShareBlock(page, false),
  );
}

function shareBlocksFor(page, withTiles) {
  if (page.id === "dashboard") return dashboardShareBlocks();
  if (page.id === "schedule") return [scheduleShareBlock()];
  return [metricShareBlock(page, withTiles)];
}

function shareMode() {
  const picked = document.querySelector('input[name="share-mode"]:checked');
  return picked ? picked.value : "page";
}

function paintSharePicks() {
  sharePicks.innerHTML = PAGES.map(
    (page) =>
      `<label><input type="checkbox" value="${esc(page.id)}"${page.id === state.page ? " checked" : ""}> ${esc(page.title)}</label>`,
  ).join("");
}

function shareActionLabel() {
  const mode = shareMode();
  if (mode === "all") return "Email all pages";
  if (mode === "page") return "Email this page";
  const count = sharePicks.querySelectorAll("input:checked").length;
  if (!count) return "Email";
  return count === 1 ? "Email 1 page" : `Email ${count} pages`;
}

function syncSharePicks() {
  sharePicks.hidden = shareMode() !== "pick";
  shareError.hidden = true;
  shareSend.textContent = shareActionLabel();
}

function shareOpenOnScreen() {
  return Boolean(shareRoot && shareRoot.classList.contains("is-open") && !shareRoot.hidden);
}

function clearSharePersistence() {
  const keys = ["hb.web.shareOpen", "shareOpen", "hb.share.open", "hb.web.share"];
  for (const store of [localStorage, sessionStorage]) {
    try {
      for (const key of keys) store.removeItem(key);
      for (let i = store.length - 1; i >= 0; i -= 1) {
        const key = store.key(i);
        if (key && /share/i.test(key) && /open/i.test(key)) store.removeItem(key);
      }
    } catch {
      /* private mode */
    }
  }
  try {
    const url = new URL(window.location.href);
    let changed = false;
    for (const key of ["share", "shareOpen", "share-open"]) {
      if (!url.searchParams.has(key)) continue;
      url.searchParams.delete(key);
      changed = true;
    }
    const hash = url.hash.replace(/^#/, "").toLowerCase();
    if (hash === "share" || hash === "share-open" || hash === "shareopen") {
      url.hash = "";
      changed = true;
    }
    if (changed) history.replaceState(null, "", `${url.pathname}${url.search}${url.hash}`);
  } catch {
    /* ignore a bad location */
  }
}

function forceShareClosed() {
  if (!shareRoot) return;
  shareRoot.classList.remove("is-open");
  shareRoot.hidden = true;
  clearSharePersistence();
}

let shareOpenedByUser = false;

function openShare() {
  shareOpenedByUser = true;
  shareScope.textContent = `Filters · ${scopeLabel(state.filters)}`;
  const pageRadio = document.querySelector('input[name="share-mode"][value="page"]');
  if (pageRadio) pageRadio.checked = true;
  paintSharePicks();
  syncSharePicks();
  clearSharePersistence();
  shareRoot.hidden = false;
  shareRoot.classList.add("is-open");
  shareSend.focus();
}

function closeShare() {
  forceShareClosed();
  if (shareSend) shareSend.blur();
}

async function sendShare() {
  const mode = shareMode();
  const picked = [...sharePicks.querySelectorAll("input:checked")].map((input) => input.value);
  const pages = sharePages(mode, state.page, picked, PAGES);
  if (!pages.length) {
    shareError.hidden = false;
    return;
  }
  shareError.hidden = true;
  shareSend.disabled = true;
  try {
    if (filtersActive(state.filters) && pages.some((page) => page.section || page.id === "dashboard")) {
      await ensureSeatRows(pages);
    }
    if (pages.some((page) => page.id === "schedule" || page.id === "dashboard")) {
      await load("schedule").catch(() => null);
    }
    const withTiles = pages.length === 1;
    const detailed = pages.map((page) => ({
      title: page.title,
      blocks: shareBlocksFor(page, withTiles),
    }));
    const scope = scopeLabel(state.filters);
    const subject = shareSubject(scope, packStamp);
    const plain = shareBrief({
      scope,
      stamp: packStamp,
      updated: updated.textContent,
      pages: detailed,
    });
    const html = shareHtml({
      scope,
      stamp: packStamp,
      updated: updated.textContent,
      pages: detailed,
    });
    const url = mailtoURL({ to: shareTo.value, subject, body: plain });
    shareRoot.dataset.lastMailto = url;
    shareRoot.dataset.lastEml = shareEml({ to: shareTo.value.trim(), subject, plain, html });
    closeShare();
    const file = new Blob([shareRoot.dataset.lastEml], { type: "message/rfc822" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(file);
    link.download = "Fulfillment Heartbeat.eml";
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(link.href), 1000);
    window.location.href = url;
  } finally {
    shareSend.disabled = false;
  }
}

shareOpen.addEventListener("click", openShare);
shareClose.addEventListener("click", (event) => {
  event.preventDefault();
  event.stopPropagation();
  closeShare();
});
shareSend.addEventListener("click", (event) => {
  event.stopPropagation();
  sendShare();
});
shareRoot.addEventListener("click", (event) => {
  if (event.target.closest(".share-card")) return;
  closeShare();
});
shareRoot.addEventListener("change", (event) => {
  if (event.target.name === "share-mode" || event.target.closest("#share-picks")) syncSharePicks();
});
document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return;
  if (shareOpenOnScreen()) {
    event.preventDefault();
    closeShare();
    return;
  }
  if (state.browseOpen) {
    event.preventDefault();
    state.browseOpen = false;
    paintBrowse();
  }
});
forceShareClosed();
window.addEventListener("pageshow", (event) => {
  if (event.persisted || !shareOpenedByUser) forceShareClosed();
});

clearFilters.addEventListener("click", () => {
  state.browseOpen = false;
  applyScope(emptyFilters());
});

scopeSearch.addEventListener("input", () => {
  state.scopeQuery = scopeSearch.value;
  state.browseOpen = false;
  paintResults();
  paintBrowse();
});

scopeSearch.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    state.scopeQuery = "";
    scopeSearch.value = "";
    hideResults();
  }
  if (event.key === "Enter" && searchHits[0]) {
    event.preventDefault();
    state.browseOpen = false;
    applyScope(scopeFromPick(searchHits[0]));
  }
});

scopeResults.addEventListener("mousedown", (event) => {
  event.preventDefault();
});

browseOpen.addEventListener("click", () => {
  state.browseOpen = !state.browseOpen;
  hideResults();
  paintBrowse();
});

browseClose.addEventListener("click", () => {
  state.browseOpen = false;
  paintBrowse();
});

browseRoot.addEventListener("click", (event) => {
  if (event.target.closest(".browse-card")) return;
  state.browseOpen = false;
  paintBrowse();
});

browseBack.addEventListener("click", () => {
  state.filters = parentScope(state.filters);
  state.tableWindow = ROW_PAGE;
  if (!shareRoot.hidden) shareScope.textContent = `Filters · ${scopeLabel(state.filters)}`;
  scrollChromeToTop();
  render();
});

navToggle.addEventListener("click", (event) => {
  event.stopPropagation();
  if (desktopNav()) {
    const collapsed = !document.documentElement.classList.contains("nav-collapsed");
    document.documentElement.classList.toggle("nav-collapsed", collapsed);
    try {
      sessionStorage.setItem("hb.web.navCollapsed", collapsed ? "1" : "0");
    } catch {
      /* private mode */
    }
    syncNavToggle();
    return;
  }
  const open = !drawer.classList.contains("open");
  drawer.classList.toggle("open", open);
  navToggle.setAttribute("aria-expanded", open ? "true" : "false");
  if (!open) {
    scrim.hidden = true;
    return;
  }
  // The scrim covers the button. Showing it on this same click closes the drawer immediately.
  window.setTimeout(() => {
    if (drawer.classList.contains("open")) scrim.hidden = false;
  }, 0);
});
window.addEventListener("resize", syncNavToggle);
syncNavToggle();
scrim.addEventListener("click", closeDrawer);

document.body.addEventListener("input", (event) => {
  const box = event.target.closest("[data-shopper-search]");
  if (!box) return;
  state.shopperQuery = box.value;
  state.shopperWindow = ROW_PAGE;
  paintShopperList();
});

document.body.addEventListener("click", (event) => {
  const hit = event.target.closest("[data-hit]");
  if (hit) {
    const pick = searchHits[Number(hit.getAttribute("data-hit"))];
    if (pick) {
      state.browseOpen = false;
      applyScope(scopeFromPick(pick));
    }
    return;
  }
  const drilled = event.target.closest("[data-browse]");
  if (drilled) {
    const pick = browseHits[Number(drilled.getAttribute("data-browse"))];
    if (pick) {
      if (pick.kind === "store") state.browseOpen = false;
      applyScope(scopeFromPick(pick));
    }
    return;
  }
  const chip = event.target.closest("[data-scope]");
  if (chip) {
    applyScope(filtersUpTo(state.filters, chip.getAttribute("data-scope")));
    return;
  }
  if (event.target.closest("[data-clear-scope]")) {
    state.browseOpen = false;
    applyScope(emptyFilters());
    return;
  }
  if (!event.target.closest(".find")) hideResults();
  if (state.browseOpen && !event.target.closest("#browse") && !event.target.closest("#browse-open")) {
    state.browseOpen = false;
    paintBrowse();
  }
  if (event.target.closest("[data-logout]")) {
    logout();
    return;
  }
  if (event.target.closest("[data-close-drawer]")) {
    closeDrawer();
    return;
  }
  const more = event.target.closest("[data-more]");
  if (more) {
    if (more.getAttribute("data-more") === "shoppers") {
      state.shopperWindow += ROW_PAGE;
      paintShopperList();
      return;
    }
    state.tableWindow += ROW_PAGE;
    render();
    return;
  }
  const pageButton = event.target.closest("[data-page]");
  if (pageButton) {
    const nextPage = pageButton.getAttribute("data-page");
    if (nextPage === "schedule") state.scheduleTab = "summary";
    state.page = nextPage;
    state.tableWindow = ROW_PAGE;
    state.shopperWindow = ROW_PAGE;
    state.shopperQuery = "";
    closeDrawer();
    render();
    return;
  }
  const tab = event.target.closest("[data-tab]");
  if (tab) {
    state.scheduleTab = tab.getAttribute("data-tab");
    state.tableWindow = ROW_PAGE;
    render();
  }
});

function acceptHome(home) {
  state.home = home;
  state.homeError = "";
  applyPackStamp(home && home.publishedAt);
  const staleSchema = schemaWarning(home);
  if (staleSchema) console.warn(staleSchema);
  raiseBanner(staleSchema || considerPublished(sessionStorage, "hb.web.seenPublishedAt", packBannerTime(home)), Boolean(staleSchema));
  render();
}

function retryHomeAfterAuth() {
  if (state.home) return;
  state.homeError = "";
  load("home").then(acceptHome).catch((error) => {
    if (error && error.authBlocked) {
      window.location.assign("/login");
      return;
    }
    if (!state.home) state.homeError = "";
  });
}

function applyPageQuery() {
  const url = new URL(location.href);
  const id = url.searchParams.get("page");
  if (!id || !PAGES.some((page) => page.id === id)) return;
  state.page = id;
  url.searchParams.delete("page");
  history.replaceState(null, "", `${url.pathname}${url.search}${url.hash}`);
}

function pageHasCredentials() {
  try {
    const url = new URL(location.href);
    return Boolean(url.username || url.password);
  } catch (e) {
    return false;
  }
}

if (pageHasCredentials()) {
  const url = new URL(location.href);
  url.username = "";
  url.password = "";
  location.replace(url.href);
} else {
  applyPageQuery();
  renderNav();
  loadAccountSession();
  load("home").then(acceptHome).catch((error) => {
    if (error && error.authBlocked) {
      window.location.assign("/login");
      return;
    }
    state.home = null;
    state.homeError = "";
    render();
    window.addEventListener("focus", retryHomeAfterAuth);
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") retryHomeAfterAuth();
    });
  });
}
