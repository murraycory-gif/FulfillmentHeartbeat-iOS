import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { hashPassword, verifyPassword } from "./functions/accounts.js";
import {
  basicAuthOk,
  createSessionToken,
  onRequest as basicGate,
  timingSafeEqualString,
} from "./functions/_middleware.js";
import {
  accessCertsURL,
  authorize,
  clearJwksCache,
  devBypassAllowed,
  emailAllowed,
  objectKeyForPath,
  parseAllowlist,
  verifyAccessJwt,
} from "./functions/gate.js";
import { bannerText, considerPublished, formatHeadline, money, pct, publishClock, publishStamp, updatedLine } from "./public/clock.js";
import {
  canonicalDivision,
  canonicalStore,
  countStores,
  includesScope,
  isPersonOm,
  matchesDistrict,
  scheduleDistrictNote,
  emptyScopeNote,
  storesForDistrict,
  shownDistrict,
  optionValues,
  matchesDivision,
  regionLineInScope,
  scopeStoreCount,
  sectionGrainRows,
  searchScope,
  cascadePick,
  scopeChips,
  filtersUpTo,
  browseLevel,
  storeLabel,
} from "./public/filters.js";
import { FIGURE_SECTIONS, packURL } from "./public/packs.js";
import { healthWord, mailtoURL, shareBrief, shareEml, shareHtml, sharePages, shareSubject } from "./public/share.js";
import { chromeSeat, lossPercentPoints, seatSummary } from "./public/seat.js";
import { metricsInSource, pphBar, shopperIdentity, shopperMatchesQuery, sortShoppersByPph } from "./public/shoppers.js";
import {
  bannerMismatch,
  companyMarketNote,
  notScheduled,
  barelyScheduled,
  percentHealth,
  qualifies,
  qualifiesStore,
  scheduleVisibleTitle,
  rankedDivisions,
  rankedRegions,
  scheduleGapNote,
  summary,
} from "./public/schedule-math.js";

const root = dirname(fileURLToPath(import.meta.url));
const empty = { region: "", division: "", district: "", om: "", store: "" };

function filters(extra) {
  return { ...empty, ...extra };
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else out.push(path);
  }
  return out;
}

const allow = parseAllowlist(`
# comment
Reader@Example.com

not-an-email
reader@example.com
`);
assert.deepEqual(allow, ["reader@example.com"]);
assert.equal(emailAllowed("Reader@Example.com", allow), true);
assert.equal(emailAllowed("other@example.com", allow), false);
assert.equal(parseAllowlist("# only\n\n").length, 0);

assert.equal(objectKeyForPath("home"), "web-pack/home.json");
assert.equal(objectKeyForPath("/section/sales"), "web-pack/section/sales.json");
assert.equal(objectKeyForPath("presub"), "web-pack/presub.json");
assert.equal(objectKeyForPath("schedule"), "schedule-check.json");
assert.equal(objectKeyForPath("section/not_a_section"), null);
assert.equal(objectKeyForPath("section/../home"), null);
assert.equal(objectKeyForPath("packs/seat/company/all/current.sqlite"), null);
assert.equal(objectKeyForPath("https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite"), null);
assert.equal(objectKeyForPath("home?x=https://example.r2.dev/a"), null);

assert.equal(devBypassAllowed({ HEARTBEAT_WEB_DEV: "1" }, "localhost"), true);
assert.equal(devBypassAllowed({ HEARTBEAT_WEB_DEV: "1" }, "127.0.0.1"), true);
assert.equal(devBypassAllowed({ HEARTBEAT_WEB_DEV: "1" }, "heartbeat.pages.dev"), false);
assert.equal(devBypassAllowed({}, "localhost"), false);
assert.equal(accessCertsURL("Team.CloudflareAccess.com"), "https://team.cloudflareaccess.com/cdn-cgi/access/certs");
assert.equal(accessCertsURL("https://evil.example/cdn-cgi/access/certs"), null);

const stamp = readFileSync(join(root, "../FulfillmentHeartbeat/BuildStamp.swift"), "utf8");
const app = readFileSync(join(root, "public/app.js"), "utf8");
assert.match(stamp, /HB-0828\.494/);
assert.equal(app.includes("HB-0828.494"), false);
assert.match(app, /applyPackStamp\(home && home\.publishedAt\)/);
assert.match(app, /publishStamp\(raw\)/);
assert.equal((stamp.match(/HB-0828\.494/g) || []).length, 1);
assert.equal(app.includes("Sign in with the email PIN"), false);
assert.equal(app.includes("/api/"), false);
assert.match(app, /packURL/);

