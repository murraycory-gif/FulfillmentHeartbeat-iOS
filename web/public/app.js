import { updatedLine, considerPublished, pct, money, num } from "./clock.js";
import {
  emptyFilters,
  filtersActive,
  includesScope,
  regions,
  divisionsFor,
  optionValues,
  scopeLabel,
  finestScope,
  countStores,
  canonicalStore,
} from "./filters.js";
import {
  summary as scheduleSummary,
  companyMarketNote,
  bannerMismatch,
  actionGroups,
  rankedDivisions,
  rankedRegions,
  notScheduled,
  percentHealth,
  effHealth,
} from "./schedule-math.js";

const STAMP = "HB-0828.493";

const PAGES = [
  { id: "dashboard", title: "Dashboard" },
  { id: "sales", title: "Sales ScoreCard", section: "sales" },
  { id: "lost_revenue", title: "Loss Revenue ScoreCard", section: "lost_revenue" },
  { id: "missing_items", title: "Missing Items ScoreCard", section: "missing_items" },
  { id: "five_star", title: "5 Star ScoreCard", section: "five_star" },
  { id: "pre_sub_oos", title: "Pre-Sub OOS ScoreCard", section: "pre_sub_oos" },
  { id: "pick_path", title: "Pick Path Compliance ScoreCard", section: "pick_path" },
  { id: "prep_not_ready", title: "Prep Not Ready ScoreCard", section: "prep_not_ready" },
  { id: "dynacap", title: "Dynacap Settings ScoreCard", section: "dynacap" },
  { id: "schedule_quality", title: "Schedule Quality ScoreCard", section: "schedule_quality" },
  { id: "schedule", title: "Upcoming Weeks Schedule Check" },
  { id: "picker_scorecard", title: "Picker ScoreCard", section: "picker_scorecard" },
  { id: "pph", title: "PPH Pure Picks Per Hour", section: "pph" },
  { id: "labor", title: "Labor ScoreCard", section: "labor" },
];

const COLUMNS = {
  sales: [
    ["Sales $", ["sales_dollars"], money],
    ["YoY %", ["sales_yoy_pct"], pct],
    ["Orders", ["sales_orders"], (value) => num(value, 0)],
  ],
  lost_revenue: [
    ["Lost $", ["lost_revenue"], money],
    ["Lost %", ["lost_revenue_pct"], pct],
    ["eComm $", ["ecomm_sales"], money],
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
  pre_sub_oos: [["Rate", ["oos_pct"], pct]],
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
    ["Target Vs Actual", ["target_vs_actual_pct"], pct],
    ["Act Cost", ["act_cost_pct"], pct],
    ["Cost Tgt", ["cost_trgt_pct"], pct],
    ["Sch Eff", ["schedule_efficiency_pct"], pct],
    ["UPLH", ["uplh_impact_pct"], pct],
    ["Wage", ["wage_impact_pct"], pct],
    ["AIV", ["aiv_impact_pct"], pct],
  ],
};

const state = {
  page: "dashboard",
  filters: emptyFilters(),
  home: null,
  homeError: "",
  packs: new Map(),
  scheduleTab: "action",
  bannerTimer: 0,
};

const drawer = document.querySelector("#drawer");
const scrim = document.querySelector("#scrim");
const main = document.querySelector("#main");
const filtersForm = document.querySelector("#filters");
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
  const response = await fetch(`/api/${path}`, { cache: "no-store", credentials: "same-origin" });
  if (response.status === 401) throw new Error("AUTH");
  if (!response.ok) throw new Error("NO DATA");
  const data = await response.json();
  state.packs.set(path, data);
  return data;
}

function renderNav() {
  const items = PAGES.map(
    (page) =>
      `<li><button type="button" data-page="${page.id}" aria-current="${page.id === state.page ? "page" : "false"}">${esc(page.title)}</button></li>`,
  ).join("");
  drawer.innerHTML = `<ul class="pages">${items}</ul><p class="hint" style="padding:8px 16px">${esc(STAMP)}</p>`;
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
}

function setUpdated(raw) {
  updated.textContent = updatedLine(raw);
}

function companyBlock(section) {
  const summary = summaryFor(section);
  const tiles = tilesFor(section);
  if (!summary && !tiles) return `<p class="nodata">NO DATA</p>`;
  const health = summary ? summary.health : "none";
  const secondary = summary && summary.secondary ? `<p class="note">${esc(summary.secondary)}</p>` : "";
  const tileHtml = tiles
    ? `<div class="tiles">${tiles.labels
        .map(
          (label, index) =>
            `<div class="tile"><span>${esc(label)}</span><strong>${esc((tiles.values || [])[index] || "—")}</strong></div>`,
        )
        .join("")}</div>`
    : "";
  const scope = filtersActive(state.filters)
    ? `<p class="scope">In this scope: ${num(countStores(roster(), state.filters), 0)} stores. Company figures stay the cooked upload.</p>`
    : "";
  return `${badge(health)}${secondary}${tileHtml}${scope}`;
}

