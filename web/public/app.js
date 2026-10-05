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
} from "./filters.js";
import { packURL } from "./packs.js";
import { seatSummary } from "./seat.js";
import {
  summary as scheduleSummary,
  scheduleVisibleTitle,
  companyMarketNote,
  actionGroups,
  rankedDivisions,
  rankedRegions,
  notScheduled,
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
    ["Lost %", ["lost_revenue_pct"], pct],
    ["eComm", ["ecomm_sales"], money],
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

function renderNav() {
  const items = PAGES.map(
    (page) =>
      `<li><button type="button" data-page="${page.id}" aria-current="${page.id === state.page ? "page" : "false"}">${esc(page.title)}</button></li>`,
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

function cookedTiles(section) {
  const tiles = tilesFor(section);
  if (!tiles || !Array.isArray(tiles.labels) || !tiles.labels.length) return "";
  return `<div class="tiles">${tiles.labels
    .map((label, index) => {
      const raw = (tiles.values || [])[index];
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
  const secondary = seat.secondary ? `<p class="secondary">${esc(seat.secondary)}</p>` : "";
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
        .map((column) => `<td>${esc(column[2](cell(row, column[1])))}</td>`)
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
            `<div class="metric"><span>${esc(column[0])}</span><strong>${esc(column[2](cell(row, column[1])))}</strong></div>`,
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
    .map(
      (row) =>
        `<li class="line-card"><div><p class="eyebrow">${esc(row.grain === "region" ? "Region" : "Division")}</p><p class="line-title">${esc(row.label)}</p></div><div class="line-value"><strong>${esc(row.value)}</strong><span>${esc(row.count)}</span></div></li>`,
    )
    .join("");
  const heading = filtersActive(state.filters) ? scopeLabel(state.filters) : "Regions";
  return `<section class="grain"><h2>${esc(heading)}</h2><div class="desk-only scroll"><table><thead><tr><th>Grain</th><th>Name</th><th>Value</th><th>Count</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only line-cards">${cards}</ul></section>`;
}

function proofRows() {
  const filters = state.filters;
  if (filters.district || filters.om || filters.store) return [];
  const lines = (state.home && state.home.regionLines) || [];
  const sections = [];
  const seen = new Set();
  for (const line of lines) {
    if (!line || seen.has(line.section)) continue;
    seen.add(line.section);
    sections.push(line.section);
  }
  const rows = [];
  for (const section of sections) {
    let grain = sectionGrainRows(lines, section, filters, roster());
    if (!filtersActive(filters)) grain = grain.filter((row) => row.grain === "region");
    const title = (lines.find((line) => line.section === section) || {}).title || section;
    for (const row of grain) rows.push({ ...row, title });
  }
  return rows;
}

function regionProof() {
  const lines = proofRows();
  const narrowed = filtersActive(state.filters);
  const note =
    state.filters.district || state.filters.om || state.filters.store
      ? `<p class="note">District, OM, and store seats stay on the store rows. No averaged grade.</p>`
      : narrowed && !lines.length
        ? `<p class="note">No rows in this scope.</p>`
        : "";
  if (!lines.length && !narrowed) return "";
  const rows = lines
    .map(
      (line) =>
        `<tr><td>${esc(line.grain === "division" ? "Division" : "Region")}</td><td>${esc(line.title)}</td><td>${esc(line.label)}</td><td>${esc(line.value)}</td><td>${esc(line.count)}</td></tr>`,
    )
    .join("");
  const cards = lines
    .map(
      (line) =>
        `<li class="line-card"><div><p class="eyebrow">${esc(line.grain === "division" ? "Division" : line.label)}</p><p class="line-title">${esc(line.title)}${line.grain === "division" ? ` · ${esc(line.label)}` : ""}</p></div><div class="line-value"><strong>${esc(line.value)}</strong><span>${esc(line.count)}</span></div></li>`,
    )
    .join("");
  const table = lines.length
    ? `<div class="desk-only scroll"><table><thead><tr><th>Grain</th><th>Metric</th><th>Name</th><th>Value</th><th>Count</th></tr></thead><tbody>${rows}</tbody></table></div><ul class="phone-only line-cards">${cards}</ul>`
    : "";
  // Region results. Not Upcoming Weeks Schedule Check — that page is in Pages.
  return `<section id="pack-lines"><h2>Region results</h2>${note}${table}</section>`;
}

function renderDashboard() {
  const cards = PAGES.filter((page) => page.section)
    .map((page) => {
      const health = (summaryFor(page.section) || {}).health || "none";
      return `<article class="scorecard ${health}"><button class="link" type="button" data-page="${page.id}">${companyBlock(page.section, page.title)}</button></article>`;
    })
    .join("");
  main.innerHTML = `<div class="cards">${cards}</div>${regionProof()}`;
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
            `<div class="metric"><span>${esc(column[0])}</span><strong>${esc(column[2](cell(row, column[1])))}</strong></div>`,
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
  const week = pack.week ? `Week ${esc(pack.week)}` : summaryTitle || "Schedule";
  let body = "";
  if (state.scheduleTab === "summary") body = scheduleSummaryHtml(pack, card);
  else if (state.scheduleTab === "detail") body = scheduleDetailHtml(pack);
  else body = scheduleActionHtml(pack, card);
  main.innerHTML = `<p class="note">${week}</p>${tabs}${body}`;
}

function scheduleActionHtml(pack, card) {
  const groups = actionGroups(pack, state.filters, roster());
  const groupsHtml = groups.length
    ? groups
        .map((group) => {
          const rows = group.stores
            .slice(0, 80)
            .map((store) => {
              const flags = [];
              if (Number(store.under) >= 10) flags.push("under");
              if (store.fourUnder != null && Number(store.fourUnder) - 9 > 0.0001) flags.push("4-week");
              if (Number(store.over) >= 15) flags.push("over");
              return `<tr><td>${esc(store.store)}</td><td class="${toneClass(percentHealth(store.under, notScheduled(store)))}">${esc(pct(store.under))}</td><td class="${toneClass(percentHealth(store.over, notScheduled(store)))}">${esc(pct(store.over))}</td><td>${esc(flags.join(", ") || "—")}</td></tr>`;
            })
            .join("");
          const cards = group.stores
            .slice(0, 80)
            .map((store) => {
              const flags = [];
              if (Number(store.under) >= 10) flags.push("under");
              if (store.fourUnder != null && Number(store.fourUnder) - 9 > 0.0001) flags.push("4-week");
              if (Number(store.over) >= 15) flags.push("over");
              return `<li class="store-card"><p class="store-id">${esc(store.store)}</p><div class="metric-row"><div class="metric"><span>Under</span><strong>${esc(pct(store.under))}</strong></div><div class="metric"><span>Over</span><strong>${esc(pct(store.over))}</strong></div><div class="metric"><span>Why</span><strong>${esc(flags.join(", ") || "—")}</strong></div></div></li>`;
            })
            .join("");
          return `<section class="group"><h3>${esc(canonicalDivision(group.division) || group.division || "—")} · ${group.stores.length}</h3><div class="desk-only scroll"><table><thead><tr><th>Store</th><th>Under</th><th>Over</th><th>Why</th></tr></thead><tbody>${rows}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul></section>`;
        })
        .join("")
    : `<p class="note">No stores qualify in this scope.</p>`;
  const countLabel = `${card.actionCount} ${card.actionCount === 1 ? "store" : "stores"}`;
  return `<p class="note">${countLabel}</p>${groupsHtml}`;
}

function scheduleSummaryHtml(pack, card) {
  const kpis = [
    ["Under", pct(card.under), percentHealth(card.under, false)],
    ["Over", pct(card.over), percentHealth(card.over, false)],
    ["Pch vs Sch", pct(card.pch), ""],
    ["Sch Eff", pct(card.eff), effHealth(card.eff, false)],
    ["# Under", num(card.underCount, 0), ""],
    ["# Over", num(card.overCount, 0), ""],
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
  return `<div class="tiles">${kpis}</div>${market ? `<p class="note">${esc(market)}</p>` : ""}<h2>Regions</h2><div class="desk-only scroll"><table><thead><tr><th>Region</th><th>Under</th><th>Over</th><th>Eff</th><th>Stores</th></tr></thead><tbody>${regionRows}</tbody></table></div><ul class="phone-only line-cards">${regionCards}</ul><h2>Divisions</h2><div class="desk-only scroll"><table><thead><tr><th>Division</th><th>Under</th><th>Over</th><th>Eff</th><th>Stores</th></tr></thead><tbody>${divisions}</tbody></table></div><ul class="phone-only line-cards">${divisionCards}</ul>`;
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
      const name = esc(canonicalStore(store.store));
      const tag = unscheduled ? ` <span class="unscheduled">Not scheduled yet</span>` : "";
      return `<tr><td>${name}${tag}</td><td>${esc(canonicalDivision(store.division) || store.division || "—")}</td><td class="${toneClass(percentHealth(store.under, unscheduled))}">${esc(pct(store.under))}</td><td class="${toneClass(percentHealth(store.over, unscheduled))}">${esc(pct(store.over))}</td><td class="${toneClass(effHealth(store.eff, unscheduled))}">${esc(pct(store.eff))}</td><td>${esc(pct(store.pch))}</td><td>${esc(money(store.sales))}</td></tr>`;
    })
    .join("");
  const cards = rows
    .map((store) => {
      const unscheduled = notScheduled(store);
      const tag = unscheduled ? ` <span class="unscheduled">Not scheduled yet</span>` : "";
      return `<li class="store-card"><p class="store-id">${esc(canonicalStore(store.store))}${tag}</p><p class="sub">${esc(canonicalDivision(store.division) || store.division || "—")}</p><div class="metric-row"><div class="metric"><span>Under</span><strong>${esc(pct(store.under))}</strong></div><div class="metric"><span>Over</span><strong>${esc(pct(store.over))}</strong></div><div class="metric"><span>Eff</span><strong>${esc(pct(store.eff))}</strong></div><div class="metric"><span>Sales</span><strong>${esc(money(store.sales))}</strong></div></div></li>`;
    })
    .join("");
  return `<div class="desk-only scroll"><table><thead><tr><th>Store</th><th>Division</th><th>Under</th><th>Over</th><th>Eff</th><th>Pch</th><th>Sales</th></tr></thead><tbody>${body}</tbody></table></div><ul class="phone-only store-cards">${cards}</ul>${more}`;
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