assert.equal(packURL("home"), "/data/home.json");
assert.equal(packURL("section/sales"), "/data/section/sales.json");
assert.equal(
  packURL("home", "https://user:pass@fulfillment-heartbeat-web.pages.dev/app"),
  "https://fulfillment-heartbeat-web.pages.dev/data/home.json",
);
assert.equal(
  packURL("section/sales", "https://fulfillment-heartbeat-web.pages.dev"),
  "https://fulfillment-heartbeat-web.pages.dev/data/section/sales.json",
);
assert.match(app, /new URL\(relative, location\.origin\)/);
assert.match(app, /console\.error\("pack fetch failed"/);
assert.equal(packURL("presub"), "/data/presub.json");
assert.equal(packURL("schedule"), "/data/schedule.json");
assert.equal(packURL("packs/seat/company/all/current.sqlite"), null);
assert.equal(packURL("https://example.r2.dev/current.sqlite"), null);
assert.equal(FIGURE_SECTIONS.has("lost_revenue"), true);
assert.equal(FIGURE_SECTIONS.has("five_star"), true);
assert.equal(FIGURE_SECTIONS.has("pick_path"), true);
assert.equal(FIGURE_SECTIONS.has("dynacap"), true);
assert.equal(FIGURE_SECTIONS.has("schedule_quality"), true);
assert.equal(FIGURE_SECTIONS.has("picker_scorecard"), true);
assert.equal(FIGURE_SECTIONS.has("labor"), true);
assert.equal(FIGURE_SECTIONS.has("sales"), false);
assert.equal(FIGURE_SECTIONS.has("missing_items"), false);
assert.equal(FIGURE_SECTIONS.has("pre_sub_oos"), false);
assert.equal(FIGURE_SECTIONS.has("prep_not_ready"), false);
assert.equal(FIGURE_SECTIONS.has("pph"), false);
assert.equal(formatHeadline("lost_revenue", 393334.12), "$393,334.12");
assert.equal(formatHeadline("lost_revenue", 4248638.426), "$4,248,638.43");
assert.equal(money("$81,833,890.57"), "$81,833,890.57");
assert.equal(formatHeadline("five_star", 3.400277), "3.40");
assert.equal(formatHeadline("labor", 0.24972986261229743), "0.25%");
assert.equal(formatHeadline("pick_path", 79.8251044108846), "79.8%");
assert.equal(formatHeadline("dynacap", 67.85707617841031), "67.9");
assert.equal(formatHeadline("picker_scorecard", 24548), "24,548");
assert.equal(formatHeadline("schedule_quality", 90.33328114614572), "90.3%");

const seatLines = [
  { section: "sales", region: "East", title: "Sales", value: "$8,209,791.69", count: 615 },
  { section: "sales", region: "South", title: "Sales", value: "$4,994,836.32", count: 397 },
  { section: "picker_scorecard", region: "East", title: "Pickers", value: "6996 shoppers", count: 6996 },
];
assert.equal(regionLineInScope(seatLines[0], filters({ region: "East Region" }), []), true);
assert.equal(regionLineInScope(seatLines[1], filters({ region: "East Region" }), []), false);
assert.equal(scopeStoreCount([], filters({ region: "East Region" }), seatLines), 615);
const eastRoster = [{ store: "117", division: "Shaws", district: "03", om: "Ada" }];
assert.equal(scopeStoreCount(eastRoster, filters({ region: "East Region" }), seatLines), 1);

const grainLines = [
  {
    section: "lost_revenue",
    region: "East",
    value: "$566,667.32",
    count: 613,
    children: [
      { division: "Jewel Osco", value: "$187,589.93", count: 180 },
      { division: "Shaws", value: "$232,438.89", count: 147 },
    ],
  },
  { section: "lost_revenue", region: "South", value: "$232,961.93", count: 395, children: [] },
];
const eastGrain = sectionGrainRows(grainLines, "lost_revenue", filters({ region: "East Region" }), []);
assert.equal(eastGrain.length, 3);
assert.equal(eastGrain[0].label, "East");
assert.equal(eastGrain[0].value, "$566,667.32");
assert.equal(eastGrain[2].label, "Shaws");
const shawsGrain = sectionGrainRows(grainLines, "lost_revenue", filters({ division: "Shaws" }), []);
assert.equal(shawsGrain.length, 1);
assert.equal(shawsGrain[0].value, "$232,438.89");
assert.equal(
  sectionGrainRows(grainLines, "lost_revenue", filters({ district: "03" }), eastRoster).length,
  0,
);
assert.equal(app.includes("Company figures stay the cooked upload"), false);
assert.match(app, /nav-collapsed/);
assert.match(app, /seatSummary/);
const companySales = {
  headline: 37065336.17,
  secondary: "785 up · 172 flat · 1208 down",
  health: "risk",
  storeCount: 2179,
};
const eastLines = [
  {
    section: "sales",
    region: "East",
    value: "$10,706,607.64",
    count: 615,
    health: "risk",
    children: [{ division: "Shaws", value: "$1.00", count: 147, health: "watch" }],
  },
];
const eastStores = [
  { store: "117", division: "Shaws", district: "03", om: "Ada", payload: { sales_dollars: 10, sales_yoy_pct: 4 } },
  { store: "118", division: "Jewel Osco", district: "04", om: "Bea", payload: { sales_dollars: 20, sales_yoy_pct: -10 } },
  { store: "200", division: "United", district: "03", om: "Ada", payload: { sales_dollars: 999, sales_yoy_pct: 8 } },
];
const companySeat = seatSummary("sales", {
  company: companySales,
  lines: eastLines,
  rows: eastStores,
  filters: filters({}),
});
assert.equal(companySeat.fixedCompany, true);
assert.equal(companySeat.headline, 37065336.17);
assert.equal(companySeat.secondary, "785 up · 172 flat · 1208 down");
const eastSeat = seatSummary("sales", {
  company: companySales,
  lines: eastLines,
  rows: eastStores,
  filters: filters({ region: "East Region" }),
});
assert.equal(eastSeat.fixedCompany, false);
assert.equal(eastSeat.headlineText, "$10,706,607.64");
assert.equal(eastSeat.headline, null);
assert.equal(eastSeat.secondary, "1 up · 0 flat · 1 down");
assert.equal(eastSeat.storeCount, 615);
const shawsSeat = seatSummary("sales", {
  company: companySales,
  lines: eastLines,
  rows: eastStores,
  filters: filters({ region: "East Region", division: "Shaws" }),
});
assert.equal(shawsSeat.headlineText, "$1.00");
assert.equal(shawsSeat.secondary, "1 up · 0 flat · 0 down");
assert.equal(chromeSeat(eastLines, "sales", filters({ district: "03" })), null);
const districtSeat = seatSummary("sales", {
  company: companySales,
  lines: eastLines,
  rows: eastStores,
  filters: filters({ region: "East Region", district: "03" }),
});
assert.equal(districtSeat.headlineText, null);
assert.equal(districtSeat.headline, 10);
assert.equal(districtSeat.secondary, "1 up · 0 flat · 0 down");
const blankDynacap = seatSummary("dynacap", {
  company: { headline: 67.9, secondary: "company", health: "good", storeCount: 9 },
  lines: [],
  rows: [{ store: "117", division: "Shaws", district: "03", payload: {} }],
  filters: filters({ store: "117" }),
});
assert.equal(blankDynacap.headline, null);
assert.equal(blankDynacap.headlineText, null);
assert.match(blankDynacap.secondary, /No Dynacap rows/);
const capacityDynacap = seatSummary("dynacap", {
  company: { headline: 67.9, secondary: "company", health: "good", storeCount: 9 },
  lines: [],
  rows: [{ store: "22", division: "United", payload: { eot_capacity: 17200, used_capacity: 1187 } }],
  filters: filters({ store: "22" }),
});
assert.equal(capacityDynacap.headline, null);
assert.equal(capacityDynacap.storeCount, 1);
assert.match(capacityDynacap.secondary, /No Pcs\/Hr/);
assert.match(app, /This pack has no Schedule Check rows/);
assert.match(app, /data-more/);
assert.match(app, /data-close-drawer/);
assert.equal(app.includes("Workbook banner said"), false);
assert.match(app, /scrollTo\(0, 0\)/);
assert.equal(app.includes("Shopper names are not on this site"), false);
assert.match(app, /Shopper rows open from a division/);
const css = readFileSync(join(root, "public/app.css"), "utf8");
assert.equal(/\.brand-lockup\s*\{[^}]*background:\s*#fff/.test(css), false);
const pageHtml = readFileSync(join(root, "public/index.html"), "utf8");
assert.match(pageHtml, /src="\/nav-boot\.js\?v=2"/);
assert.equal(/<script>\s*try/.test(pageHtml), false);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /nav-collapsed/);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /location\.username/);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /location\.replace\(location\.origin/);
const lockup = pageHtml.slice(pageHtml.indexOf('class="brand-lockup"'), pageHtml.indexOf("</p>", pageHtml.indexOf('class="brand-lockup"')));
assert.ok(lockup.indexOf("wordmark") < lockup.indexOf('class="heart"'));
assert.ok(lockup.indexOf('class="heart"') < lockup.indexOf('class="pulse"'));
assert.match(css, /\.brand-lockup \{[^}]*justify-self:\s*center/);
assert.match(css, /z-index:\s*30/);
const quinnRoster = [
  { store: "210", division: "United", district: "U5", om: "Andrew Quinn" },
  { store: "1", division: "Jewel Osco", district: "J1", om: "Chicago 1" },
  { store: "22", division: "United", district: "U5", om: "Andrew Quinn" },
];
const quinnSales = { store: "210", division: "United", district: "U5", om: "" };
assert.equal(includesScope(quinnSales, filters({ om: "Andrew Quinn" })), false);
assert.equal(includesScope(quinnSales, filters({ om: "Andrew Quinn" }), quinnRoster), true);
assert.equal(includesScope({ store: "22", division: "United", om: "Southwest 1" }, filters({ om: "Andrew Quinn" }), quinnRoster), true);
assert.equal(isPersonOm("Andrew Quinn"), true);
assert.equal(isPersonOm("Chicago 1"), false);
assert.deepEqual(optionValues(quinnRoster, filters({}), "om"), ["Andrew Quinn"]);
assert.deepEqual(optionValues(quinnRoster, filters({ om: "Andrew Quinn" }), "district"), ["U5"]);
const midAtlantic = seatSummary("dynacap", {
  company: { headline: 67.9, secondary: "company", health: "good", storeCount: 9 },
  lines: [
    {
      section: "dynacap",
      region: "East",
      value: "81.3",
      count: 612,
      health: "risk",
      children: [{ division: "Mid-Atlantic", value: "100.0", count: 286, health: "watch" }],
    },
  ],
  rows: [],
  filters: filters({ division: "Mid-Atlantic" }),
});
assert.equal(midAtlantic.headlineText, "100.0");
assert.equal(midAtlantic.health, "watch");
assert.equal(
  scheduleVisibleTitle("Schedule Review Summary — Week 31 (WK31)", 32),
  "Schedule Review Summary — Week 32 (WK32)",
);
assert.equal(scheduleVisibleTitle("Schedule Review Summary — Week 31 (WK31)", 33), "Schedule Review Summary — Week 33 (WK33)");
assert.match(app, /scheduleVisibleTitle\(pack\.summaryTitle,\s*pack\.week\)/);
assert.equal(readFileSync(join(root, "public/seat.js"), "utf8").includes("dynacapHealth"), false);
assert.match(app, /class="region-cards"/);
assert.match(app, /Schedule Check/);
assert.equal(app.includes("Region results"), false);
assert.match(app, /regionTables/);
assert.match(app, /nav-icon/);
assert.match(app, /NAV_ICON/);
assert.match(app, /text\/html/);
assert.match(app, /mailtoURL/);
assert.match(app, /share-open/);
assert.match(css, /\.share \[hidden\]/);
assert.match(css, /#share\[hidden\][\s\S]*display:\s*none !important/);
assert.match(css, /#share\.is-open \{ display: grid !important; \}/);
assert.match(app, /function forceShareClosed/);
assert.match(app, /function closeShare/);
assert.equal(app.includes('getItem("hb.web.shareOpen")'), false);
assert.equal(app.includes("getItem('shareOpen')"), false);
assert.match(pageHtml, /app\.css\?v=20/);
assert.match(css, /#scope-search,\s*#browse-open,\s*#share-open,\s*#clear-filters \{[^}]*height:\s*44px/);
assert.match(pageHtml, /id="scope-search"/);
assert.match(pageHtml, /id="clear-filters"/);
assert.match(pageHtml, /aria-label="Share"/);
assert.match(pageHtml, /app\.js\?v=29/);
const renderSrc = app.slice(app.indexOf("async function render("), app.indexOf("function desktopNav("));
assert.equal(renderSrc.includes("await ensureSeatRows"), false);
assert.match(renderSrc, /renderDashboard\(\);\s*warmDashboard\(token\)/);
assert.match(renderSrc, /renderPicker\(\)/);
assert.equal(renderSrc.includes('await load("section/picker_scorecard")'), false);
assert.match(app, /function seatReady/);
assert.match(app, /function warmDashboard/);
assert.match(app, /Shopper tape stays parked/);
assert.match(app, /Schedule stores/);
assert.match(pageHtml, /rel="icon" href="\/favicon\.svg"/);
assert.match(css, /\.heart \{[^}]*z-index:\s*2/);
assert.match(css, /\.pulse \{[^}]*margin-left:\s*-20px/);
assert.equal(/<script(?![^>]*\bsrc=)/.test(pageHtml), false);
assert.match(pageHtml, /<script src="\/nav-boot\.js\?v=2"><\/script>/);
assert.match(app, /· OM \$\{seat\.om\}/);
assert.match(app, /section === "schedule_quality"[\s\S]*OM \$\{esc\(manager\)\}/);
assert.match(app, /section\/picker_scorecard/);
assert.match(app, /No shopper data/);
assert.match(app, /data-shopper-search/);
assert.match(app, /data-more="shoppers"/);
assert.match(app, /Shopper PPH, hours, and orders are from the Picker ScoreCard/);
assert.match(css, /td\.bar-risk/);
assert.match(css, /\.store-card\.bar-good/);
assert.equal(pphBar(80), "good");
assert.equal(pphBar(74), "watch");
assert.equal(pphBar(73.99), "risk");
assert.equal(pphBar(null), "none");
assert.equal(pphBar(0), "risk");
assert.equal(shopperIdentity({ shopper: "Ava Lane", shopperId: "ALANE1" }), "Ava Lane · ALANE1");
assert.equal(shopperIdentity({ shopper: "AVELJ03", shopperId: "AVELJ03" }), "AVELJ03");
assert.equal(shopperMatchesQuery({ shopper: "AVELJ03", shopperId: "AVELJ03", store: "1" }, "vel"), true);
assert.equal(shopperMatchesQuery({ shopper: "AVELJ03", shopperId: "AVELJ03", store: "1" }, "99" ), false);
const pphPack = JSON.parse(readFileSync(join(root, "public/data/section/pph.json"), "utf8"));
assert.equal(pphPack.rows.some((row) => row.shopper || row.shopperId), false);
assert.equal(pphPack.rows.every((row) => row.payload && Object.prototype.hasOwnProperty.call(row.payload, "pph")), true);
assert.equal(pphPack.rows.some((row) => row.payload.pick_hours != null || row.payload.orders != null), false);
const rankedShoppers = sortShoppersByPph([
  { store: "2", shopper: "High", shopperId: "High", payload: { pph: 90, pick_hours: 4, orders: 3 } },
  { store: "1", shopper: "Blank", shopperId: "Blank", payload: { orders: 1 } },
  { store: "1", shopper: "Low", shopperId: "Low", payload: { pph: 22.7, pick_hours: 0.9, orders: 1 } },
  { store: "1", shopper: "Zero", shopperId: "Zero", payload: { pph: 0, pick_hours: 1, orders: 1 } },
]);
assert.deepEqual(rankedShoppers.map((row) => row.shopper), ["Zero", "Low", "High", "Blank"]);
assert.deepEqual(
  metricsInSource(rankedShoppers, [
    { label: "PPH", keys: ["pph"] },
    { label: "Hours", keys: ["pick_hours"] },
    { label: "Orders", keys: ["orders"] },
    { label: "Path %", keys: ["compliance_pct"] },
  ]).map((column) => column.label),
  ["PPH", "Hours", "Orders"],
);
assert.match(app, /Labor Sch Eff is schedule efficiency from the Labor workbook/);
assert.match(app, /Quality Sch Eff is the average schedule efficiency on the Schedule Quality sheet/);
assert.equal(readFileSync(join(root, "public/seat.js"), "utf8").includes("formatCompanyAiv"), false);
assert.equal(app.includes("formatCompanyAiv"), false);
assert.equal(app.includes("laborMarket"), false);
assert.match(css, /\.share\[hidden\]/);
assert.match(app, /tileUsesSectionTone/);
assert.match(app, /tone-\$\{tone\}/);
const phoneCss = css.slice(css.indexOf("@media (max-width: 800px)"), css.indexOf("@media (min-width: 801px)"));
const deskCss = css.slice(css.indexOf("@media (min-width: 801px)"));
assert.match(phoneCss, /#nav-toggle \{[^}]*min-height:\s*44px/);
assert.match(phoneCss, /#nav-toggle \{[^}]*min-width:\s*44px/);
assert.match(deskCss, /#nav-toggle \{[^}]*min-height:\s*44px/);
assert.match(deskCss, /#nav-toggle \{[^}]*min-width:\s*44px/);
assert.equal(phoneCss.includes("min-height: 32px"), false);
assert.equal(deskCss.includes("min-height: 22px"), false);
assert.match(css, /grid-template-areas:\s*"lockup"\s*"title"\s*"foot"/);
assert.match(css, /\.header-foot/);
assert.match(css, /\.brand-lockup \{[^}]*position: static/);
assert.match(css, /#nav-toggle \{[^}]*background: transparent/);
assert.match(css, /\.drawer-stamp/);
assert.match(css, /\.region-cards \.chip \{[^}]*border-left:\s*4px/);
assert.match(app, /class="drawer-stamp"/);
assert.match(app, /bar-\$\{tone\}/);
assert.match(app, /region-legend/);
assert.equal(app.includes("worstHealth"), false);
assert.equal(pageHtml.includes('id="stamp"'), false);
assert.equal(pageHtml.includes('class="stamp"'), false);
assert.match(pageHtml, /class="header-foot"/);
assert.match(deskCss, /\.wordmark \{ font-size: 1\.55rem/);
assert.match(deskCss, /h1 \{ font-size: 1\.05rem/);
assert.match(deskCss, /#updated \{ font-size: 0\.78rem/);
assert.match(deskCss, /\.pulse \{[^}]*margin-left:\s*-28px/);
assert.equal(deskCss.includes('"nav stamp"'), false);
assert.equal(app.includes("Hide pages"), false);
assert.equal(deskCss.includes(".chip strong"), false);
assert.equal(deskCss.includes(".filter-label"), false);
assert.equal(deskCss.includes(".score-face h2"), false);
assert.match(css, /@media \(max-width: 800px\)[\s\S]*\.wordmark \{ font-size: 1\.48rem/);
assert.match(css, /\.chip\.tone-good strong \{ color: var\(--good\)/);
assert.match(css, /\.chip\.tone-watch strong \{ color: var\(--watch\)/);
assert.match(css, /\.chip\.tone-risk strong \{ color: var\(--risk\)/);
assert.match(app, /scheduleTab: "summary"/);
assert.match(app, /\["summary", "action", "detail"\]/);
assert.match(app, /nextPage === "schedule"\) state\.scheduleTab = "summary"/);
assert.match(pageHtml, /id="share" class="share" hidden/);
assert.equal(pageHtml.includes('id="share" class="share is-open"'), false);
assert.match(app, /closest\("\.share-card"\)/);
assert.match(pageHtml, /id="share-open"/);
assert.match(pageHtml, /name="share-mode" value="all"/);
assert.match(pageHtml, /name="share-mode" value="pick"/);
const catalog = [
  { id: "dashboard", title: "Dashboard" },
  { id: "lost_revenue", title: "Lost Revenue" },
  { id: "labor", title: "Labor" },
];
assert.deepEqual(
  sharePages("page", "lost_revenue", [], catalog).map((page) => page.id),
  ["lost_revenue"],
);
assert.equal(sharePages("all", "lost_revenue", [], catalog).length, 3);
assert.deepEqual(
  sharePages("pick", "lost_revenue", ["labor", "dashboard"], catalog).map((page) => page.id),
  ["dashboard", "labor"],
);
assert.equal(sharePages("pick", "lost_revenue", [], catalog).length, 0);
assert.equal(shareSubject("Total Company", "HB-0828.494"), "Fulfillment Heartbeat — Total Company — HB-0828.494");
assert.equal(shareSubject("East Region · Jewel Osco", "HB-0828.494"), "Fulfillment Heartbeat — East Region · Jewel Osco — HB-0828.494");
assert.equal(healthWord("risk"), "At risk");
const brief = shareBrief({
  scope: "Total Company",
  stamp: "HB-0828.494",
  updated: "Updated Mon 10/5 1:39 PM",
  pages: [{ title: "Lost Revenue", detail: "At risk · 2,165 stores · $4,248,638.43\nLost % 5.19% · Missed $178,705.37" }],
});
assert.match(brief, /Filters|Total Company/);
assert.match(brief, /Lost % 5.19%/);
assert.match(brief, /Missed \$178,705\.37/);
assert.match(brief, /Sent from Fulfillment Heartbeat/);
const mail = mailtoURL({ to: "ops@example.com", subject: shareSubject("Total Company", "HB-0828.494"), body: brief });
assert.match(mail, /^mailto:ops@example.com\?subject=/);
assert.match(decodeURIComponent(mail), /Lost % 5.19%/);
assert.match(decodeURIComponent(mail), /Total Company/);
const structured = shareBrief({
  scope: "Total Company",
  stamp: "HB-0828.494",
  updated: "Updated Mon 10/5 1:39 PM",
  pages: [
    {
      title: "Dashboard",
      blocks: [
        { title: "Sales", status: "Healthy", count: "2,181 stores", figure: "$81,833,890.57" },
        {
          title: "Lost Revenue",
          status: "At risk",
          count: "2,165 stores",
          figure: "$4,248,638.43",
          metrics: [{ label: "Lost %", value: "5.19%" }],
        },
      ],
    },
  ],
});
assert.match(structured, /FULFILLMENT HEARTBEAT/);
assert.match(structured, /SALES\nHealthy · 2,181 stores\n\$81,833,890\.57/);
assert.match(structured, /LOST REVENUE\nAt risk · 2,165 stores\n\$4,248,638\.43\nLost %    5\.19%/);
assert.ok(structured.indexOf("SALES") < structured.indexOf("LOST REVENUE"));
const html = shareHtml({
  scope: "Total Company",
  stamp: "HB-0828.494",
  updated: "Updated Mon 10/5 1:39 PM",
  pages: structured && [
    { title: "Lost Revenue", blocks: [{ title: "Lost Revenue", status: "At risk", figure: "$4,248,638.43", metrics: [{ label: "Lost %", value: "5.19%" }, { label: "Missed", value: "$178,705.37" }] }] },
  ],
});
assert.match(html, /<table/);
assert.match(html, /Lost %/);
assert.match(html, /5\.19%/);
assert.match(html, /\$178,705\.37/);
const eml = shareEml({ to: "ops@example.com", subject: "Fulfillment Heartbeat — Total Company — HB-0828.494", plain: structured, html });
assert.match(eml, /multipart\/alternative/);
assert.match(eml, /X-Unsent: 1/);
assert.match(eml, /text\/html/);
assert.match(eml, /5\.19%/);

for (const path of walk(join(root, "public"))) {
  const text = readFileSync(path, "utf8");
  assert.equal(/r2\.dev/i.test(text), false, path);
  assert.equal(text.includes("pub-eafb309f53464d98902d12ac107f0f1e"), false, path);
}
const fn = readFileSync(join(root, "functions/api/[[path]].js"), "utf8");
assert.equal(/r2\.dev/i.test(fn), false);
assert.match(fn, /private, no-store/);
assert.match(fn, /HEARTBEAT_PACKS/);

assert.equal(updatedLine(""), "Updated —");
assert.equal(updatedLine(null), "Updated —");
assert.equal(publishStamp("2026-10-05T18:39:32Z"), "HB-1005.1839");
assert.equal(publishStamp(""), "");
assert.equal(publishStamp(null), "");
const noon = new Date(2026, 8, 28, 15, 10, 0);
assert.equal(publishClock(noon), "Mon 9/28 3:10 PM");
assert.equal(bannerText(null, "2026-09-28T16:00:00Z"), null);
const memory = new Map();
const storage = {
  getItem: (key) => (memory.has(key) ? memory.get(key) : null),
  setItem: (key, value) => memory.set(key, value),
};
assert.equal(considerPublished(storage, "hb.web.seenPublishedAt", "2026-09-28T15:00:00Z"), null);
const newer = considerPublished(storage, "hb.web.seenPublishedAt", "2026-09-28T16:00:00Z");
assert.match(newer, /^New data uploaded /);
assert.equal(considerPublished(storage, "hb.web.seenPublishedAt", "2026-09-28T16:00:00Z"), null);

assert.equal(qualifies(29999, 50, 50, 50), false);
assert.equal(qualifies(null, 50, 50, 50), false);
assert.equal(qualifies(30000, 10, 0, 0), true);
assert.equal(qualifies(30000, 9.9, 9, 14.9), false);
assert.equal(qualifies(30000, 0, 9, 0), false);
assert.equal(qualifies(30000, 0, 9.0002, 0), true);
assert.equal(qualifies(30000, 0, 0, 15), true);
assert.equal(notScheduled({ under: 100, eff: 0 }), true);
assert.equal(notScheduled({ under: 100, eff: 1 }), false);
assert.equal(percentHealth(12, true), "none");
assert.equal(percentHealth(0, false), "good");
assert.equal(percentHealth(0.2, false), "risk");

assert.equal(matchesDivision("SHAWS", "Shaws"), true);
assert.equal(matchesDivision("MID-ATLANTIC", "Mid Atlantic"), true);
assert.equal(matchesDivision("Shaws", "United"), false);
assert.equal(canonicalDivision("NOR. CALIFORNIA"), "NorCal");
assert.equal(canonicalDivision("SO CALIFORNIA"), "SoCal");
assert.equal(canonicalDivision("JEWEL"), "Jewel Osco");
assert.equal(canonicalDivision("DENVER"), "Mountain West");
assert.equal(canonicalDivision("INTERMOUNTAIN"), "Mountain West");
assert.equal(canonicalStore("0117"), "117");
assert.equal(matchesDistrict("03", "3"), true);
assert.equal(matchesDistrict("D3", "3"), false);
assert.equal(matchesDistrict("62", "62 DEN WEST & MTNS"), true);
assert.equal(matchesDistrict("J1", "J1 NORTH SHORE"), true);
assert.equal(matchesDistrict("A1", "H1 NE PHILA SUBURB"), false);

const packHome = JSON.parse(readFileSync(join(root, "public/data/home.json"), "utf8"));
const packRoster = packHome.filters.stores;
const store53 = cascadePick(packRoster, { kind: "store", value: "53" });
assert.equal(storeLabel(53), "0053");
assert.equal(store53.store, "53");
assert.equal(store53.division, "Mid-Atlantic");
assert.equal(store53.district, "A1");
assert.equal(store53.region, "East Region");
assert.equal(store53.om, "Abraham Negussie");
const abraham = cascadePick(packRoster, { kind: "om", value: "Abraham Negussie" });
assert.equal(abraham.om, "Abraham Negussie");
assert.equal(abraham.division, "Mid-Atlantic");
assert.equal(abraham.district, "");
assert.equal(abraham.region, "East Region");
const phila = searchScope(packRoster, { region: "", division: "", district: "", om: "", store: "" }, "ne phila").flatMap((group) => group.hits);
assert.ok(phila.some((hit) => hit.kind === "district" && hit.value === "A1"));
const stores53 = searchScope(packRoster, { region: "", division: "", district: "", om: "", store: "" }, "53")
  .find((group) => group.group === "Store").hits;
assert.equal(stores53[0].label, "0053");
assert.equal(stores53[0].value, "53");
const mid = searchScope(packRoster, { region: "East Region", division: "", district: "", om: "", store: "" }, "mid");
assert.ok(mid.some((group) => group.hits.some((hit) => hit.value === "Mid-Atlantic")));
const up = filtersUpTo(store53, "division");
assert.equal(up.division, "Mid-Atlantic");
assert.equal(up.district, "");
assert.equal(up.store, "");
assert.deepEqual(scopeChips(store53).map((chip) => chip.label), ["Company", "East", "Mid-Atlantic", "A1", "Abraham Negussie", "0053"]);
const eastBrowse = browseLevel(packRoster, { region: "", division: "", district: "", om: "", store: "" });
assert.equal(eastBrowse.level, "region");
assert.ok(eastBrowse.rows.every((row) => row.count > 0));
const a1Browse = browseLevel(packRoster, { region: "East Region", division: "Mid-Atlantic", district: "", om: "", store: "" });
assert.equal(a1Browse.level, "district");
assert.ok(a1Browse.rows.some((row) => row.value === "A1" && row.count > 0 && row.label.includes("PHILA")));
const packSq = JSON.parse(readFileSync(join(root, "public/data/section/schedule_quality.json"), "utf8")).rows;
function sqCount(district) {
  return packSq.filter((row) => includesScope(row, filters({ district }), packRoster, "schedule_quality")).length;
}
const a1Store = packRoster.find((row) => row.district === "A1").store;
assert.equal(sqCount("A1"), 20);
assert.equal(sqCount("A9"), 23);
assert.equal(sqCount("U2"), 0);
assert.equal(sqCount("U7"), 0);
assert.equal(sqCount("62"), 23);
assert.equal(
  includesScope(
    { store: a1Store, division: "Mid-Atlantic", district: "H1 NE PHILA SUBURB" },
    filters({ district: "A1" }),
    packRoster,
    "schedule_quality",
  ),
  true,
);
assert.equal(
  includesScope(
    { store: a1Store, division: "Mid-Atlantic", district: "H1 NE PHILA SUBURB" },
    filters({ district: "A1" }),
    packRoster,
    "sales",
  ),
  false,
);
assert.equal(
  scheduleDistrictNote("schedule_quality", filters({ district: "U2" }), packRoster, sqCount("U2")),
  "No Schedule Quality data for this district.",
);
assert.equal(scheduleDistrictNote("schedule_quality", filters({ district: "A1" }), packRoster, sqCount("A1")), "");
assert.equal(emptyScopeNote("prep_not_ready", filters({ division: "Haggen" }), packRoster, 0), "No Prep data for this scope.");
assert.equal(emptyScopeNote("prep_not_ready", filters({ district: "A1" }), packRoster, 0), "No Prep data for this scope.");
assert.equal(emptyScopeNote("prep_not_ready", filters({ district: "U2" }), packRoster, 0), "No Prep data for this scope.");
assert.equal(emptyScopeNote("sales", filters({ district: "A1" }), packRoster, 0), "");
assert.equal(
  emptyScopeNote("schedule_quality", filters({ division: "United" }), packRoster, 0),
  "No Schedule Quality data for this scope.",
);
assert.equal(emptyScopeNote("schedule_quality", filters({ division: "Haggen" }), packRoster, 15), "");
assert.equal(emptyScopeNote("schedule_quality", filters({ district: "U2" }), packRoster, 0), "No Schedule Quality data for this district.");
const gapPack = {
  markets: [{ label: "United", under: null, over: null, eff: null }],
  stores: [
    { store: "22", region: "South Region", division: "United", under: null, over: null, eff: null },
    { store: "117", region: "East Region", division: "Shaws", under: 9, over: 4, eff: 85 },
  ],
};
assert.equal(scheduleGapNote(gapPack, filters({ division: "United" }), []), "No data");
assert.equal(scheduleGapNote(gapPack, empty, []), "United: No data");
assert.match(readFileSync(join(root, "public/schedule-math.js"), "utf8"), /No data/);
assert.match(app, /scheduleGapNote\(/);
assert.match(app, /blank \? "No data"/);
const blankUnited = summary(
  {
    markets: [{ label: "United", under: null, over: null, eff: null }],
    stores: [{ store: "22", region: "South Region", division: "United", under: null, over: null, eff: null }],
  },
  filters({ division: "United" }),
);
assert.equal(blankUnited.under, null);
assert.equal(blankUnited.over, null);
assert.equal(blankUnited.eff, null);
assert.match(app, /\["EOT", \["eot_capacity"\]/);
assert.match(app, /\["Used", \["used_capacity"\]/);
assert.match(app, /cooked shoppers/);
assert.match(app, /Company shoppers is the cooked company total/);
assert.match(css, /text-overflow:\s*ellipsis/);
assert.match(readFileSync(join(root, "public/_headers"), "utf8"), /\/data\/\*[\s\S]*private, no-store/);
assert.equal(storesForDistrict(packRoster, "62").size, 23);
assert.equal(shownDistrict("schedule_quality", "H1 NE PHILA SUBURB", "A1"), "A1 NE PHILA SUBURB");
assert.equal(shownDistrict("schedule_quality", "88 KINGS/BALDUCCIS", "A9"), "A9 KINGS/BALDUCCIS");
assert.equal(shownDistrict("schedule_quality", "62 DEN WEST & MTNS", "62"), "62 DEN WEST & MTNS");
assert.equal(shownDistrict("schedule_quality", "65 DENVER/SPRINGS", "66"), "66");
assert.equal(shownDistrict("sales", "62 DEN WEST & MTNS", "62"), "62 DEN WEST & MTNS");
assert.equal(shownDistrict("schedule_quality", "H1 NE PHILA SUBURB", ""), "H1 NE PHILA SUBURB");
assert.equal(packHome.laborMarket, undefined);
assert.equal(packHome.companyTiles.labor.values[packHome.companyTiles.labor.labels.indexOf("AIV")], "0.00%");
assert.equal(Number(lossPercentPoints(0.05189747740362091, 4248638.425832152, 81865991.15).toFixed(2)), 5.19);
assert.equal(lossPercentPoints(5.19, 4248638.425832152, 81865991.15), 5.19);
assert.equal(lossPercentPoints(4.84, 4.84, 1), 4.84);
assert.equal(
  includesScope({ division: "Shaws", district: "03", om: "Ada", store: "0117" }, filters({ region: "East Region" })),
  true,
);
assert.equal(
  includesScope({ division: "United", district: "03", om: "Ada", store: "200" }, filters({ region: "East Region" })),
  false,
);
assert.equal(
  includesScope({ division: "Jewel Osco", district: "J3", om: "Ada", store: "10" }, filters({ division: "Shaws" })),
  false,
);

const pack = {
  publishedAt: "2026-09-28T12:00:00Z",
  week: 32,
  summaryTitle: "Week 31",
  workbookActionBanner: 468,
  markets: [
    { label: "Total", under: 41.07, over: 4.03 },
    { label: "United", under: null, over: null },
  ],
  stores: [
    { store: "1", region: "South Region", division: "United", district: "U1", om: "A", sales: 40000, under: 20, over: 1, eff: 50, pch: 70, fourUnder: 1 },
    { store: "2", region: "South Region", division: "United", district: "U1", om: "A", sales: 40000, under: 100, over: 0, eff: 0, pch: 0, fourUnder: 0 },
  ],
};
const company = summary(pack, empty);
assert.equal(company.under, 41.07);
assert.equal(company.over, 4.03);
assert.equal(company.eff, 25);
assert.equal(company.usesMarketLook, true);
assert.match(companyMarketNote(company, empty), /Under 20\.00% \/ Over 1\.00%/);
const united = summary(pack, filters({ division: "United" }));
assert.equal(united.usesMarketLook, true);
assert.equal(united.under, null);
assert.equal(united.over, null);
const cut = summary(pack, filters({ division: "United", district: "U1" }));
assert.equal(cut.usesMarketLook, false);
assert.equal(cut.under, 20);
assert.equal(bannerMismatch(pack, company, empty), null);
assert.equal(company.actionCount, 1);
assert.equal(barelyScheduled({ under: 92.7, eff: 7.3 }), true);
assert.equal(barelyScheduled({ under: 89.9, eff: 10.1 }), false);
assert.equal(notScheduled({ under: 97.2, eff: 2.3 }), false);
assert.equal(
  qualifiesStore({ sales: 40000, under: 97.2, fourUnder: 0, over: 0, eff: 2.3 }),
  false,
);

function b64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function b64urlJson(value) {
  return b64url(new TextEncoder().encode(JSON.stringify(value)));
}

const pair = await crypto.subtle.generateKey(
  { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
  true,
  ["sign", "verify"],
);
const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
jwk.kid = "test";
jwk.alg = "RS256";
const header = b64urlJson({ alg: "RS256", kid: "test", typ: "JWT" });
const now = 1_700_000_000_000;

async function token(payload) {
  const body = b64urlJson(payload);
  const data = new TextEncoder().encode(`${header}.${body}`);
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", pair.privateKey, data));
  return `${header}.${body}.${b64url(signature)}`;
}

const good = await token({
  email: "reader@example.com",
  aud: "aud-tag",
  exp: Math.floor(now / 1000) + 60,
});
const verified = await verifyAccessJwt(good, { jwks: { keys: [jwk] }, aud: "aud-tag", now });
assert.equal(verified.ok, true);
assert.equal(verified.email, "reader@example.com");

const flipped = `${good.slice(0, -4)}AAAA`;
assert.equal((await verifyAccessJwt(flipped, { jwks: { keys: [jwk] }, aud: "aud-tag", now })).ok, false);
const wrongAud = await token({ email: "reader@example.com", aud: "other", exp: Math.floor(now / 1000) + 60 });
assert.equal((await verifyAccessJwt(wrongAud, { jwks: { keys: [jwk] }, aud: "aud-tag", now })).reason, "aud");
const expired = await token({ email: "reader@example.com", aud: "aud-tag", exp: Math.floor(now / 1000) - 10 });
assert.equal((await verifyAccessJwt(expired, { jwks: { keys: [jwk] }, aud: "aud-tag", now })).reason, "exp");

clearJwksCache();
const live = await token({
  email: "reader@example.com",
  aud: "aud-tag",
  exp: Math.floor(Date.now() / 1000) + 120,
});
const request = new Request("https://heartbeat.example/api/home", {
  headers: { "Cf-Access-Jwt-Assertion": live },
});
const env = { CF_ACCESS_TEAM_DOMAIN: "team.cloudflareaccess.com", CF_ACCESS_AUD: "aud-tag" };
const allowed = await authorize(request, env, "reader@example.com\n", async () => ({ keys: [jwk] }));
assert.equal(allowed.ok, true);
const denied = await authorize(request, env, "other@example.com\n", async () => ({ keys: [jwk] }));
assert.equal(denied.reason, "allowlist");
const emptyList = await authorize(request, env, "# nobody\n", async () => ({ keys: [jwk] }));
assert.equal(emptyList.reason, "allowlist");
const open = await authorize(new Request("http://localhost/api/home"), { HEARTBEAT_WEB_DEV: "1" }, "", async () => null);
assert.equal(open.ok, true);
const locked = await authorize(new Request("https://heartbeat.pages.dev/api/home"), { HEARTBEAT_WEB_DEV: "1" }, "reader@example.com\n");
assert.equal(locked.ok, false);

const publishScript = readFileSync(join(root, "../Tools/HeartbeatIngest/publish-web.sh"), "utf8");
assert.match(publishScript, /HEARTBEAT_UI_ONLY/);
assert.match(publishScript, /HEARTBEAT_USE_LOCAL_DATA/);
assert.match(publishScript, /fulfillment-heartbeat-web/);
assert.match(publishScript, /\{"error":"unauthorized"\}/);
assert.equal(publishScript.includes("--project-name heartbeat-web"), false);
const wrangler = readFileSync(join(root, "wrangler.toml"), "utf8");
assert.match(wrangler, /name = "fulfillment-heartbeat-web"/);
assert.match(wrangler, /pages_build_output_dir = "dist"/);
assert.match(wrangler, /binding = "HB_AUTH"/);
assert.match(wrangler, /database_name = "fulfillment-heartbeat-auth"/);
assert.match(wrangler, /646c017a-802f-4395-b635-d4b5bd66c1cb/);
assert.equal(wrangler.includes("heartbeat-web.pages.dev"), false);
const built = spawnSync(process.execPath, ["scripts/stage_pages.mjs"], { cwd: root });
assert.equal(built.status, 0, built.stderr.toString());
const distIndex = readFileSync(join(root, "dist/index.html"), "utf8");
assert.equal(distIndex.includes("HB-0828.494"), false);
assert.equal(distIndex.includes('id="stamp"'), false);
assert.match(distIndex, /class="header-foot"/);
assert.match(distIndex, /aria-label="Fulfillment Heartbeat"/);
assert.match(distIndex, /class="fulfill">Fulfill</);
assert.equal(distIndex.includes("pages.dev"), false);
assert.match(app, /class="figure"/);
assert.equal(statSync(join(root, "functions/api/[[path]].js")).isFile(), true);
assert.equal(statSync(join(root, "functions/_middleware.js")).isFile(), true);
const middleware = readFileSync(join(root, "functions/_middleware.js"), "utf8");
assert.match(middleware, /timingSafeEqual/);
assert.equal(middleware.includes("WWW-Authenticate"), false);
assert.equal(middleware.includes("BASIC_PASS="), false);
assert.equal(timingSafeEqualString("heartbeat", "heartbeat"), true);
assert.equal(timingSafeEqualString("heartbeat", "Heartbeat"), false);
assert.equal(timingSafeEqualString("a", "ab"), false);
const gateEnv = {
  BASIC_USER: "heartbeat",
  BASIC_PASS: "test-only-secret",
  BASIC_PASS_TESTER: "tester-only-secret",
  SESSION_SECRET: "unit-test-session-secret",
};
const authed = new Request("https://fulfillment-heartbeat-web.pages.dev/", {
  headers: { Authorization: `Basic ${Buffer.from("heartbeat:test-only-secret").toString("base64")}` },
});
const tester = new Request("https://fulfillment-heartbeat-web.pages.dev/", {
  headers: { Authorization: `Basic ${Buffer.from("tester:tester-only-secret").toString("base64")}` },
});
assert.equal(basicAuthOk(authed, gateEnv), true);
assert.equal(basicAuthOk(tester, gateEnv), true);
assert.equal(
  basicAuthOk(tester, { ...gateEnv, BASIC_USER_TESTER: "heartbeat-test" }),
  true,
);
assert.equal(
  basicAuthOk(
    new Request("https://fulfillment-heartbeat-web.pages.dev/", {
      headers: { Authorization: `Basic ${Buffer.from("heartbeat-test:tester-only-secret").toString("base64")}` },
    }),
    { ...gateEnv, BASIC_USER_TESTER: "heartbeat-test" },
  ),
  true,
);
assert.equal(basicAuthOk(new Request("https://fulfillment-heartbeat-web.pages.dev/"), gateEnv), false);
assert.equal(basicAuthOk(authed, {}), false);
assert.equal(basicAuthOk(tester, { BASIC_USER: "heartbeat", BASIC_PASS: "test-only-secret" }), false);
assert.equal(
  basicAuthOk(
    new Request("https://fulfillment-heartbeat-web.pages.dev/", {
      headers: { Authorization: `Basic ${Buffer.from("heartbeat:tester-only-secret").toString("base64")}` },
    }),
    gateEnv,
  ),
  false,
);
assert.equal(
  basicAuthOk(
    new Request("https://fulfillment-heartbeat-web.pages.dev/", {
      headers: { Authorization: `Basic ${Buffer.from("tester:test-only-secret").toString("base64")}` },
    }),
    gateEnv,
  ),
  false,
);
assert.equal(
  basicAuthOk(
    new Request("https://fulfillment-heartbeat-web.pages.dev/", {
      headers: { Authorization: `Basic ${Buffer.from("heartbeat:wrong").toString("base64")}` },
    }),
    gateEnv,
  ),
  false,
);
assert.match(middleware, /BASIC_PASS_TESTER/);
assert.match(middleware, /"tester"/);
assert.match(middleware, /AUTH_CUTOVER/);
assert.match(middleware, /HttpOnly/);
assert.match(middleware, /SameSite=Lax/);
const accountsSrc = readFileSync(join(root, "functions/accounts.js"), "utf8");
assert.match(accountsSrc, /autocomplete="current-password"/);
assert.match(accountsSrc, /autocomplete="username"/);
assert.match(accountsSrc, /autocomplete="new-password"/);
assert.match(accountsSrc, /name="email"/);
assert.match(accountsSrc, /minlength="10"/);
assert.match(accountsSrc, /PBKDF2/);
assert.match(app, /drawer-label">Settings/);
assert.match(app, /href="\/admin">User management/);
assert.match(app, /href="\/account">Account/);
assert.match(app, /accountSession\.role === "admin"/);
assert.match(app, /new URL\("\/session", location\.origin\)/);
assert.match(css, /\.drawer-settings a/);
assert.match(css, /\.drawer-label/);
assert.match(app, /authBlocked/);
assert.match(app, /retryHomeAfterAuth/);
assert.match(app, /location\.assign\("\/login"\)/);
assert.match(app, /new URL\("\/logout", location\.origin\)/);
assert.equal(app.includes('location.assign("/logout")'), false);
assert.equal(app.includes("logout:logout"), false);
assert.equal(app.includes("state.homeError = \"NO DATA\""), false);
assert.match(app, /data-logout>Logout/);
assert.match(css, /\.drawer-logout/);
const gateDenied = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/"),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(gateDenied.status, 200);
assert.equal(gateDenied.headers.get("WWW-Authenticate"), null);
const loginHTML = await gateDenied.text();
assert.match(loginHTML, /action="\/login"/);
assert.match(loginHTML, /type="email"/);
assert.match(loginHTML, /name="email"/);
assert.match(loginHTML, /type="password"/);
assert.match(loginHTML, /autocomplete="username"/);
assert.match(loginHTML, /autocomplete="current-password"/);
assert.match(loginHTML, /<span class="fulfill">Fulfill<\/span><span class="ment">ment<\/span>/);
assert.match(loginHTML, /src="\/nav-boot\.js\?v=2"/);
assert.equal(loginHTML.includes('class="header-back"'), false);
assert.match(accountsSrc, /class="header-back"/);
assert.match(accountsSrc, />Dashboard</);
assert.match(accountsSrc, /Back to Heartbeat/);
assert.match(accountsSrc, /aria-controls="drawer"/);
assert.match(accountsSrc, /"\/\?page=pph"/);
assert.match(accountsSrc, /"\/\?page=schedule"/);
assert.match(accountsSrc, /src="\/shell-nav\.js\?v=1"/);
assert.match(readFileSync(join(root, "public/login.css"), "utf8"), /\.header-back,\s*#nav-toggle \{[^}]*min-height:\s*44px/);
assert.match(app, /function applyPageQuery/);
assert.match(loginHTML, /href="\/favicon\.svg"/);
let bootServed = false;
const boot = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/nav-boot.js?v=2"),
  env: gateEnv,
  next: async () => {
    bootServed = true;
    return new Response("boot", { status: 200 });
  },
});
assert.equal(boot.status, 200);
assert.equal(bootServed, true);
assert.equal(await boot.text(), "boot");
let iconServed = false;
const icon = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/favicon.svg"),
  env: gateEnv,
  next: async () => {
    iconServed = true;
    return new Response("<svg></svg>", { status: 200, headers: { "content-type": "image/svg+xml" } });
  },
});
assert.equal(icon.status, 200);
assert.equal(iconServed, true);
assert.equal(loginHTML.includes("NO DATA"), false);
const dataDenied = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json"),
  env: gateEnv,
  next: async () => new Response("{}", { status: 200 }),
});
assert.equal(dataDenied.status, 401);
assert.equal(dataDenied.headers.get("content-type"), "application/json; charset=utf-8");
assert.equal(dataDenied.headers.get("cache-control"), "private, no-store");
assert.equal(dataDenied.headers.get("set-cookie"), null);
assert.equal(dataDenied.headers.get("WWW-Authenticate"), null);
assert.deepEqual(await dataDenied.json(), { error: "unauthorized" });
const signedIn = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/login", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: "username=heartbeat&password=test-only-secret",
  }),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(signedIn.status, 303);
assert.match(signedIn.headers.get("location"), /\/$/);
const setCookie = signedIn.headers.get("set-cookie") || "";
assert.match(setCookie, /hb_session=/);
assert.match(setCookie, /HttpOnly/);
assert.match(setCookie, /Secure/);
assert.match(setCookie, /SameSite=Lax/);
assert.match(setCookie, /Max-Age=2592000/);
const sessionCookie = setCookie.split(";")[0];
const opened = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: sessionCookie } }),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(opened.status, 200);
assert.equal(await opened.text(), "page");
const dataOpened = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", { headers: { cookie: sessionCookie } }),
  env: gateEnv,
  next: async () => new Response("{}", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(dataOpened.status, 200);
assert.equal(dataOpened.headers.get("cache-control"), "private, no-store");
const wrong = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/login", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: "username=heartbeat&password=wrong",
  }),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(wrong.status, 401);
assert.equal(wrong.headers.get("set-cookie"), null);
assert.match(await wrong.text(), /That email or password is wrong/);
const rotated = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: sessionCookie } }),
  env: { ...gateEnv, BASIC_PASS: "rotated-secret" },
  next: async () => new Response("page", { status: 200 }),
});
assert.match(await rotated.text(), /action="\/login"/);
const testerToken = await createSessionToken(gateEnv, "tester", "tester-only-secret");
const testerCookie = `hb_session=${testerToken}`;
const testerAfterMasterRotate = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: testerCookie } }),
  env: { ...gateEnv, BASIC_PASS: "rotated-secret" },
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(await testerAfterMasterRotate.text(), "page");
const testerAfterOwnRotate = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: testerCookie } }),
  env: { ...gateEnv, BASIC_PASS_TESTER: "rotated-tester" },
  next: async () => new Response("page", { status: 200 }),
});
assert.match(await testerAfterOwnRotate.text(), /action="\/login"/);
const stale = await createSessionToken(gateEnv, "heartbeat", "test-only-secret", 0);
const expiredSession = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: `hb_session=${stale}` } }),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.match(await expiredSession.text(), /action="\/login"/);
const flippedCookie = sessionCookie.slice(0, -1) + (sessionCookie.endsWith("a") ? "b" : "a");
const tampered = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: flippedCookie } }),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.match(await tampered.text(), /action="\/login"/);
const loggedOut = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/logout", { headers: { cookie: sessionCookie } }),
  env: gateEnv,
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(loggedOut.status, 302);
assert.match(loggedOut.headers.get("location"), /\/login$/);
assert.match(loggedOut.headers.get("set-cookie") || "", /Max-Age=0/);
const iconRedirect = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/favicon.ico"),
  env: gateEnv,
  next: async () => new Response("missing", { status: 404 }),
});
assert.equal(iconRedirect.status, 302);
assert.match(iconRedirect.headers.get("location") || "", /\/favicon\.svg$/);