function cell(row, keys) {
  const payload = row.payload || {};
  for (const key of keys) {
    if (payload[key] != null && payload[key] !== "") return payload[key];
  }
  return null;
}

function table(section, rows) {
  const columns = COLUMNS[section] || [];
  const matched = rows.filter((row) => row.store && includesScope(row, state.filters));
  if (!matched.length) return `<p class="note">No stores in this scope.</p>`;
  const shown = matched.slice(0, 300);
  const head = ["Store", "Division", "District", "OM", ...columns.map((column) => column[0])]
    .map((label) => `<th>${esc(label)}</th>`)
    .join("");
  const body = shown
    .map((row) => {
      const metrics = columns
        .map((column) => `<td>${esc(column[2](cell(row, column[1])))}</td>`)
        .join("");
      return `<tr><td>${esc(canonicalStore(row.store))}</td><td>${esc(row.division || "—")}</td><td>${esc(row.district || "—")}</td><td>${esc(row.om || "—")}</td>${metrics}</tr>`;
    })
    .join("");
  const more = matched.length > shown.length ? `<p class="note">Showing ${shown.length} of ${matched.length} stores.</p>` : "";
  return `${more}<div class="scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderDashboard() {
  const cards = PAGES.filter((page) => page.section)
    .map((page) => {
      return `<article class="card"><button class="link" type="button" data-page="${page.id}"><h2>${esc(page.title)}</h2>${companyBlock(page.section)}</button></article>`;
    })
    .join("");
  const schedule = `<article class="card"><button class="link" type="button" data-page="schedule"><h2>Upcoming Weeks Schedule Check</h2><p class="note">Separate pack. Open the page for Action Needed, Summary, and Store Detail.</p></button></article>`;
  main.innerHTML = `<div class="cards">${cards}${schedule}</div>`;
}

function renderPicker() {
  const roll = pickerRoll(state.home, state.filters);
  const summary = summaryFor("picker_scorecard");
  const note = summary && summary.secondary ? `<p class="note">${esc(summary.secondary)}</p>` : "";
  if (!roll) {
    main.innerHTML = `${note}<p class="nodata">NO DATA</p>`;
    return;
  }
  const health = roll.risk > 0 ? "risk" : roll.watch > 0 ? "watch" : roll.healthy > 0 ? "good" : "none";
  const tiles = [
    ["Shoppers", num(roll.shoppers, 0)],
    ["Healthy", num(roll.healthy, 0)],
    ["Watch", num(roll.watch, 0)],
    ["At Risk", num(roll.risk, 0)],
  ]
    .map(([label, value]) => `<div class="tile"><span>${label}</span><strong>${esc(value)}</strong></div>`)
    .join("");
  const scope = `<p class="scope">${esc(scopeLabel(state.filters))}${filtersActive(state.filters) ? ` · In this scope: ${num(countStores(roster(), state.filters), 0)} stores` : ""}</p>`;
  main.innerHTML = `${badge(health)}${note}${scope}<div class="tiles">${tiles}</div><p class="note">Shopper rows stay in the cooked rollup. This page does not download the shopper tape.</p>`;
}

function pickerRoll(home, filters) {
  const rolls = (home && home.pickerRollups) || {};
  if (!filtersActive(filters)) return rolls.company || null;
  const scope = finestScope(filters);
  if (scope && rolls[scope]) return rolls[scope];
  const found = Object.keys(rolls).find((key) => scope && key.toLowerCase() === scope.toLowerCase());
  if (found) return rolls[found];
  const stores = roster().filter((row) => includesScope(row, filters));
  const parts = [];
  for (const row of stores) {
    const key = `store:${canonicalStore(row.store)}`;
    if (rolls[key]) parts.push(rolls[key]);
  }
  if (!parts.length) return null;
  return parts.reduce(
    (sum, roll) => ({
      shoppers: sum.shoppers + (roll.shoppers || 0),
      stores: sum.stores + (roll.stores || 0),
      healthy: sum.healthy + (roll.healthy || 0),
      watch: sum.watch + (roll.watch || 0),
      risk: sum.risk + (roll.risk || 0),
    }),
    { shoppers: 0, stores: 0, healthy: 0, watch: 0, risk: 0 },
  );
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
  const body = items
    .slice(0, 10)
    .map(
      (item) =>
        `<tr><td>${esc(item.name || "—")}</td><td>${esc(item.code || "—")}</td><td>${esc(pct(item.percent))}</td><td>${esc(num(item.count, 0))}</td></tr>`,
    )
    .join("");
  return `<h2>Top 10 Pre-Sub OOS items</h2><div class="scroll"><table><thead><tr><th>Item</th><th>Code</th><th>Pre-Sub OOS %</th><th>Count</th></tr></thead><tbody>${body}</tbody></table></div>`;
}

function toneClass(health) {
  return health === "good" || health === "risk" || health === "none" ? health : "";
}

function renderSchedule(pack) {
  if (!pack) {
    main.innerHTML = `<p class="nodata">NO DATA</p><p class="note">The Schedule Review workbook is not on this site.</p>`;
    return;
  }
  const card = scheduleSummary(pack, state.filters);
  const tabs = ["action", "summary", "detail"]
    .map((id) => {
      const label = id === "action" ? "Action Needed" : id === "summary" ? "Summary" : "Store Detail";
      return `<button type="button" data-tab="${id}" aria-pressed="${state.scheduleTab === id ? "true" : "false"}">${label}</button>`;
    })
    .join("");
  const week = pack.week ? `Week ${esc(pack.week)}` : "NO DATA";
  let body = "";
  if (state.scheduleTab === "summary") body = scheduleSummaryHtml(pack, card);
  else if (state.scheduleTab === "detail") body = scheduleDetailHtml(pack);
  else body = scheduleActionHtml(pack, card);
  main.innerHTML = `<p class="note">${week}${pack.summaryTitle ? ` · ${esc(pack.summaryTitle)}` : ""}</p><div class="seg">${tabs}</div>${body}`;
}

function scheduleActionHtml(pack, card) {
  const mismatch = bannerMismatch(pack, card, state.filters);
  const groups = actionGroups(pack, state.filters);
  const note = mismatch ? `<p class="note">${esc(mismatch)}</p>` : "";
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
          return `<section class="group"><h3>${esc(group.division || "—")} · ${esc(group.region || "—")} · ${group.stores.length}</h3><div class="scroll"><table><thead><tr><th>Store</th><th>Under</th><th>Over</th><th>Why</th></tr></thead><tbody>${rows}</tbody></table></div></section>`;
        })
        .join("")
    : `<p class="note">No stores qualify in this scope.</p>`;
  const countLabel = `${card.actionCount} ${card.actionCount === 1 ? "store" : "stores"}`;
  return `${note}<p class="note">${countLabel} · sales ≥ $30,000 and (under ≥ 10% or 4-wk under &gt; 9% or over ≥ 15%)</p>${groupsHtml}`;
}

function scheduleSummaryHtml(pack, card) {
  const kpis = [
    ["Under", pct(card.under), percentHealth(card.under, false)],
    ["Over", pct(card.over), percentHealth(card.over, false)],
    ["Pch vs Sch", pct(card.pch), ""],
    ["Sch Eff", pct(card.eff), effHealth(card.eff, false)],
    ["# Under", num(card.underCount, 0), ""],
    ["# Over", num(card.overCount, 0), ""],
    ["Stores in scope", num(card.scope, 0), ""],
  ]
    .map(
      ([label, value, health]) =>
        `<div class="kpi ${health || ""}"><span>${label}</span><strong>${esc(value)}</strong></div>`,
    )
    .join("");
  const market = companyMarketNote(card, state.filters);
  const divisions = rankedDivisions(pack, state.filters)
    .map(
      (row) =>
        `<tr><td>${esc(row.division)}</td><td>${esc(pct(row.under))}</td><td>${esc(pct(row.over))}</td><td>${esc(pct(row.eff))}</td><td>${esc(num(row.scope, 0))}</td></tr>`,
    )
    .join("");
  const regionRows = rankedRegions(pack, state.filters)
    .map(
      (row) =>
        `<tr><td>${esc(row.region)}</td><td>${esc(pct(row.under))}</td><td>${esc(pct(row.over))}</td><td>${esc(pct(row.eff))}</td><td>${esc(num(row.scope, 0))}</td></tr>`,
    )
    .join("");
  return `<div class="tiles">${kpis}</div>${market ? `<p class="note">${esc(market)}</p>` : ""}<p class="note">Eff at or above 90% is green. 0% under or over is green. Not scheduled stays gray.</p><h2>Regions</h2><div class="scroll"><table><thead><tr><th>Region</th><th>Under</th><th>Over</th><th>Eff</th><th>Stores</th></tr></thead><tbody>${regionRows}</tbody></table></div><h2>Divisions</h2><div class="scroll"><table><thead><tr><th>Division</th><th>Under</th><th>Over</th><th>Eff</th><th>Stores</th></tr></thead><tbody>${divisions}</tbody></table></div>`;
}

function scheduleDetailHtml(pack) {
  const rows = (pack.stores || []).filter((store) => includesScope(store, state.filters)).slice(0, 400);
  if (!rows.length) return `<p class="note">No stores in this scope.</p>`;
  const body = rows
    .map((store) => {
      const unscheduled = notScheduled(store);
      const name = esc(canonicalStore(store.store));
      const tag = unscheduled ? ` <span class="unscheduled">Not scheduled yet</span>` : "";
      return `<tr><td>${name}${tag}</td><td>${esc(store.division || "—")}</td><td class="${toneClass(percentHealth(store.under, unscheduled))}">${esc(pct(store.under))}</td><td class="${toneClass(percentHealth(store.over, unscheduled))}">${esc(pct(store.over))}</td><td class="${toneClass(effHealth(store.eff, unscheduled))}">${esc(pct(store.eff))}</td><td>${esc(pct(store.pch))}</td><td>${esc(money(store.sales))}</td></tr>`;
    })
    .join("");
  return `<div class="scroll"><table><thead><tr><th>Store</th><th>Division</th><th>Under</th><th>Over</th><th>Eff</th><th>Pch</th><th>Sales</th></tr></thead><tbody>${body}</tbody></table></div>`;
}

let renderToken = 0;

async function render() {
  const token = ++renderToken;
  const page = pageById(state.page);
  title.textContent = page.title;
  renderNav();
  renderFilters();
  if (state.homeError === "AUTH") {
    setUpdated(null);
    main.innerHTML = `<p class="nodata">NO DATA</p><p class="note">Sign in with the email PIN to open Heartbeat.</p>`;
    return;
  }
  if (!state.home) {
    setUpdated(null);
    main.innerHTML = `<p class="nodata">NO DATA</p>`;
    return;
  }
  if (page.id === "schedule") {
    setUpdated(null);
    main.innerHTML = `<p class="note">Loading…</p>`;
    try {
      const pack = await load("schedule");
      if (token !== renderToken) return;
      setUpdated(pack.publishedAt);
      raiseBanner(considerPublished(sessionStorage, "hb.web.seenScheduleAt", pack.publishedAt));
      renderSchedule(pack);
    } catch (error) {
      if (error.message === "AUTH") {
        state.homeError = "AUTH";
        return render();
      }
      setUpdated(null);
      renderSchedule(null);
    }
    return;
  }
  setUpdated(state.home.publishedAt);
  if (page.id === "dashboard") {
    renderDashboard();
    return;
  }
  if (page.section === "picker_scorecard") {
    renderPicker();
    return;
  }
  main.innerHTML = `${companyBlock(page.section)}<p class="note">Loading…</p>`;
  let rows = [];
  let missing = false;
  try {
    const pack = await load(`section/${page.section}`);
    if (token !== renderToken) return;
    rows = pack.rows || [];
  } catch (error) {
    if (error.message === "AUTH") {
      state.homeError = "AUTH";
      return render();
    }
    missing = true;
  }
  let extra = "";
  if (page.section === "pre_sub_oos") {
    try {
      const presub = await load("presub");
      if (token !== renderToken) return;
      extra = renderPresub(presub);
    } catch (error) {
      if (error.message === "AUTH") {
        state.homeError = "AUTH";
        return render();
      }
      extra = state.home.preSubItemTabPresent === false
        ? `<p class="note">Item detail not in this upload</p>`
        : `<p class="note">NO DATA</p>`;
    }
  }
  if (token !== renderToken) return;
  const storeTable = missing
    ? `<p class="note">Store rows are not in this upload.</p>`
    : table(page.section, rows);
  main.innerHTML = `${companyBlock(page.section)}${extra}${storeTable}`;
}

function closeDrawer() {
  drawer.classList.remove("open");
  scrim.hidden = true;
  navToggle.setAttribute("aria-expanded", "false");
}

navToggle.addEventListener("click", () => {
  const open = !drawer.classList.contains("open");
  drawer.classList.toggle("open", open);
  scrim.hidden = !open;
  navToggle.setAttribute("aria-expanded", open ? "true" : "false");
});
scrim.addEventListener("click", closeDrawer);

document.body.addEventListener("click", (event) => {
  const pageButton = event.target.closest("[data-page]");
  if (pageButton) {
    state.page = pageButton.getAttribute("data-page");
    closeDrawer();
    render();
    return;
  }
  const tab = event.target.closest("[data-tab]");
  if (tab) {
    state.scheduleTab = tab.getAttribute("data-tab");
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
  render();
});

renderNav();
load("home")
  .then((home) => {
    state.home = home;
    raiseBanner(considerPublished(sessionStorage, "hb.web.seenPublishedAt", home.publishedAt));
  })
  .catch((error) => {
    state.homeError = error.message === "AUTH" ? "AUTH" : "NO DATA";
  })
  .finally(render);
