import { updatedLine, considerPublished, pct, money, num, formatHeadline } from "./clock.js";
import {
  emptyFilters,
  filtersActive,
  includesScope,
  regions,
  divisionsFor,
  optionValues,
  scopeLabel,
  finestScope,
  sectionGrainRows,
  canonicalStore,
  canonicalDivision,
  regionForDivision,
} from "./filters.js";
import { packURL } from "./packs.js";
import { healthWord, mailtoURL, shareBrief, sharePages, shareSubject } from "./share.js";
import { lossPercentPoints, seatSummary } from "./seat.js";
import {
  summary as scheduleSummary,
  scheduleVisibleTitle,
  companyMarketNote,
  actionGroups,
  rankedDivisions,
  rankedRegions,
  notScheduled,
  barelyScheduled,
  percentHealth,
  effHealth,
} from "./schedule-math.js";

const STAMP = "HB-0828.494";

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
    ["Missed", ["missed_sales", "reduced_capacity"], money],
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
  ],
  schedule_quality: [
    ["Sch Eff", ["schedule_efficiency_pct"], pct],
    ["Under", ["under_schedule_pct", "under_scheduled"], pct],
    ["Over", ["over_schedule_pct", "over_scheduled"], pct],
  ],
  pph: [["PPH", ["pph"], (value) => num(value, 1)]],
  labor: [
    ["Vs Target", ["target_vs_actual_pct"], pct],
    ["Act Cost", ["act_cost_pct"], pct],
    ["Cost Tgt", ["cost_trgt_pct"], pct],
    ["Sch Eff", ["schedule_efficiency_pct"], pct],
    ["UPLH", ["uplh_impact_pct"], pct],
    ["Wage", ["wage_impact_pct"], pct],
    ["AIV", ["aiv_impact_pct"], pct],
  ],
};

const ROW_PAGE = 80;

const state = {
  page: "dashboard",
  filters: emptyFilters(),
  home: null,
  homeError: "",
  packs: new Map(),
  scheduleTab: "action",
  bannerTimer: 0,
  tableWindow: ROW_PAGE,
};

const drawer = document.querySelector("#drawer");
const scrim = document.querySelector("#scrim");
const main = document.querySelector("#main");
const filtersForm = document.querySelector("#filters");
const filterToggle = document.querySelector("#filter-toggle");
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

function raiseBanner(text) {
  if (!text) return;
  banner.hidden = false;
  banner.textContent = text;
  clearTimeout(state.bannerTimer);
  state.bannerTimer = setTimeout(() => {
    banner.hidden = true;
  }, 5000);
}