const dataFiles = [
  "data/home.json",
  "data/presub.json",
  "data/schedule.json",
  "data/section/lost_revenue.json",
  "data/section/sales.json",
  "data/section/five_star.json",
  "data/section/pick_path.json",
  "data/section/dynacap.json",
  "data/section/schedule_quality.json",
  "data/section/labor.json",
  "data/section/picker_scorecard.json",
];
for (const file of dataFiles) {
  const text = readFileSync(join(root, "dist", file), "utf8").trim();
  assert.equal(text.startsWith("<"), false, file);
  JSON.parse(text);
}
const cooked = JSON.parse(readFileSync(join(root, "dist/data/home.json"), "utf8"));
assert.notEqual(cooked.publishedAt, "2026-09-30T18:23:22Z");
assert.match(cooked.publishedAt, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
assert.ok(cooked.filters.stores.length > 2000);
assert.equal(
  cooked.filters.stores.some((row) => String(row.store).toUpperCase() === "TOTAL"),
  false,
);
const bySection = Object.fromEntries(cooked.summaries.map((item) => [item.section, item.headline]));
assert.ok(bySection.lost_revenue > 0);
assert.ok(bySection.sales > 1_000_000);
assert.ok(bySection.picker_scorecard > 1000);
assert.ok(bySection.five_star > 0);
assert.ok(bySection.pick_path > 0);
assert.ok(bySection.dynacap > 0);
assert.ok(bySection.schedule_quality > 0);
assert.ok(bySection.labor != null);
const eastLoss = cooked.regionLines.find((line) => line.section === "lost_revenue" && line.region === "East");
assert.match(eastLoss.value, /^\$/);
assert.ok(eastLoss.children.some((child) => child.division === "Shaws"));
const lostTiles = cooked.companyTiles.lost_revenue;
assert.equal(cooked.publishedAt, "2026-10-05T22:57:06Z");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Lost %")], "0.05%");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Goal %")], "0.03%");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Missed")], "—");
const southDyn = cooked.regionLines.find((line) => line.section === "dynacap" && line.region === "South");
assert.equal(southDyn.children.some((child) => child.division === "United"), false);
assert.equal(southDyn.children.find((child) => child.division === "Southwest").value, "51.1");
assert.equal(southDyn.children.find((child) => child.division === "Southern").value, "71.0");
assert.equal(cooked.regionTables, undefined);
const eastDynacap = cooked.regionLines.find((line) => line.section === "dynacap" && line.region === "East");
const cookedMidAtlantic = (eastDynacap?.children || []).find((child) => child.division === "Mid-Atlantic");
assert.ok(cookedMidAtlantic, "cooked dynacap pack includes Mid-Atlantic");
const midRate = Number(String(cookedMidAtlantic.value).replace(/,/g, ""));
if (midRate >= 65) assert.equal(cookedMidAtlantic.health, "good");
else if (midRate >= 60) assert.equal(cookedMidAtlantic.health, "watch");
else assert.equal(cookedMidAtlantic.health, "risk");
const schedule = JSON.parse(readFileSync(join(root, "dist/data/schedule.json"), "utf8"));
const pickerFile = JSON.parse(readFileSync(join(root, "dist/data/section/picker_scorecard.json"), "utf8"));
assert.ok(pickerFile.rows.length > 1000);
assert.ok(pickerFile.rows.some((row) => row.shopper));
const pathPickers = JSON.parse(readFileSync(join(root, "dist/data/section/pick_path_picker.json"), "utf8"));
assert.ok(pathPickers.rows.length > 1000);
assert.equal(schedule.empty, undefined);
assert.equal(schedule.week, 32);
assert.equal(schedule.stores.length, 2163);
const liveCompany = summary(schedule, empty, []);
assert.equal(pct(liveCompany.eff), "88.44%");
const southSched = rankedRegions(schedule, empty, []).find((row) => row.region === "South Region");
assert.equal(pct(southSched.eff), "92.64%");
assert.equal(southSched.scope, 397);
assert.equal(pct(southSched.under), "3.05%");
assert.equal(pct(southSched.over), "5.91%");
assert.notEqual(pct(southSched.under), "34.28%");
const eastSched = rankedRegions(schedule, empty, []).find((row) => row.region === "East Region");
assert.notEqual(pct(eastSched.under), "29.40%");
const southOnly = summary(schedule, filters({ region: "South Region" }), []);
assert.equal(southOnly.scope, 397);
assert.equal(pct(southOnly.under), "3.05%");
const weightedPack = {
  markets: [
    { label: "Southern", under: 4, over: 5, eff: 90 },
    { label: "Southwest", under: 2, over: 6, eff: 92 },
  ],
  stores: [
    { store: "1", region: "South Region", division: "Southern", under: 4, over: 5, eff: 90 },
    { store: "2", region: "South Region", division: "Southern", under: 4, over: 5, eff: 90 },
    { store: "3", region: "South Region", division: "Southern", under: 100, over: 0, eff: 0 },
    { store: "4", region: "South Region", division: "Southwest", under: 2, over: 6, eff: 92 },
  ],
};
const weightedSouth = rankedRegions(weightedPack, empty, [])[0];
assert.equal(weightedSouth.under, 3.5);
assert.equal(weightedSouth.over, 5.25);
assert.equal(weightedSouth.eff, 90.5);
const weightedSummary = summary(weightedPack, empty, []);
assert.equal(weightedSummary.underCount, 3);
assert.equal(weightedSummary.storeUnder, 10 / 3);
assert.match(app, /function scheduleRate/);
assert.match(app, /if \(notScheduled\(store\)\) return "—"/);
assert.equal(pct(southOnly.eff), "92.64%");
const southDivisions = rankedDivisions(schedule, filters({ region: "South Region" }), []);
assert.equal(southDivisions.find((row) => row.division === "Southwest").scope, 190);
assert.equal(southDivisions.find((row) => row.division === "Southern").scope, 136);
assert.equal(southDivisions.find((row) => row.division === "United").scope, 71);
assert.equal(countStores(cooked.filters.stores, filters({ region: "South Region" })), 397);
const liveUnited = summary(schedule, filters({ division: "United" }), []);
assert.equal(liveUnited.under, null);
assert.equal(liveUnited.over, null);
assert.equal(pct(liveUnited.eff), "100.00%");
const unitedDivision = rankedDivisions(schedule, empty, []).find((row) => row.division === "United");
assert.equal(unitedDivision.under, null);
assert.equal(unitedDivision.over, null);
assert.equal(pct(unitedDivision.eff), "100.00%");
assert.equal(scheduleGapNote(schedule, filters({ division: "United" }), []), "");
assert.equal(scheduleGapNote(schedule, empty, []).includes("United: No data"), false);
assert.match(schedule.summaryTitle, new RegExp(`Week ${schedule.week}`));
assert.equal(schedule.summaryTitle.includes("Week 31"), false);
assert.match(scheduleVisibleTitle(schedule.summaryTitle, schedule.week), new RegExp(`Week ${schedule.week}`));
const storeOne = cooked.filters.stores.find((row) => row.store === "1");
assert.equal(isPersonOm(storeOne.om), true);
const quinnStores = cooked.filters.stores.filter((row) => row.om === "Andrew Quinn");
assert.ok(quinnStores.length > 1);
assert.ok(countStores(cooked.filters.stores, filters({ region: "East Region" })) > 400);

function d1From(raw) {
  return {
    prepare(sql) {
      const prepared = raw.prepare(sql);
      const bound = (params) => ({
        first: async () => prepared.get(...params) ?? null,
        all: async () => ({ results: prepared.all(...params) }),
        run: async () => {
          const info = prepared.run(...params);
          return { success: true, meta: { changes: info.changes ?? 0 } };
        },
      });
      return { bind: (...params) => bound(params), ...bound([]) };
    },
  };
}

function openAuth() {
  const raw = new DatabaseSync(":memory:");
  return { raw, db: d1From(raw) };
}

function accountEnv(db, extra = {}) {
  return {
    ...gateEnv,
    ADMIN_EMAIL: "admin@example.com",
    SETUP_SECRET: "setup-secret-value",
    HB_AUTH: db,
    ...extra,
  };
}

async function accountRequest(db, path, { method = "GET", body = "", cookie = "", headers = {}, env = null } = {}) {
  const requestHeaders = { ...headers };
  if (body) requestHeaders["content-type"] = "application/x-www-form-urlencoded";
  if (cookie) requestHeaders.cookie = cookie;
  return basicGate({
    request: new Request(`https://fulfillment-heartbeat-web.pages.dev${path}`, {
      method,
      headers: requestHeaders,
      body: body || undefined,
    }),
    env: env || accountEnv(db),
    next: async () => new Response("page", { status: 200 }),
  });
}