async function load(path) {
  if (state.packs.has(path)) return state.packs.get(path);
  const url = packURL(path);
  if (!url) throw new Error("NO DATA");
  const response = await fetch(url, { cache: "no-store", credentials: "same-origin" });
  const type = (response.headers.get("content-type") || "").toLowerCase();
  if (!response.ok || type.includes("text/html")) throw new Error("NO DATA");
  const text = await response.text();
  const trimmed = text.trim();
  if (!trimmed || trimmed.startsWith("<")) throw new Error("NO DATA");
  let data;
  try {
    data = JSON.parse(trimmed);
  } catch {
    throw new Error("NO DATA");
  }
  if (!data || typeof data !== "object") throw new Error("NO DATA");
  state.packs.set(path, data);
  return data;
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

function renderNav() {
  const items = PAGES.map(
    (page) =>
      `<li><button type="button" data-page="${page.id}" aria-current="${page.id === state.page ? "page" : "false"}">${navIcon(page)}<span>${esc(page.title)}</span></button></li>`,
  ).join("");
  drawer.innerHTML = `<div class="drawer-head"><p class="drawer-title">Pages</p><button type="button" class="drawer-close" data-close-drawer>Close</button></div><ul class="pages">${items}</ul><p class="hint">${esc(STAMP)}</p>`;
}

function renderFilters() {
  const filters = state.filters;
  const stores = roster();
  const fields = [
    ["region", "Region", ["", ...regions()]],
    ["division", "Division", ["", ...divisionsFor(filters)]],
    ["district", "District", ["", ...optionValues(stores, filters, "district")]],
    ["om", "OM", ["", ...optionValues(stores, filters, "om")]],
    ["store", "Store", ["", ...optionValues(stores, filters, "store")]],
  ];
  filtersForm.innerHTML = fields
    .map(([key, label, values]) => {
      const options = values
        .map((value) => {
          const text = value || (key === "om" ? "All OMs" : `All ${label.toLowerCase()}s`);
          const selected = value === filters[key] ? " selected" : "";
          return `<option value="${esc(value)}"${selected}>${esc(text)}</option>`;
        })
        .join("");
      return `<label>${esc(label)}<select name="${key}">${options}</select></label>`;
    })
    .join("");
  const seat = filtersActive(filters) ? scopeLabel(filters) : "Total Company";
  filterToggle.textContent = `Filters · ${seat}`;
  if (clearFilters) {
    clearFilters.textContent = "Clear all";
    clearFilters.hidden = !filtersActive(filters);
  }
}

function setUpdated(raw) {
  updated.textContent = updatedLine(raw);
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

function cookedTiles(section) {
  const tiles = tilesFor(section);
  if (!tiles || !Array.isArray(tiles.labels) || !tiles.labels.length) return "";
  const labels = tiles.labels;
  const values = section === "lost_revenue" ? lostTileValues(labels, tiles.values || []) : tiles.values || [];
  return `<div class="tiles">${labels
    .map((label, index) => {
      const raw = values[index];
      const shown = raw == null || raw === "" ? "—" : String(raw).trim().startsWith("$") ? money(raw) : String(raw);
      const name = shown.startsWith("$") ? String(label || "").replace(/\s*\$+\s*$/, "") : label;
      return `<div class="chip"><span>${esc(name)}</span><strong>${esc(shown)}</strong></div>`;
    })
    .join("")}</div>`;
}

function seatFor(section) {
  const pack = state.packs.get(`section/${section}`);
  return seatSummary(section, {
    company: summaryFor(section),
    lines: (state.home && state.home.regionLines) || [],
    rows: (pack && pack.rows) || [],
    filters: state.filters,
    roster: roster(),
  });
}

function shownSecondary(section, text) {
  if (section !== "schedule_quality" || !text) return text || "";
  return String(text).replace(
    /(\d[\d,]*) of (\d[\d,]*) at 90% · (\d[\d,]*) under · (\d[\d,]*) over/,
    "$1 of $2 at 90% · $3 stores under above 5% · $4 stores over above 5%",
  );
}

function companyBlock(section, title) {
  const seat = seatFor(section);
  const tiles = filtersActive(state.filters) ? "" : cookedTiles(section);
  if (!summaryFor(section) && !tiles && !filtersActive(state.filters)) return `<p class="nodata">NO DATA</p>`;
  const health = seat.health || "none";
  const hideEmptyBadge = section === "picker_scorecard" && seat.storeCount > 0 && health === "none";
  const name = title ? `<h2>${esc(title)}</h2>` : "";
  const countLabel = !seat.storeCount
    ? ""
    : !seat.fixedCompany && section === "picker_scorecard"
      ? `${num(seat.storeCount, 0)} shoppers`
      : `${num(seat.storeCount, 0)} stores`;
  const figureText =
    seat.headlineText != null && seat.headlineText !== ""
      ? seat.headlineText
      : seat.headline != null && seat.headline !== ""
        ? formatHeadline(section, seat.headline)
        : filtersActive(state.filters)
          ? "—"
          : "";
  const figure = !tiles && figureText ? `<p class="figure">${esc(figureText)}</p>` : "";
  const secondaryText = shownSecondary(section, seat.secondary);
  const secondary = secondaryText ? `<p class="secondary">${esc(secondaryText)}</p>` : "";
  const scope = filtersActive(state.filters)
    ? `<p class="scope">In this scope: ${esc(countLabel || "no cooked grade")}.</p>`
    : "";
  return `<div class="score-face">${name}${hideEmptyBadge ? "" : badge(health)}${countLabel ? `<p class="sub">${esc(countLabel)}</p>` : ""}${figure}${tiles}${secondary}${scope}</div>`;
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

function table(section, rows) {
  const columns = COLUMNS[section] || [];
  const known = rosterByStore();
  const matched = rows.filter((row) => row.store && includesScope(row, state.filters, roster()));
  if (!matched.length) return `<p class="note">No stores in this scope.</p>`;
  const shown = matched.slice(0, state.tableWindow);
  const head = ["Store", "Division", "District", "OM", ...columns.map((column) => column[0])]
    .map((label) => `<th>${esc(label)}</th>`)
    .join("");
  const body = shown
    .map((row) => {
      const metrics = columns
        .map((column) => `<td>${esc(column[2](cell(row, column[1]), row))}</td>`)
        .join("");
      const division = displayDivision(row, known);
      return `<tr><td>${esc(canonicalStore(row.store))}</td><td>${esc(division)}</td><td>${esc(row.district || "—")}</td><td>${esc(row.om || "—")}</td>${metrics}</tr>`;
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
            `<div class="metric"><span>${esc(column[0])}</span><strong>${esc(column[2](cell(row, column[1]), row))}</strong></div>`,
        )
        .join("");
      const division = displayDivision(row, known);
      return `<li class="store-card"><p class="store-id">${esc(canonicalStore(row.store))}</p><p class="sub">${esc(division)} · ${esc(row.district || "—")} · ${esc(row.om || "—")}</p><div class="metric-row">${metrics}</div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
}

function grainBlock(section) {
  const rows = sectionGrainRows(
    (state.home && state.home.regionLines) || [],
    section,
    state.filters,
    roster(),
  );
  if (!rows.length) return "";
  const body = rows
    .map(
      (row) =>
        `<tr><td>${esc(row.grain === "region" ? "Region" : "Division")}</td><td>${esc(row.label)}</td><td>${esc(row.value)}</td><td>${esc(row.count)}</td></tr>`,
    )
    .join("");
  const cards = rows
    .map((row) => {
      const extra = String(row.value ?? "").replace(/[^\d]/g, "") === String(row.count ?? "") ? "" : `<span>${esc(row.count)}</span>`;
      return `<li class="line-card"><div><p class="eyebrow">${esc(row.grain === "region" ? "Region" : "Division")}</p><p class="line-title">${esc(row.label)}</p></div><div class="line-value"><strong>${esc(row.value)}</strong>${extra}</div></li>`;
    })
    .join("");
  const heading = filtersActive(state.filters) ? scopeLabel(state.filters) : "Regions";
  return `<section class="grain"><h2>${esc(heading)}</h2><div class="desk-only scroll"><table><thead><tr><th>Grain</th><th>Name</th><th>Value</th><th>Count</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only line-cards">${cards}</ul></section>`;
}

const REGION_CARD_ORDER = ["East", "South", "California", "West"];

function worstHealth(rows) {
  const rank = { risk: 3, watch: 2, good: 1, none: 0 };
  let tone = "none";
  for (const row of rows) {
    const health = row.health || "none";
    if ((rank[health] || 0) > (rank[tone] || 0)) tone = health;
  }
  return tone;
}

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
      const sales = rows.find((row) => row.section === "sales");
      const storeCount = sales && sales.storeCount
        ? sales.storeCount
        : rows.reduce((max, row) => (row.section === "picker_scorecard" ? max : Math.max(max, Number(row.storeCount) || 0)), 0);
      const chips = rows
        .map((row) => {
          const raw = row.headline;
          const shown = raw == null || raw === "" ? "—" : String(raw).trim().startsWith("$") ? money(raw) : String(raw);
          return `<div class="chip"><span>${esc(row.title)}</span><strong>${esc(shown)}</strong></div>`;
        })
        .join("");
      const health = worstHealth(rows);
      return `<article class="scorecard ${health}"><div class="score-face"><h2>${esc(name)}</h2>${badge(health)}${storeCount ? `<p class="sub">${esc(num(storeCount, 0))} stores</p>` : ""}<div class="tiles">${chips}</div></div></article>`;
    })
    .join("");
  if (!cards) return "";
  const note =
    state.filters.district || state.filters.om || state.filters.store
      ? `<p class="note">District, OM, and store seats stay on the store rows.</p>`
      : "";
  return `<section class="region-cards" id="pack-lines"><h2>Regions</h2>${note}${cards}</section>`;
}

function scheduleDashCard(pack) {
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

function shopperTable(rows, kind) {
  const matched = (rows || []).filter((row) => row.store && includesScope(row, state.filters, roster()));
  if (!matched.length) return `<p class="note">No shopper rows in this scope.</p>`;
  const shown = matched.slice(0, state.tableWindow);
  const more =
    matched.length > shown.length
      ? `<p class="note">${num(shown.length, 0)} of ${num(matched.length, 0)} shoppers</p><button type="button" class="more" data-more="1">Show more</button>`
      : `<p class="note">${num(matched.length, 0)} shoppers in this scope.</p>`;
  const columns =
    kind === "path"
      ? [
          ["Path %", ["compliance_pct"], pct],
          ["PPH", ["pph"], (value) => num(value, 1)],
          ["Orders", ["orders"], (value) => num(value, 0)],
        ]
      : [
          ["PPH", ["pph"], (value) => num(value, 1)],
          ["Presub", ["presub_pct"], pct],
          ["OOS", ["oos_pct"], pct],
          ["Hours", ["pick_hours"], (value) => num(value, 1)],
          ["Orders", ["orders"], (value) => num(value, 0)],
          ["OTT", ["ott_pct"], pct],
          ["OTH", ["oth5_pct"], pct],
          ["COE", ["coe_pct"], pct],
        ];
  const head = ["Shopper", "Store", ...columns.map((column) => column[0])]
    .map((label) => `<th>${esc(label)}</th>`)
    .join("");
  const body = shown
    .map((row) => {
      const metrics = columns.map((column) => `<td>${esc(column[2](cell(row, column[1])))}</td>`).join("");
      const name = row.shopper || row.shopperId || "—";
      return `<tr><td>${esc(name)}</td><td>${esc(canonicalStore(row.store))}</td>${metrics}</tr>`;
    })
    .join("");
  const cards = shown
    .map((row) => {
      const metrics = columns
        .map(
          (column) =>
            `<div class="metric"><span>${esc(column[0])}</span><strong>${esc(column[2](cell(row, column[1]), row))}</strong></div>`,
        )
        .join("");
      const name = row.shopper || row.shopperId || "—";
      return `<li class="store-card"><p class="store-id">${esc(name)}</p><p class="sub">Store ${esc(canonicalStore(row.store))}</p><div class="metric-row">${metrics}</div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
}

function renderPicker() {
  const summary = summaryFor("picker_scorecard");
  const pack = state.packs.get("section/picker_scorecard");
  const rows = (pack && pack.rows) || [];
  if (!summary && !tilesFor("picker_scorecard") && !rows.length && !filtersActive(state.filters)) {
    main.innerHTML = `<p class="nodata">NO DATA</p>`;
    return;
  }
  const health = rows.length && ((summary && summary.health) || "none") === "none" ? "" : (summary && summary.health) || "none";
  const note = shopperSeat(state.filters)
    ? shopperTable(rows, "scorecard")
    : `<p class="note">Shopper rows open from a division, district, OM, or store.</p>`;
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
  return ["action", "summary", "detail"]
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
  const week = pack.week ? `Week ${pack.week}` : summaryTitle || "Schedule";
  const hero = `<article class="scorecard"><div class="score-face"><h2>Schedule Check</h2><p class="sub">${esc(week)}</p><p class="figure">${esc(num(card.actionCount, 0))} to review</p><p class="secondary">Sales at least $30,000, and under at least 10%, 4-week under above 9%, or over at least 15%. Not scheduled yet and barely scheduled stay off this list.</p><p class="note">Summary “Any under” counts stores above 0% this week. Schedule Quality counts stores under above 5%.</p></div></article>`;
  let body = "";
  if (state.scheduleTab === "summary") body = scheduleSummaryHtml(pack, card);
  else if (state.scheduleTab === "detail") body = scheduleDetailHtml(pack);
  else body = scheduleActionHtml(pack, card);
  main.innerHTML = `${hero}${tabs}${body}`;
}

function scheduleSeat(store) {
  const known = rosterByStore().get(canonicalStore(store.store)) || {};
  return {
    division: canonicalDivision(known.division || store.division) || known.division || store.division || "—",
    district: known.district || store.district || "—",
    om: known.om || store.om || "—",
  };
}

function seatText(store) {
  const seat = scheduleSeat(store);
  return `${seat.division} · ${seat.district} · ${seat.om}`;
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
              return `<tr><td>${esc(store.store)}</td><td>${esc(seat.division)}</td><td>${esc(seat.district)}</td><td>${esc(seat.om)}</td><td>${esc(pct(store.under))}</td><td>${esc(pct(store.over))}</td><td>${esc(whyFlags(store))}</td></tr>`;
            })
            .join("");
          const cards = group.stores
            .slice(0, 80)
            .map(
              (store) =>
                `<li class="store-card"><p class="store-id">${esc(store.store)}</p><p class="sub">${esc(seatText(store))}</p><div class="metric-row"><div class="metric"><span>Under</span><strong>${esc(pct(store.under))}</strong></div><div class="metric"><span>Over</span><strong>${esc(pct(store.over))}</strong></div><div class="metric"><span>Why</span><strong>${esc(whyFlags(store))}</strong></div></div></li>`,
            )
            .join("");
          return `<section class="group"><h3>${esc(canonicalDivision(group.division) || group.division || "—")} · ${group.stores.length}</h3><div class="desk-only scroll"><table><thead><tr><th>Store</th><th>Division</th><th>District</th><th>OM</th><th>Under</th><th>Over</th><th>Why</th></tr></thead><tbody>${rows}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul></section>`;
        })
        .join("")
    : `<p class="note">No stores qualify in this scope.</p>`;
  const countLabel = `${card.actionCount} to review`;
  return `<p class="note">${countLabel}. Sales at least $30,000, and under at least 10%, 4-week under above 9%, or over at least 15%.</p>${groupsHtml}`;
}

function scheduleSummaryHtml(pack, card) {
  const kpis = [
    ["Under", pct(card.under), percentHealth(card.under, false)],
    ["Over", pct(card.over), percentHealth(card.over, false)],
    ["Pch vs Sch", pct(card.pch), ""],
    ["Sch Eff", pct(card.eff), effHealth(card.eff, false)],
    ["Any under", num(card.underCount, 0), ""],
    ["Any over", num(card.overCount, 0), ""],
    ["Stores", num(card.scope, 0), ""],
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
        `<tr><td>${esc(row.division)}</td><td>${esc(pct(row.under))}</td><td>${esc(pct(row.over))}</td><td>${esc(pct(row.eff))}</td><td>${esc(num(row.scope, 0))}</td></tr>`,
    )
    .join("");
  const regionRows = rankedRegions(pack, state.filters, roster())
    .map(
      (row) =>
        `<tr><td>${esc(row.region)}</td><td>${esc(pct(row.under))}</td><td>${esc(pct(row.over))}</td><td>${esc(pct(row.eff))}</td><td>${esc(num(row.scope, 0))}</td></tr>`,
    )
    .join("");
  const regionCards = rankedRegions(pack, state.filters, roster())
    .map(
      (row) =>
        `<li class="line-card"><div><p class="eyebrow">Region</p><p class="line-title">${esc(row.region)}</p></div><div class="line-value"><strong>${esc(pct(row.under))} under</strong><span>${esc(pct(row.over))} over · ${esc(num(row.scope, 0))} stores</span></div></li>`,
    )
    .join("");
  const divisionCards = rankedDivisions(pack, state.filters, roster())
    .map(
      (row) =>
        `<li class="line-card"><div><p class="eyebrow">Division</p><p class="line-title">${esc(row.division)}</p></div><div class="line-value"><strong>${esc(pct(row.under))} under</strong><span>${esc(pct(row.over))} over · ${esc(num(row.scope, 0))} stores</span></div></li>`,
    )
    .join("");
  return `<div class="tiles">${kpis}</div><p class="note">Any under: stores on this week above 0% under. Not the review list, and not Schedule Quality’s stores under above 5%.</p>${market ? `<p class="note">${esc(market)}</p>` : ""}<h2>Regions</h2><div class="desk-only scroll"><table><thead><tr><th>Region</th><th>Under</th><th>Over</th><th>Eff</th><th>Stores</th></tr></thead><tbody>${regionRows}</tbody></table></div><ul class="phone-only line-cards">${regionCards}</ul><h2>Divisions</h2><div class="desk-only scroll"><table><thead><tr><th>Division</th><th>Under</th><th>Over</th><th>Eff</th><th>Stores</th></tr></thead><tbody>${divisions}</tbody></table></div><ul class="phone-only line-cards">${divisionCards}</ul>`;
}

function scheduleDetailHtml(pack) {
  const matched = (pack.stores || []).filter((store) => includesScope(store, state.filters, roster()));
  if (!matched.length) return `<p class="note">No stores in this scope.</p>`;
  const rows = matched.slice(0, state.tableWindow);
  const more =
    matched.length > rows.length
      ? `<p class="note">${num(rows.length, 0)} of ${num(matched.length, 0)} stores</p><button type="button" class="more" data-more="1">Show more</button>`
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
      return `<tr><td>${name}${tag}</td><td>${esc(seat.division)}</td><td>${esc(seat.district)}</td><td>${esc(seat.om)}</td><td class="${toneClass(percentHealth(store.under, quiet))}">${esc(pct(store.under))}</td><td class="${toneClass(percentHealth(store.over, quiet))}">${esc(pct(store.over))}</td><td class="${toneClass(effHealth(store.eff, quiet))}">${esc(pct(store.eff))}</td><td>${esc(pct(store.pch))}</td><td>${esc(money(store.sales))}</td></tr>`;
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
      return `<li class="store-card"><p class="store-id">${esc(canonicalStore(store.store))}${tag}</p><p class="sub">${esc(seatText(store))}</p><div class="metric-row"><div class="metric"><span>Under</span><strong>${esc(pct(store.under))}</strong></div><div class="metric"><span>Over</span><strong>${esc(pct(store.over))}</strong></div><div class="metric"><span>Eff</span><strong>${esc(pct(store.eff))}</strong></div><div class="metric"><span>Sales</span><strong>${esc(money(store.sales))}</strong></div></div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr><th>Store</th><th>Division</th><th>District</th><th>OM</th><th>Under</th><th>Over</th><th>Eff</th><th>Pch</th><th>Sales</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
}

let renderToken = 0;
let paintedPage = "";

async function render() {
  const token = ++renderToken;
  const page = pageById(state.page);
  if (paintedPage !== page.id) {
    paintedPage = page.id;
    window.scrollTo(0, 0);
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
    main.innerHTML = `<p class="note">Loading…</p>`;
    try {
      const pack = await load("schedule");
      if (token !== renderToken) return;
      setUpdated(pack.publishedAt || state.home.publishedAt);
      raiseBanner(considerPublished(sessionStorage, "hb.web.seenScheduleAt", pack.publishedAt));
      renderSchedule(pack);
    } catch {
      if (token !== renderToken) return;
      setUpdated(state.home.publishedAt);
      renderSchedule(null);
    }
    return;
  }
  setUpdated(state.home.publishedAt);
  if (filtersActive(state.filters)) {
    main.innerHTML = `<p class="note">Loading…</p>`;
    await ensureSeatRows();
    if (token !== renderToken) return;
  }
  if (page.id === "dashboard") {
    renderDashboard();
    if (!state.packs.has("schedule")) {
      load("schedule")
        .then(() => {
          if (token === renderToken && state.page === "dashboard") renderDashboard();
        })
        .catch(() => {});
    }
    return;
  }
  if (page.section === "picker_scorecard") {
    main.innerHTML = `<p class="note">Loading…</p>`;
    try {
      await load("section/picker_scorecard");
    } catch {
      /* company chrome still paints when the shopper file is missing */
    }
    if (token !== renderToken) return;
    renderPicker();
    return;
  }
  if (!filtersActive(state.filters)) {
    main.innerHTML = `${companyBlock(page.section)}<p class="note">Loading…</p>`;
  }
  let rows = [];
  let missing = false;
  try {
    const pack = await load(`section/${page.section}`);
    if (token !== renderToken) return;
    rows = pack.rows || [];
  } catch {
    missing = true;
  }
  let extra = "";
  if (page.section === "pre_sub_oos") {
    try {
      const presub = await load("presub");
      if (token !== renderToken) return;
      extra = renderPresub(presub);
    } catch {
      extra = state.home.preSubItemTabPresent === false
        ? `<p class="note">Item detail not in this upload</p>`
        : `<p class="note">NO DATA</p>`;
    }
  }
  let shoppers = "";
  if (page.section === "pick_path" && shopperSeat(state.filters)) {
    try {
      const pathShoppers = await load("section/pick_path_picker");
      if (token !== renderToken) return;
      shoppers = `<h2>Shoppers</h2>${shopperTable((pathShoppers && pathShoppers.rows) || [], "path")}`;
    } catch {
      shoppers = "";
    }
  }
  if (token !== renderToken) return;
  const storeTable = missing
    ? `<p class="note">Store rows are not in this upload.</p>`
    : table(page.section, rows);
  const health = (summaryFor(page.section) || {}).health || "none";
  main.innerHTML = `<article class="scorecard ${health}">${companyBlock(page.section, page.title)}</article>${grainBlock(page.section)}${extra}${storeTable}${shoppers}`;
}

function desktopNav() {
  return window.matchMedia("(min-width: 801px)").matches;
}

function syncNavToggle() {
  if (!desktopNav()) {
    navToggle.textContent = "Pages";
    return;
  }
  const collapsed = document.documentElement.classList.contains("nav-collapsed");
  navToggle.textContent = collapsed ? "Pages" : "Hide pages";
  navToggle.setAttribute("aria-expanded", collapsed ? "false" : "true");
}

function closeDrawer() {
  drawer.classList.remove("open");
  scrim.hidden = true;
  if (!desktopNav()) navToggle.setAttribute("aria-expanded", "false");
}

async function ensureSeatRows() {
  await Promise.all(
    PAGES.filter((page) => page.section).map((page) => load(`section/${page.section}`).catch(() => null)),
  );
}

function seatFigure(section, seat) {
  if (seat.headlineText != null && seat.headlineText !== "") return String(seat.headlineText);
  if (seat.headline != null && seat.headline !== "") return formatHeadline(section, seat.headline);
  return "";
}

function shareCount(section, seat) {
  if (!seat || !seat.storeCount) return "";
  const label = section === "picker_scorecard" ? "shoppers" : "stores";
  return `${num(seat.storeCount, 0)} ${label}`;
}

function companyTileLine(section) {
  if (filtersActive(state.filters)) return "";
  const tiles = tilesFor(section);
  if (!tiles || !Array.isArray(tiles.labels) || !tiles.labels.length) return "";
  const labels = tiles.labels;
  const values = section === "lost_revenue" ? lostTileValues(labels, tiles.values || []) : tiles.values || [];
  return labels
    .map((label, index) => {
      const raw = values[index];
      const shown = raw == null || raw === "" ? "—" : String(raw);
      return `${label} ${shown}`;
    })
    .join(" · ");
}

function metricShareDetail(page, withTiles) {
  const seat = seatFor(page.section);
  const health = healthWord(seat.health || (summaryFor(page.section) || {}).health);
  const head = [health, shareCount(page.section, seat), seatFigure(page.section, seat)].filter(Boolean).join(" · ");
  const secondary = shownSecondary(page.section, seat.secondary);
  const tiles = withTiles ? companyTileLine(page.section) : "";
  return [head, secondary, tiles].filter(Boolean).join("\n");
}

function scheduleShareDetail() {
  const pack = state.packs.get("schedule");
  if (!pack || scheduleIsEmpty(pack)) return "NO DATA";
  const card = scheduleSummary(pack, state.filters, roster());
  const week = pack.week ? `Week ${pack.week}` : "Schedule";
  return `${week} · ${num(card.actionCount, 0)} to review`;
}

function dashboardShareDetail(withTiles) {
  return PAGES.filter((page) => page.id !== "dashboard")
    .map((page) => {
      if (page.id === "schedule") return `Schedule Check · ${scheduleShareDetail()}`;
      const line = metricShareDetail(page, withTiles).split("\n")[0];
      return `${page.title} · ${line}`;
    })
    .join("\n");
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
  return shareRoot && !shareRoot.hidden;
}

function openShare() {
  shareScope.textContent = `Filters · ${scopeLabel(state.filters)}`;
  const pageRadio = document.querySelector('input[name="share-mode"][value="page"]');
  if (pageRadio) pageRadio.checked = true;
  paintSharePicks();
  syncSharePicks();
  shareRoot.hidden = false;
  shareSend.focus();
}

function closeShare() {
  if (!shareRoot) return;
  shareRoot.hidden = true;
  shareSend.blur();
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
      await ensureSeatRows();
    }
    if (pages.some((page) => page.id === "schedule" || page.id === "dashboard")) {
      await load("schedule").catch(() => null);
    }
    const withTiles = pages.length === 1;
    const detailed = pages.map((page) => ({
      title: page.title,
      detail:
        page.id === "dashboard"
          ? dashboardShareDetail(false)
          : page.id === "schedule"
            ? scheduleShareDetail()
            : metricShareDetail(page, withTiles),
    }));
    const scope = scopeLabel(state.filters);
    const url = mailtoURL({
      to: shareTo.value,
      subject: shareSubject(scope, STAMP),
      body: shareBrief({
        scope,
        stamp: STAMP,
        updated: updated.textContent,
        pages: detailed,
      }),
    });
    shareRoot.dataset.lastMailto = url;
    closeShare();
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
  if (event.key === "Escape" && shareOpenOnScreen()) {
    event.preventDefault();
    closeShare();
  }
});

clearFilters.addEventListener("click", () => {
  state.filters = emptyFilters();
  state.tableWindow = ROW_PAGE;
  render();
});

filterToggle.addEventListener("click", () => {
  const open = filtersForm.classList.toggle("open");
  filterToggle.setAttribute("aria-expanded", open ? "true" : "false");
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

document.body.addEventListener("click", (event) => {
  if (event.target.closest("[data-close-drawer]")) {
    closeDrawer();
    return;
  }
  const more = event.target.closest("[data-more]");
  if (more) {
    state.tableWindow += ROW_PAGE;
    render();
    return;
  }
  const pageButton = event.target.closest("[data-page]");
  if (pageButton) {
    state.page = pageButton.getAttribute("data-page");
    state.tableWindow = ROW_PAGE;
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

filtersForm.addEventListener("change", (event) => {
  const select = event.target;
  if (!select.name) return;
  const next = { ...state.filters, [select.name]: select.value };
  if (select.name === "region") {
    next.division = "";
    next.district = "";
    next.om = "";
    next.store = "";
  } else if (select.name === "division") {
    next.district = "";
    next.om = "";
    next.store = "";
  } else if (select.name === "district") {
    next.om = "";
    next.store = "";
  } else if (select.name === "om") {
    next.store = "";
  }
  state.filters = next;
  state.tableWindow = ROW_PAGE;
  if (!shareRoot.hidden) shareScope.textContent = `Filters · ${scopeLabel(next)}`;
  render();
});

renderNav();
load("home")
  .then((home) => {
    state.home = home;
    raiseBanner(considerPublished(sessionStorage, "hb.web.seenPublishedAt", home.publishedAt));
  })
  .catch(() => {
    state.homeError = "NO DATA";
  })
  .finally(render);