function cookieHeader(response) {
  return (response.headers.get("set-cookie") || "").split(";")[0];
}

function inviteToken(text) {
  const match = String(text).match(/\/invite\/([A-Za-z0-9_-]+)/);
  assert.ok(match, "expected an invite link");
  return match[1];
}

const passwordHash = await hashPassword("correct-horse");
assert.equal(await verifyPassword("correct-horse", passwordHash.salt, passwordHash.hash, passwordHash.iterations), true);
assert.equal(await verifyPassword("other-horse!!", passwordHash.salt, passwordHash.hash, passwordHash.iterations), false);
assert.equal(passwordHash.iterations, 100000);

const auth = openAuth();
const setupDenied = await accountRequest(auth.db, "/setup");
assert.equal(setupDenied.status, 404);
assert.equal(setupDenied.headers.get("cache-control"), "no-store");
const setupWrong = await accountRequest(auth.db, "/setup", { headers: { authorization: "Bearer not-the-secret-value" } });
assert.equal(setupWrong.status, 404);
const setupOk = await accountRequest(auth.db, "/setup", { headers: { authorization: "Bearer setup-secret-value" } });
assert.equal(setupOk.status, 200);
const setupBody = await setupOk.text();
assert.match(setupBody, /^email: admin@example.com/);
const adminInvite = inviteToken(setupBody);
const inviteForm = await accountRequest(auth.db, `/invite/${adminInvite}`);
const inviteHtml = await inviteForm.text();
assert.match(inviteHtml, /name="confirm"/);
assert.match(inviteHtml, /minlength="10"/);
assert.match(inviteHtml, /autocomplete="new-password"/);
const tooShort = await accountRequest(auth.db, `/invite/${adminInvite}`, {
  method: "POST",
  body: "password=short&confirm=short",
});
assert.equal(tooShort.status, 400);
assert.match(await tooShort.text(), /at least 10 characters/);
const mismatch = await accountRequest(auth.db, `/invite/${adminInvite}`, {
  method: "POST",
  body: "password=long-enough-1&confirm=long-enough-2",
});
assert.equal(mismatch.status, 400);
assert.match(await mismatch.text(), /do not match/);
const joined = await accountRequest(auth.db, `/invite/${adminInvite}`, {
  method: "POST",
  body: "password=long-enough-1&confirm=long-enough-1",
});
assert.equal(joined.status, 303);
const adminCookie = cookieHeader(joined);
assert.match(adminCookie, /^hb_session=[a-f0-9]{64}\.[a-f0-9]{64}$/);
const signedHome = await accountRequest(auth.db, "/", { cookie: adminCookie });
assert.equal(await signedHome.text(), "page");
const people = await accountRequest(auth.db, "/admin", { cookie: adminCookie });
assert.equal(people.status, 200);
const peopleHtml = await people.text();
assert.match(peopleHtml, /Email is off\. Copy the invite link\./);
assert.match(peopleHtml, /admin@example.com/);
assert.match(peopleHtml, /src="\/auth-copy\.js"/);
assert.match(peopleHtml, /class="header-back" href="\/"/);
assert.match(peopleHtml, />Dashboard</);
assert.match(peopleHtml, /Back to Heartbeat/);
assert.match(peopleHtml, /id="nav-toggle"/);
assert.match(peopleHtml, /href="\/\?page=labor"/);
assert.match(peopleHtml, /href="\/admin" aria-current="page">User management/);
const added = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: "action=add&email=Viewer@Example.com&role=viewer",
});
const addedHtml = await added.text();
assert.match(addedHtml, /viewer@example.com/);
assert.equal(addedHtml.includes("Email sent"), false);
const viewerInvite = inviteToken(addedHtml);
const viewerJoined = await accountRequest(auth.db, `/invite/${viewerInvite}`, {
  method: "POST",
  body: "password=viewer-pass-1&confirm=viewer-pass-1",
});
assert.equal(viewerJoined.status, 303);
const viewerCookie = cookieHeader(viewerJoined);
const viewerDenied = await accountRequest(auth.db, "/admin", { cookie: viewerCookie });
assert.equal(viewerDenied.status, 403);
const viewerDeniedHtml = await viewerDenied.text();
assert.match(viewerDeniedHtml, /Admins only/);
assert.match(viewerDeniedHtml, /class="header-back"/);
assert.match(viewerDeniedHtml, /href="\/account">Account/);
assert.equal(viewerDeniedHtml.includes(">User management<"), false);
const inviteReuse = await accountRequest(auth.db, `/invite/${viewerInvite}`, {
  method: "POST",
  body: "password=viewer-pass-9&confirm=viewer-pass-9",
});
assert.equal(inviteReuse.status, 400);
const pending = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: "action=add&email=pending@example.com&role=viewer",
});
const pendingToken = inviteToken(await pending.text());
const pendingId = auth.raw.prepare("SELECT id FROM users WHERE email = ?").get("pending@example.com").id;
const copied = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: `action=copy&user=${encodeURIComponent(pendingId)}`,
});
const copiedHtml = await copied.text();
assert.match(copiedHtml, /Copy this invite link/);
assert.match(copiedHtml, new RegExp(`/invite/${pendingToken}`));
const viewerId = auth.raw.prepare("SELECT id FROM users WHERE email = ?").get("viewer@example.com").id;
const disabled = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: `action=disable&user=${encodeURIComponent(viewerId)}`,
});
assert.match(await disabled.text(), /viewer@example.com is disabled/);
const viewerClosed = await accountRequest(auth.db, "/", { cookie: viewerCookie });
assert.match(await viewerClosed.text(), /action="\/login"/);
const viewerBlocked = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-1",
});
assert.equal(viewerBlocked.status, 401);
const enabled = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: `action=enable&user=${encodeURIComponent(viewerId)}`,
});
assert.match(await enabled.text(), /viewer@example.com is active/);
const viewerAgain = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-1",
});
assert.equal(viewerAgain.status, 303);
const reset = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: `action=reset&user=${encodeURIComponent(viewerId)}`,
});
const resetHtml = await reset.text();
assert.match(resetHtml, /set-password link/);
const resetToken = inviteToken(resetHtml);
const oldPassword = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-1",
});
assert.equal(oldPassword.status, 401);
assert.match(await oldPassword.text(), /invite link/);
const resetJoin = await accountRequest(auth.db, `/invite/${resetToken}`, {
  method: "POST",
  body: "password=viewer-pass-2&confirm=viewer-pass-2",
});
assert.equal(resetJoin.status, 303);
const adminId = auth.raw.prepare("SELECT id FROM users WHERE email = ?").get("admin@example.com").id;
const keepAdmin = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: `action=disable&user=${encodeURIComponent(adminId)}`,
});
assert.match(await keepAdmin.text(), /at least one admin/);
const removed = await accountRequest(auth.db, "/admin", {
  method: "POST",
  cookie: adminCookie,
  body: `action=remove&user=${encodeURIComponent(pendingId)}`,
});
assert.match(await removed.text(), /pending@example.com was removed/);
const accountLoggedOut = await accountRequest(auth.db, "/logout", { cookie: adminCookie });
assert.equal(accountLoggedOut.status, 302);
assert.match(accountLoggedOut.headers.get("set-cookie") || "", /Max-Age=0/);
const afterLogout = await accountRequest(auth.db, "/", { cookie: adminCookie });
assert.match(await afterLogout.text(), /action="\/login"/);
const privateData = await accountRequest(auth.db, "/data/home.json");
assert.equal(privateData.status, 401);
assert.equal(privateData.headers.get("cache-control"), "private, no-store");
assert.equal(privateData.headers.get("WWW-Authenticate"), null);
assert.equal(privateData.headers.get("set-cookie"), null);

const throttle = openAuth();
let throttleStatus = 0;
for (let attempt = 0; attempt < 8; attempt += 1) {
  const failed = await accountRequest(throttle.db, "/login", {
    method: "POST",
    body: "email=nobody@example.com&password=not-a-real-password",
  });
  throttleStatus = failed.status;
}
assert.equal(throttleStatus, 401);
const throttled = await accountRequest(throttle.db, "/login", {
  method: "POST",
  body: "email=nobody@example.com&password=not-a-real-password",
});
assert.equal(throttled.status, 429);

const legacy = openAuth();
const legacyIn = await accountRequest(legacy.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
});
assert.equal(legacyIn.status, 303);
assert.equal(legacy.raw.prepare("SELECT COUNT(*) AS n FROM login_attempts").get().n, 0);
const cutover = openAuth();
const cutoverDenied = await accountRequest(cutover.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  env: accountEnv(cutover.db, { AUTH_CUTOVER: "1" }),
});
assert.equal(cutoverDenied.status, 401);
const crossSite = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=admin@example.com&password=long-enough-1",
  headers: { origin: "https://evil.example" },
});
assert.equal(crossSite.status, 403);

const adminBack = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=admin@example.com&password=long-enough-1",
});
assert.equal(adminBack.status, 303);
const adminSession = await accountRequest(auth.db, "/session", { cookie: cookieHeader(adminBack) });
assert.equal(adminSession.status, 200);
assert.equal(adminSession.headers.get("cache-control"), "private, no-store");
assert.deepEqual(await adminSession.json(), { email: "admin@example.com", role: "admin", account: true });
const viewerBack = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-2",
});
assert.equal(viewerBack.status, 303);
const viewerSession = await accountRequest(auth.db, "/session", { cookie: cookieHeader(viewerBack) });
assert.deepEqual(await viewerSession.json(), { email: "viewer@example.com", role: "viewer", account: true });
const viewerAccount = await accountRequest(auth.db, "/account", { cookie: cookieHeader(viewerBack) });
assert.equal(viewerAccount.status, 200);
const viewerAccountHtml = await viewerAccount.text();
assert.match(viewerAccountHtml, /Change password|Current password/);
assert.match(viewerAccountHtml, /autocomplete="current-password"/);
assert.equal(viewerAccountHtml.includes("Add a person"), false);
const shortChange = await accountRequest(auth.db, "/account", {
  method: "POST",
  cookie: cookieHeader(viewerBack),
  body: "current=viewer-pass-2&password=short&confirm=short",
});
assert.equal(shortChange.status, 400);
const mismatchChange = await accountRequest(auth.db, "/account", {
  method: "POST",
  cookie: cookieHeader(viewerBack),
  body: "current=viewer-pass-2&password=viewer-pass-3&confirm=viewer-pass-9",
});
assert.equal(mismatchChange.status, 400);
const wrongCurrent = await accountRequest(auth.db, "/account", {
  method: "POST",
  cookie: cookieHeader(viewerBack),
  body: "current=not-the-password&password=viewer-pass-3&confirm=viewer-pass-3",
});
assert.equal(wrongCurrent.status, 401);
const secondViewer = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-2",
});
assert.equal(secondViewer.status, 303);
const changed = await accountRequest(auth.db, "/account", {
  method: "POST",
  cookie: cookieHeader(viewerBack),
  body: "current=viewer-pass-2&password=viewer-pass-3&confirm=viewer-pass-3",
});
assert.equal(changed.status, 200);
assert.match(await changed.text(), /Password saved/);
const oldSession = await accountRequest(auth.db, "/", { cookie: cookieHeader(secondViewer) });
assert.match(await oldSession.text(), /action="\/login"/);
const stillHere = await accountRequest(auth.db, "/", { cookie: cookieHeader(viewerBack) });
assert.equal(await stillHere.text(), "page");
const oldViewerPass = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-2",
});
assert.equal(oldViewerPass.status, 401);
const newViewerPass = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=viewer@example.com&password=viewer-pass-3",
});
assert.equal(newViewerPass.status, 303);
const legacySession = await accountRequest(legacy.db, "/session", { cookie: cookieHeader(legacyIn) });
assert.deepEqual(await legacySession.json(), { email: "heartbeat", role: "admin", account: false });
const legacyAccount = await accountRequest(legacy.db, "/account", { cookie: cookieHeader(legacyIn) });
const legacyAccountHtml = await legacyAccount.text();
assert.match(legacyAccountHtml, /does not have its own password/);
assert.match(legacyAccountHtml, /class="header-back"/);
assert.match(legacyAccountHtml, /href="\/admin">User management/);
assert.match(legacyAccountHtml, /Back to Heartbeat/);
const sessionDenied = await accountRequest(auth.db, "/session");
assert.equal(sessionDenied.status, 401);
const nullOrigin = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null" },
});
assert.equal(nullOrigin.status, 403);
const sameOriginLogin = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "https://fulfillment-heartbeat-web.pages.dev" },
});
assert.equal(sameOriginLogin.status, 303);

console.log("web ok");
