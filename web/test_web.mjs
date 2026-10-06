import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { DatabaseSync } from "node:sqlite";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { hashPassword, verifyPassword } from "./functions/accounts.js";
import {
  basicAuthOk,
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
import { checkPack, cookedAtPublishErrors, currencyPrecisionErrors, lostRollupErrors, packIdentityErrors, storeCountErrors, workbookTotalErrors } from "./check_pack.mjs";
import { PACK_FILES, PACK_POINTER_KEY, PINNED_FILE_SHA256, PINNED_HOME_SHA256, PINNED_LIVE_COOK_SHA, PINNED_LIVE_PREFIX, PINNED_LIVE_PUBLISHED_AT, guardHome, isPinnedLivePack, packApiPath, packObjectKey, packPrefix, rawDivisionName, readPackObject, resetPackCache, sha256Hex } from "./functions/pack-store.js";
import { bannerText, buildLabel, considerPublished, formatHeadline, money, pct, publishClock, publishStamp, updatedLine } from "./public/clock.js";
import { SCHEMA_VERSION, WORKBOOK_TOTAL_FIELDS, schemaWarning } from "./public/schema.js";
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
  regionStoreCount,
  scopeChips,
  filtersUpTo,
  browseLevel,
  storeLabel,
} from "./public/filters.js";
import { FIGURE_SECTIONS, packMissPlan, packPinQuery, packURL } from "./public/packs.js";
import { healthWord, mailtoURL, shareBrief, shareEml, shareHtml, sharePages, shareSubject } from "./public/share.js";
import { SCOPE_BADGES, browseCountText, chromeSeat, companyCountText, distinctShopperCount, divisionChipTitle, figureAbsent, formatCompanyAiv, laborGrainValue, LOST_EXCL_LABEL, lossPercentPoints, lostExclMissed, lostGrainRows, metricCountLine, partialCountLine, pickerScopeHealth, pickerShopperBands, reportedStoreLine, rowsInScope, scopeHealth, seatSummary, sectionRowGrain, sectionStoreCount, summarizeSeat } from "./public/seat.js";
import { metricsInSource, pphBar, shopperHoursText, shopperIdentity, shopperMatchesQuery, sortShoppersByPph } from "./public/shoppers.js";
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
assert.equal(packApiPath("/api/home"), "home.json");
assert.equal(packApiPath("/api/section/labor"), "section/labor.json");
assert.equal(packApiPath("/api/schedule"), "schedule.json");
assert.equal(packApiPath("/api/web-pack/home.json"), "");
assert.equal(packApiPath("https://example.r2.dev/home"), "");
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
assert.equal(
  packURL("section/labor", "", "cookSha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&publishedAt=2026-10-06T01%3A35%3A23Z"),
  "/data/section/labor.json?cookSha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&publishedAt=2026-10-06T01%3A35%3A23Z",
);
assert.equal(
  packPinQuery({
    cookSha: "a".repeat(40),
    publishedAt: "2026-10-06T01:35:23Z",
    cookedAt: "2026-10-07T00:00:00Z",
  }),
  `cookSha=${"a".repeat(40)}&publishedAt=2026-10-06T01%3A35%3A23Z&cookedAt=2026-10-07T00%3A00%3A00Z`,
);
assert.equal(packPinQuery({ cookSha: "a".repeat(40) }), "");
assert.equal(packMissPlan({ path: "section/labor", status: 404, pin: "cookSha=abc", repinned: false }), "repin");
assert.equal(packMissPlan({ path: "section/labor", status: 404, pin: "cookSha=abc", repinned: true }), "fail");
assert.equal(packMissPlan({ path: "home", status: 404, pin: "cookSha=abc", repinned: false }), "fail");
assert.equal(packMissPlan({ path: "section/labor", status: 404, pin: "", repinned: false }), "fail");
assert.equal(packMissPlan({ path: "section/labor", status: 500, pin: "cookSha=abc", repinned: false }), "retry");
assert.match(app, /packMissPlan/);
assert.match(app, /error\.status = response\.status/);
assert.match(app, /state\.packs\.clear\(\)/);
assert.match(app, /state\.failedPacks\.clear\(\)/);
assert.match(app, /acceptHome\(home\)/);
assert.equal(app.includes('state.packs.delete("home")'), false);
assert.match(app, /return fetchPack\(path, true\)/);
assert.match(app, /packPinQuery/);
assert.match(app, /state\.packPin/);
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
assert.equal(SCOPE_BADGES.five_star.good, 4);
assert.equal(SCOPE_BADGES.schedule_quality.good, 90);
assert.equal(SCOPE_BADGES.labor.good, 0);
assert.equal(SCOPE_BADGES.picker_scorecard.good, 80);
assert.equal(scopeHealth("five_star", 4.2), "good");
assert.equal(scopeHealth("five_star", 3.38), "risk");
assert.equal(scopeHealth("labor", -4.062248206528947), "good");
assert.equal(scopeHealth("schedule_quality", 90.2), "good");
assert.equal(
  summarizeSeat("schedule_quality", [
    { store: "1", payload: { schedule_efficiency_pct: 95, over_schedule_pct: 9 } },
    { store: "2", payload: { schedule_efficiency_pct: 95, over_schedule_pct: 1 } },
  ]).health,
  "good",
);
const pickerBadgeRows = [{ payload: { pph: 50 } }, ...Array.from({ length: 10 }, () => ({ payload: { pph: 80 } }))];
assert.equal(pickerScopeHealth(pickerBadgeRows), "watch");
assert.notEqual(pickerScopeHealth([{ payload: { pph: 20 } }]), "good");

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
assert.match(app, /tables: \(state\.home && state\.home\.regionTables\) \|\| \[\]/);
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
const laborLines = [
  {
    section: "labor",
    region: "East",
    value: "-8.59%",
    count: 609,
    health: "risk",
    children: [{ division: "Mid-Atlantic", value: "-13.59%", count: 285, health: "risk" }],
  },
];
const laborTables = [{ section: "labor", region: "East", headline: "-3.97%", storeCount: 609, health: "good" }];
const laborEast = seatSummary("labor", {
  lines: laborLines,
  tables: laborTables,
  rows: [],
  filters: filters({ region: "East Region" }),
});
assert.equal(laborEast.headlineText, "-3.97%");
const laborEastLine = seatSummary("labor", {
  lines: laborLines,
  rows: [],
  filters: filters({ region: "East Region" }),
});
assert.equal(laborEastLine.headlineText, "-8.59%");
const laborDivision = seatSummary("labor", {
  lines: laborLines,
  tables: laborTables,
  rows: [],
  filters: filters({ division: "Mid-Atlantic" }),
});
assert.equal(laborDivision.headlineText, "-13.59%");
assert.equal(laborGrainValue(laborTables, { grain: "region", label: "East", value: "-8.59%" }), "-3.97%");
assert.equal(laborGrainValue(laborTables, { grain: "division", label: "Mid-Atlantic", value: "-13.59%" }), "-13.59%");
const lostScopeRows = [
  { store: "1", division: "Shaws", district: "03", payload: { lost_revenue: 100, missed_sales: 40 } },
  { store: "2", division: "Jewel Osco", district: "04", payload: { lost_revenue: 50 } },
  { store: "210", division: "United", district: "U5", payload: { lost_revenue: 263 } },
];
const eastLost = seatSummary("lost_revenue", {
  company: { headline: 4248638.426, secondary: "workbook", health: "risk", storeCount: 2165 },
  lines: [{ section: "lost_revenue", region: "East", value: "$9,999.00", count: 2, title: "Loss", children: [] }],
  rows: lostScopeRows,
  filters: filters({ region: "East Region" }),
});
assert.equal(eastLost.figureLabel, LOST_EXCL_LABEL);
assert.equal(eastLost.headline, 110);
assert.equal(eastLost.missed, "Not available");
assert.equal(eastLost.storeCount, 2);
assert.deepEqual(lostExclMissed(lostScopeRows), { sum: 373, count: 3 });
assert.equal(lostGrainRows(lostScopeRows, filters({}), lostScopeRows).find((row) => row.label === "South").value, 263);
assert.equal(eastSeat.headline, null);
assert.equal(eastSeat.secondary, "1 up · 0 flat · 1 down");
assert.equal(eastSeat.storeCount, 615);
const shawsSeat = seatSummary("sales", {
  company: companySales,
  lines: eastLines,
  rows: eastStores,
  filters: filters({ region: "East Region", division: "Shaws" }),
});
assert.equal(shawsSeat.headlineText, "$10.00");
assert.equal(shawsSeat.workbook, false);
assert.equal(
  eastSeat.health,
  summarizeSeat("sales", rowsInScope(eastStores, filters({ region: "East Region" }), [], "sales")).health,
);
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
assert.match(pageHtml, /src="\/nav-boot\.js\?v=3"/);
assert.equal(/<script>\s*try/.test(pageHtml), false);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /nav-collapsed/);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /new URL\(location\.href\)/);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /url\.username/);
assert.equal(readFileSync(join(root, "public/nav-boot.js"), "utf8").includes("location.username"), false);
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
assert.match(pageHtml, /app\.css\?v=28/);
assert.match(css, /#scope-search,\s*#browse-open,\s*#share-open,\s*#clear-filters \{[^}]*height:\s*44px/);
assert.match(css, /\.chip-row #clear-filters \{[^}]*height:\s*44px/);
assert.match(css, /\.chip-row #clear-filters \{[^}]*min-height:\s*44px/);
assert.match(pageHtml, /id="scope-search"/);
assert.match(pageHtml, /id="clear-filters"/);
assert.match(pageHtml, /aria-label="Share"/);
assert.match(pageHtml, /app\.css\?v=28/);
assert.match(pageHtml, /app\.js\?v=45/);
assert.equal(buildLabel("1aeee20", "40"), "1aeee20 · v40");
assert.equal(buildLabel("1AEEE20deadbeef", "v40"), "1aeee20 · v40");
assert.equal(buildLabel("__BUILD_SHA__", "40"), "");
assert.match(app, /const APP_VERSION = "45"/);
assert.match(app, /const BUILD_SHA = "__BUILD_SHA__"/);
assert.match(app, /id="build-stamp"/);
assert.match(app, /Build \$\{esc\(buildLine\)\}/);
assert.equal(companyCountText(2165, true), "Loading…");
assert.equal(companyCountText(2165, true).includes("2165"), false);
assert.equal(/\d/.test(companyCountText(null, true)), false);
assert.equal(companyCountText(2167, false), "2,167 stores");
assert.equal(reportedStoreLine(null, "2,165 stores reported · 9/27", true), "Loading…");
assert.equal(/\d/.test(reportedStoreLine(2165, "2,165 stores reported · 9/27", true)), false);
assert.equal(reportedStoreLine(2167, "2,165 stores reported · 9/27", false), "2,167 stores reported · 9/27");
assert.equal(reportedStoreLine(2167, "2,165 stores reported · 9/27", false).includes("2,165"), false);
assert.equal(browseCountText(2167, true), "Loading…");
assert.equal(/\d/.test(browseCountText(29923, true)), false);
assert.equal(browseCountText(1842, false), "1,842");
assert.equal(browseCountText(0, false), "0");
assert.equal(browseCountText(null, false), "");
assert.match(app, /sectionPackPending\(section\)\) return browseCountText/);
assert.equal(app.includes("browseCountText(item.count"), false);
assert.match(app, /if \(state\.browseOpen\) paintBrowse\(\)/);
const pickerLoad = app.slice(app.indexOf('if (page.section === "picker_scorecard")'), app.indexOf("await renderMetric"));
assert.match(pickerLoad, /loadOptional\(path\)/);
assert.equal(pickerLoad.includes("shopperSeat(state.filters) && !state.packs.has(path)"), false);
assert.match(pickerLoad, /paintBrowse\(\)/);
assert.match(app, /function companyCountLabel/);
assert.match(app, /function companySecondaryText/);
assert.match(app, /summarizeSeat\(section, rowsInScope/);
assert.match(css, /\.scope-chip,\s*\n\.scope-reset \{[^}]*height:\s*44px/);
assert.match(css, /\.scope-chip,\s*\n\.scope-reset \{[^}]*min-height:\s*44px/);
assert.match(css, /\.scope-reset \{[^}]*width:\s*44px/);
assert.match(css, /\.scope-reset \{[^}]*min-width:\s*44px/);
assert.match(css, /\.scope-reset \{[^}]*place-items:\s*center/);
assert.match(css, /\.scroll th \{[^}]*position:\s*sticky/);
assert.match(css, /\.scroll th \{[^}]*top:\s*0/);
assert.match(css, /\.scroll th \{[^}]*z-index:\s*2/);
assert.match(css, /\.scroll th \{[^}]*background:\s*var\(--table\)/);
assert.equal(/\.top \{[^}]*position:\s*sticky/.test(css), false);
assert.equal(/\.sticky-top \{[^}]*position:\s*sticky/.test(css), false);
assert.match(app, /headerStoreCount/);
assert.match(app, /LOST_EXCL_LABEL/);
assert.match(app, /schema\.js\?v=1/);
assert.match(app, /console\.warn\(staleSchema\)/);
assert.match(app, /raiseBanner\(staleSchema \|\| considerPublished/);
assert.equal(SCHEMA_VERSION, 1);
assert.equal(schemaWarning({ metadata: { schemaVersion: SCHEMA_VERSION } }), "");
assert.equal(schemaWarning({ metadata: { schemaVersion: SCHEMA_VERSION + 1 } }), "");
assert.match(schemaWarning({}), /schema missing/);
assert.match(schemaWarning({ metadata: { schemaVersion: 0 } }), /schema 0/);
assert.match(schemaWarning({ metadata: { schemaVersion: SCHEMA_VERSION - 1 } }), /schema 0/);
const renderSrc = app.slice(app.indexOf("async function render("), app.indexOf("function desktopNav("));
assert.equal(renderSrc.includes("await ensureSeatRows"), false);
assert.match(app, /source data issue/);
assert.match(app, /async function ensureSeatRows\(pages\)/);
assert.match(app, /page\.section !== "picker_scorecard"/);
const seatRowsSrc = app.slice(app.indexOf("async function ensureSeatRows"), app.indexOf("function seatFigure"));
assert.match(seatRowsSrc, /regionOnly && seatReady\(page\.section\)/);
assert.equal(seatRowsSrc.includes("PAGES.filter"), false);
assert.match(app, /\["Missed", \["missed_sales"\], money\]/);
assert.equal(app.includes('["missed_sales", "reduced_capacity"]'), false);
assert.match(app, /<th>Region<\/th>/);
assert.equal(app.includes("location.username"), false);
assert.equal(readFileSync(join(root, "public/nav-boot.js"), "utf8").includes("location.username"), false);
assert.match(readFileSync(join(root, "public/seat.js"), "utf8"), /between 74 and 80/);
assert.match(renderSrc, /renderDashboard\(\);\s*warmDashboard\(token\)/);
assert.match(renderSrc, /renderPicker\(\)/);
assert.equal(renderSrc.includes('await load("section/picker_scorecard")'), false);
assert.match(app, /function seatReady/);
assert.match(app, /function warmDashboard/);
assert.match(app, /Shopper tape stays parked/);
assert.match(app, /Schedule stores/);
assert.match(pageHtml, /rel="icon" href="\/favicon\.svg"/);
assert.match(pageHtml, /rel="icon" href="\/favicon-32\.png" type="image\/png" sizes="32x32"/);
assert.match(pageHtml, /rel="icon" href="\/favicon-16\.png" type="image\/png" sizes="16x16"/);
assert.match(pageHtml, /rel="apple-touch-icon" href="\/apple-touch-icon\.png"/);
assert.match(css, /\.heart \{[^}]*z-index:\s*2/);
assert.match(css, /\.pulse \{[^}]*margin-left:\s*-20px/);
assert.equal(/<script(?![^>]*\bsrc=)/.test(pageHtml), false);
assert.match(pageHtml, /<script src="\/nav-boot\.js\?v=3"><\/script>/);
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
assert.equal(app.includes("Labor Sch Eff workbook total"), false);
assert.match(app, /workbook roll-up/);
assert.match(app, /store average/);
assert.match(app, /PPH store average/);
assert.match(app, /store sum/);
assert.equal(divisionChipTitle("sales", "Sales"), "Sales store sum");
assert.equal(divisionChipTitle("labor", "Labor"), "Labor store average");
assert.equal(divisionChipTitle("lost_revenue", "Lost"), "Lost");
assert.match(app, /divisionChipTitle\(section, row\.title\)/);
assert.equal(partialCountLine(2089, 2164), "2,089 of 2,164");
assert.equal(partialCountLine(2164, 2164), "");
assert.equal(partialCountLine(0, 2164), "");
assert.match(app, /Quality Sch Eff is the average schedule efficiency on the Schedule Quality sheet/);
assert.match(readFileSync(join(root, "public/seat.js"), "utf8"), /export function formatCompanyAiv/);
assert.match(app, /formatCompanyAiv\(aiv\)/);
assert.match(app, /laborMarket/);
assert.equal(formatCompanyAiv(0.002610916545167652), "0.00%");
assert.equal(shopperHoursText(-0.45583333333333337, (value) => value.toFixed(1)), "source data issue");
assert.equal(shopperHoursText(1.2, (value) => value.toFixed(1)), "1.2");
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
assert.equal(fn.includes("bucket.get"), false);

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
assert.equal(notScheduled({ under: 4, eff: 0 }), true);
assert.equal(notScheduled({ under: 100, eff: null }), true);
assert.equal(notScheduled({ under: 100, eff: -17.777778 }), true);
assert.equal(notScheduled({ under: 100, eff: -282.352941 }), true);
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
assert.equal(app.includes("cooked shoppers"), false);
assert.match(app, /distinct shopper IDs on the picker rows/);
assert.match(app, /workbook total/);
assert.match(css, /@media \(max-width: 800px\)[\s\S]*\.line-value strong \{[^}]*white-space:\s*normal/);
assert.match(css, /@media \(max-width: 800px\)[\s\S]*overflow-wrap:\s*anywhere/);
assert.match(readFileSync(join(root, "public/_headers"), "utf8"), /\/data\/\*[\s\S]*private, no-store/);
assert.equal(storesForDistrict(packRoster, "62").size, 23);
assert.equal(shownDistrict("schedule_quality", "H1 NE PHILA SUBURB", "A1"), "A1 NE PHILA SUBURB");
assert.equal(shownDistrict("schedule_quality", "88 KINGS/BALDUCCIS", "A9"), "A9 KINGS/BALDUCCIS");
assert.equal(shownDistrict("schedule_quality", "62 DEN WEST & MTNS", "62"), "62 DEN WEST & MTNS");
assert.equal(shownDistrict("schedule_quality", "65 DENVER/SPRINGS", "66"), "66");
assert.equal(shownDistrict("sales", "62 DEN WEST & MTNS", "62"), "62 DEN WEST & MTNS");
assert.equal(shownDistrict("schedule_quality", "H1 NE PHILA SUBURB", ""), "H1 NE PHILA SUBURB");
assert.equal(shownDistrict("schedule_quality", "A1", "A1"), "A1 NE PHILA SUBURB");
assert.equal(shownDistrict("schedule_quality", "82", "82"), "82 BALTIMORE");
assert.equal(shownDistrict("schedule_quality", "87", "87"), "87 ARLGTN/ALXNDRIA");
assert.equal(shownDistrict("schedule_quality", "A9", "A9"), "A9 KINGS/BALDUCCIS");
assert.equal(packHome.laborMarket.weight, undefined);
assert.ok(Math.abs(packHome.laborMarket.aiv_impact_pct - 0.002610916545167652) < 1e-12);
assert.ok(
  Math.abs(
    packHome.laborMarket.uplh_impact_pct +
      packHome.laborMarket.wage_impact_pct +
      packHome.laborMarket.aiv_impact_pct -
      packHome.laborMarket.target_vs_actual_pct,
  ) <= 0.01,
);
assert.equal(packHome.companyTiles.labor.values[packHome.companyTiles.labor.labels.indexOf("AIV")], "0.00%");
assert.equal(packHome.metadata.schemaVersion, SCHEMA_VERSION);
assert.match(packHome.metadata.cookSha, /^[0-9a-f]{40}$/);
const badPack = mkdtempSync(join(tmpdir(), "hb-pack-"));
writeFileSync(join(badPack, "home.json"), "{}\n");
const badCheck = spawnSync(process.execPath, [join(root, "check_pack.mjs"), badPack], { encoding: "utf8" });
assert.notEqual(badCheck.status, 0);
assert.match(badCheck.stderr, /schemaVersion=missing/);
assert.match(badCheck.stderr, /cookSha missing/);
rmSync(badPack, { recursive: true, force: true });
const livePack = join(root, "public/data");
const liveCheck = spawnSync(process.execPath, [join(root, "check_pack.mjs"), livePack], { encoding: "utf8" });
assert.notEqual(liveCheck.status, 0);
assert.match(liveCheck.stderr, /cookedAt missing/);
assert.match(liveCheck.stderr, /pinned live cook cannot be republished/);
const liveErrors = checkPack(livePack).errors;
assert.ok(liveErrors.some((item) => item.includes("cookedAt missing")));
assert.equal(liveErrors.some((item) => item.includes("workbookTotal")), false);
assert.deepEqual(workbookTotalErrors({ metadata: { schemaVersion: SCHEMA_VERSION, cookSha: "a".repeat(40) } }), []);
assert.ok(workbookTotalErrors({ cookedAt: "2026-10-07T00:00:00Z" }).some((item) => item === "workbookTotal missing"));
const workbookBlock = {};
for (const [section, fields] of Object.entries(WORKBOOK_TOTAL_FIELDS)) {
  workbookBlock[section] = Object.fromEntries(fields.map((field) => [field, 1]));
}
assert.deepEqual(workbookTotalErrors({ cookedAt: "2026-10-07T00:00:00Z", workbookTotal: workbookBlock }), []);
const missingField = structuredClone(workbookBlock);
delete missingField.dynacap.pieces_per_hour;
assert.ok(
  workbookTotalErrors({ cookedAt: "2026-10-07T00:00:00Z", workbookTotal: missingField }).some((item) =>
    item.includes("dynacap.pieces_per_hour"),
  ),
);
assert.ok(liveErrors.some((item) => item.includes("storeCount=")));
assert.ok(liveErrors.some((item) => item.includes("currency")));
assert.ok(liveErrors.some((item) => item.startsWith("lost ")));
const liveRepublish = spawnSync(process.execPath, [join(root, "check_pack.mjs"), "--cooked-at", livePack], { encoding: "utf8" });
assert.notEqual(liveRepublish.status, 0);
assert.match(liveRepublish.stderr, /refusing publish: cookedAt is missing/);
assert.match(liveRepublish.stderr, /pinned live cook cannot be republished/);
const otherCook = mkdtempSync(join(tmpdir(), "hb-nocook-"));
const otherSha = "e".repeat(40);
writeFileSync(
  join(otherCook, "home.json"),
  JSON.stringify({
    publishedAt: "2026-10-06T01:35:23Z",
    schemaVersion: SCHEMA_VERSION,
    cookSha: otherSha,
  }),
);
const otherRefused = spawnSync(process.execPath, [join(root, "check_pack.mjs"), "--cooked-at", otherCook], { encoding: "utf8" });
assert.notEqual(otherRefused.status, 0);
assert.match(otherRefused.stderr, /refusing publish: cookedAt is missing/);
assert.match(otherRefused.stderr, /cookedAt missing/);
assert.equal(otherRefused.stderr.includes("pinned live cook"), false);
assert.ok(cookedAtPublishErrors(otherCook).some((item) => item.includes("cookedAt missing")));
rmSync(otherCook, { recursive: true, force: true });
const cookedPack = mkdtempSync(join(tmpdir(), "hb-cooked-"));
writeFileSync(
  join(cookedPack, "home.json"),
  JSON.stringify({
    publishedAt: "2026-10-06T01:35:23Z",
    schemaVersion: SCHEMA_VERSION,
    cookSha: otherSha,
    cookedAt: "2026-10-07T00:00:00Z",
  }),
);
const cookedOk = spawnSync(process.execPath, [join(root, "check_pack.mjs"), "--cooked-at", cookedPack], { encoding: "utf8" });
assert.equal(cookedOk.status, 0, cookedOk.stderr);
assert.equal(cookedAtPublishErrors(cookedPack).length, 0);
rmSync(cookedPack, { recursive: true, force: true });
assert.ok(Array.isArray(packHome.regionTables) && packHome.regionTables.length > 10);
const rosterByStore = Object.fromEntries(packHome.filters.stores.map((row) => [row.store, row]));
assert.equal(rosterByStore["233"].division, "Seattle");
assert.equal(rosterByStore["339"].division, "Mountain West");
assert.equal(rosterByStore["879"].division, "Mountain West");
assert.equal(rosterByStore["1509"].division, "Mountain West");
assert.equal(rosterByStore["4799"].division, "Jewel Osco");
assert.equal(rosterByStore["4799"].district, "J6");
assert.equal(rosterByStore["210"].om, "Andrew Quinn");
assert.equal(rosterByStore["239"].om, "Ben Sarmadi");
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
assert.equal(cut.eff, 50);
const negativeEff = {
  stores: [
    { store: "2575", region: "East Region", division: "Shaws", district: "B1", om: "Olivia Sullivan", sales: 40000, under: 10, over: 1, eff: -12000, pch: 1 },
    { store: "10", region: "East Region", division: "Shaws", district: "B1", om: "Olivia Sullivan", sales: 40000, under: 4, over: 2, eff: 80, pch: 1 },
    { store: "11", region: "East Region", division: "Shaws", district: "B1", om: "Olivia Sullivan", sales: 40000, under: 6, over: 3, eff: 0, pch: 1 },
  ],
};
const districtB1 = summary(negativeEff, filters({ district: "B1" }), []);
assert.equal(districtB1.eff, 80);
const omEff = summary(negativeEff, filters({ om: "Olivia Sullivan" }));
assert.equal(omEff.eff, 80);
const store2575 = summary(negativeEff, filters({ store: "2575" }), []);
assert.equal(store2575.eff, null);
assert.equal(notScheduled(negativeEff.stores[0]), true);
assert.equal(rankedDivisions(negativeEff, filters({ district: "B1" }), [])[0].eff, 80);
assert.equal(rankedRegions(negativeEff, filters({ om: "Olivia Sullivan" }))[0].eff, 80);
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
assert.match(publishScript, /node "\$WEB\/check_pack\.mjs" "\$PACK_DIR"/);
assert.match(publishScript, /node "\$WEB\/check_pack\.mjs" --cooked-at "\$PACK_DIR"/);
assert.match(publishScript, /refusing deploy: pack data must publish through the pointer/);
assert.equal(publishScript.includes('preflight "$DATA"'), false);
assert.match(publishScript, /python3 - "\$PACK_DIR"/);
assert.match(publishScript, /refusing publish: cookedAt is missing/);
assert.match(publishScript, /behind origin/);
assert.match(publishScript, /HEARTBEAT_DATA_ONLY/);
assert.match(publishScript, /pack_identity\.py/);
assert.match(publishScript, /pack_publish\.py/);
assert.match(publishScript, /cook-guard\.sh" --publish/);
assert.match(publishScript, /cook-guard\.sh" --publish-data/);
assert.match(publishScript, /pack_publish\.py" preflight/);
assert.match(publishScript, /new cook stays out of tracked web\/public\/data/);
assert.equal(publishScript.includes("live pack stays out of tracked web/public/data"), false);
assert.match(publishScript, /python3 - "\$PACK_DIR" "\$EMAIL_FILE"/);
assert.equal(publishScript.includes('python3 - "$DATA" "$EMAIL_FILE"'), false);
assert.match(publishScript, /local pack is older or the stamps disagree/);
assert.match(publishScript, /--defer-pointer/);
assert.match(publishScript, /--commit-pointer/);
const pagesDeployAt = publishScript.indexOf("npx wrangler pages deploy");
const pointerCommitAt = publishScript.indexOf("--commit-pointer");
assert.ok(pagesDeployAt !== -1 && pointerCommitAt > pagesDeployAt);
const trapAt = publishScript.indexOf("trap cleanup_stages EXIT");
const extractTempAt = publishScript.indexOf('EXTRACT="$(mktemp -d)"');
const liveTempAt = publishScript.indexOf('LIVE_STAGE="$(mktemp -d)"');
assert.ok(trapAt !== -1 && extractTempAt !== -1 && liveTempAt !== -1 && trapAt < extractTempAt && trapAt < liveTempAt);
const cleanupFn = publishScript.match(/cleanup_stages\(\) \{[\s\S]*?\n\}/);
assert.ok(cleanupFn);
for (const code of [0, 1]) {
  const script = [
    "set -euo pipefail",
    "EXTRACT=$(mktemp -d)",
    "LIVE_STAGE=$(mktemp -d)",
    "printf '%s\\n' \"$EXTRACT\" \"$LIVE_STAGE\"",
    cleanupFn[0],
    "trap cleanup_stages EXIT",
    `exit ${code}`,
  ].join("\n");
  const cleaned = spawnSync("bash", ["-c", script], { encoding: "utf8" });
  const dirs = cleaned.stdout.trim().split("\n");
  assert.equal(dirs.length, 2, cleaned.stderr);
  assert.equal(existsSync(dirs[0]), false, dirs[0]);
  assert.equal(existsSync(dirs[1]), false, dirs[1]);
}
const liveChoice = (liveCooked, localCooked) => {
  const dir = mkdtempSync(join(tmpdir(), "hb-live-"));
  const liveFile = join(dir, "live.json");
  const localDir = join(dir, "local");
  mkdirSync(localDir);
  const stamp = (cooked) => ({
    cookSha: "a".repeat(40),
    publishedAt: "2026-10-06T01:35:23Z",
    cookedAt: cooked,
    schemaVersion: SCHEMA_VERSION,
  });
  writeFileSync(liveFile, JSON.stringify(stamp(liveCooked)));
  writeFileSync(join(localDir, "home.json"), JSON.stringify(stamp(localCooked)));
  const ran = spawnSync("python3", [join(root, "scripts/pack_identity.py"), "live", liveFile, localDir], { encoding: "utf8" });
  rmSync(dir, { recursive: true, force: true });
  return ran;
};
const newerLocal = liveChoice("2026-10-07T01:00:00Z", "2026-10-07T02:00:00Z");
assert.equal(newerLocal.status, 0, newerLocal.stderr);
assert.equal(newerLocal.stdout.trim(), "keep");
const olderLocal = liveChoice("2026-10-07T03:00:00Z", "2026-10-07T01:00:00Z");
assert.notEqual(olderLocal.status, 0);
assert.equal(olderLocal.stdout.trim(), "refuse");
const cookLocalTest = readFileSync(join(root, "../Tools/HeartbeatIngest/test_cook_local.sh"), "utf8");
assert.match(cookLocalTest, /export HEARTBEAT_SKIP_GIT_CHECK=1/);
assert.match(readFileSync(join(root, "../Tools/HeartbeatIngest/cook-local.sh"), "utf8"), /git -C "\$ROOT" fetch origin/);
assert.equal(publishScript.includes('cp -R "$EXTRACT" "$DATA"'), false);
assert.equal(publishScript.includes("dest.rename"), false);
assert.equal(publishScript.includes("staged.rename(dest)"), false);
assert.match(publishScript, /refusing publish: git worktree is dirty/);
assert.match(publishScript, /dirty tree blocks a data-only upload/);
const dirtyAt = publishScript.indexOf("refusing publish: git worktree is dirty");
const npmAt = publishScript.indexOf("\nnpm test");
const secretAt = publishScript.indexOf("put_secret_if_missing");
assert.ok(dirtyAt !== -1 && dirtyAt < npmAt && dirtyAt < secretAt);
assert.match(publishScript, /pack_publish\.py" "\$PACK_DIR"/);
assert.equal(publishScript.includes("migrate-pinned"), false);
assert.equal(publishScript.includes("--commit-dirty"), false);
assert.equal(publishScript.includes("cooked < have"), false);
assert.equal(publishScript.includes("live_stamp <="), false);
const guardRun = (args) =>
  spawnSync("bash", [join(root, "../Tools/HeartbeatIngest/cook-guard.sh"), ...args], { encoding: "utf8" });
const pinnedGuard = guardRun(["web/check_pack.mjs"]);
assert.notEqual(pinnedGuard.status, 0);
assert.equal(pinnedGuard.stdout.trim(), "refuse");
const parserGuard = guardRun(["FulfillmentHeartbeat/Storage/WorkbookParser.swift"]);
assert.notEqual(parserGuard.status, 0);
assert.equal(parserGuard.stdout.trim(), "refuse");
const cleanGuard = guardRun([]);
assert.equal(cleanGuard.status, 0);
assert.equal(cleanGuard.stdout.trim(), "cook");
const reviewGuard = guardRun(["Tools/HeartbeatIngest/publish-web.sh"]);
assert.equal(reviewGuard.status, 0);
assert.equal(reviewGuard.stdout.trim(), "review");
const decidePublish = (ahead, porcelain) =>
  spawnSync("bash", [join(root, "../Tools/HeartbeatIngest/cook-guard.sh"), "--decide-publish", String(ahead)], {
    encoding: "utf8",
    input: porcelain,
  });
const cleanPublish = decidePublish(0, "");
assert.equal(cleanPublish.status, 0, cleanPublish.stderr);
assert.equal(cleanPublish.stdout.trim(), "cook");
const unpushedPublish = decidePublish(2, "");
assert.notEqual(unpushedPublish.status, 0);
assert.match(unpushedPublish.stderr, /refusing unpushed commits/);
const dirtyPublisher = decidePublish(0, " M Tools/HeartbeatIngest/publish-web.sh\n");
assert.notEqual(dirtyPublisher.status, 0);
assert.match(dirtyPublisher.stderr, /refusing a dirty publish-web\.sh/);
const untrackedCook = decidePublish(0, "?? Tools/HeartbeatIngest/notes.sh\n");
assert.notEqual(untrackedCook.status, 0);
assert.match(untrackedCook.stderr, /refusing an untracked cook path/);
const otherDirty = decidePublish(0, " M web/public/app.js\n");
assert.equal(otherDirty.status, 0, otherDirty.stderr);
assert.equal(otherDirty.stdout.trim(), "cook");
const dirtyParser = decidePublish(0, " M FulfillmentHeartbeat/Storage/WorkbookParser.swift\n");
assert.notEqual(dirtyParser.status, 0);
assert.match(dirtyParser.stderr, /refusing a dirty cook path/);
for (const path of ["web/functions/_middleware.js", "web/public/schema.js", "web/scripts/pack_publish.py"]) {
  const dirtyPublishPath = decidePublish(0, ` M ${path}\n`);
  assert.notEqual(dirtyPublishPath.status, 0, path);
  assert.match(dirtyPublishPath.stderr, /refusing a dirty publish path/);
}
for (const name of ["HEARTBEAT_COOK_SHA", "HEARTBEAT_COOKED_AT"]) {
  const uiOverride = spawnSync("bash", [join(root, "../Tools/HeartbeatIngest/cook-guard.sh"), "--publish"], {
    encoding: "utf8",
    env: { ...process.env, [name]: "1" },
  });
  assert.notEqual(uiOverride.status, 0, name);
  assert.match(uiOverride.stderr, /refusing an env override/);
}
const envOverride = spawnSync("bash", [join(root, "../Tools/HeartbeatIngest/cook-guard.sh"), "--publish"], {
  encoding: "utf8",
  env: { ...process.env, HEARTBEAT_SKIP_GIT_CHECK: "1" },
});
assert.notEqual(envOverride.status, 0);
assert.match(envOverride.stderr, /refusing an env override/);
const decidePublishData = (ahead, porcelain) =>
  spawnSync("bash", [join(root, "../Tools/HeartbeatIngest/cook-guard.sh"), "--decide-publish-data", String(ahead)], {
    encoding: "utf8",
    input: porcelain,
  });
const cleanDataPublish = decidePublishData(0, "");
assert.equal(cleanDataPublish.status, 0, cleanDataPublish.stderr);
assert.equal(cleanDataPublish.stdout.trim(), "cook");
const dirtyAppData = decidePublishData(0, " M web/public/app.js\n");
assert.notEqual(dirtyAppData.status, 0);
assert.match(dirtyAppData.stderr, /refusing a dirty path/);
const untrackedData = decidePublishData(0, "?? web/scripts/notes.py\n");
assert.notEqual(untrackedData.status, 0);
assert.match(untrackedData.stderr, /refusing an untracked path/);
for (const name of ["HEARTBEAT_COOK_SHA", "HEARTBEAT_COOKED_AT", "HEARTBEAT_SKIP_GIT_CHECK", "HEARTBEAT_SKIP_PACK_CHECK"]) {
  const overridden = spawnSync("bash", [join(root, "../Tools/HeartbeatIngest/cook-guard.sh"), "--publish-data"], {
    encoding: "utf8",
    env: { ...process.env, [name]: "1" },
  });
  assert.notEqual(overridden.status, 0, name);
  assert.match(overridden.stderr, /refusing an env override/);
}
const publishPlan = spawnSync(
  "python3",
  [
    "-c",
    `
import json, sys, tempfile
from pathlib import Path
sys.path.insert(0, "scripts")
from pack_publish import plan_pointer, upload_pack
sha = "a" * 40
other = "b" * 40
cooked = "2026-10-07T01:00:00Z"
published = "2026-10-06T01:35:23Z"
live = f"web-pack/{sha}-{cooked}"
fallback = f"web-pack/{other}-2026-10-06T00:00:00Z"
old = {
    "prefix": live,
    "cookSha": sha,
    "cookedAt": cooked,
    "publishedAt": published,
    "schemaVersion": 1,
    "previous": {"prefix": fallback, "cookSha": other, "cookedAt": "2026-10-06T00:00:00Z", "publishedAt": published, "schemaVersion": 1},
}
def refused(fn):
    try:
        fn()
    except SystemExit as error:
        return error.code if isinstance(error.code, str) else ""
    return ""
assert "live pack folder" in refused(lambda: plan_pointer(old, sha, cooked, published, 1))
assert "fallback pack folder" in refused(lambda: plan_pointer(old, other, "2026-10-06T00:00:00Z", published, 1))
recook = plan_pointer(old, sha, "2026-10-08T00:00:00Z", published, 1)
assert recook["previous"]["prefix"] == live, recook
assert recook["previous"]["cookSha"] == sha
puts = []
def fake_wrangler(args, check=True):
    class Result:
        returncode = 0
    if args[:3] == ["r2", "object", "get"] and "current.json" in args[3]:
        dest = next(item.split("=", 1)[1] for item in args if str(item).startswith("--file="))
        Path(dest).write_text(json.dumps(old), encoding="utf-8")
    if args[:3] == ["r2", "object", "put"]:
        puts.append(args[3])
    return Result()
with tempfile.TemporaryDirectory() as tmp:
    data = Path(tmp) / "data"
    data.mkdir()
    (data / "home.json").write_text(json.dumps({"cookSha": sha, "publishedAt": published, "cookedAt": cooked, "schemaVersion": 1}), encoding="utf-8")
    same = upload_pack(data, Path("check_pack.mjs"), fake_wrangler)
assert same["prefix"] == live, same
assert same["cookSha"] == sha
assert puts == []
`,
  ],
  { cwd: root, encoding: "utf8" },
);
assert.equal(publishPlan.status, 0, publishPlan.stderr || publishPlan.stdout);
const preflightPlan = spawnSync(
  "python3",
  [
    "-c",
    `
import hashlib, json, sys, tempfile
from pathlib import Path
sys.path.insert(0, "scripts")
from pack_publish import PINNED_FILE_SHA256, PINNED_HOME_SHA256, PINNED_LIVE_COOK_SHA, PINNED_LIVE_PREFIX, PINNED_LIVE_PUBLISHED_AT, migrate_pinned_pointer, preflight_pointer
home = Path("public/data/home.json").read_bytes()
assert hashlib.sha256(home).hexdigest() == PINNED_HOME_SHA256
assert len(PINNED_FILE_SHA256) == 16
for rel, digest in PINNED_FILE_SHA256.items():
    blob = (Path("public/data") / rel).read_bytes()
    assert hashlib.sha256(blob).hexdigest() == digest, rel
pinned = {
    "prefix": PINNED_LIVE_PREFIX,
    "cookSha": PINNED_LIVE_COOK_SHA,
    "publishedAt": PINNED_LIVE_PUBLISHED_AT,
    "cookedAt": "",
    "schemaVersion": 1,
}
cooked_sha = "a" * 40
cooked_at = "2026-10-07T01:00:00Z"
cooked = {
    "prefix": f"web-pack/{cooked_sha}-{cooked_at}",
    "cookSha": cooked_sha,
    "cookedAt": cooked_at,
    "publishedAt": PINNED_LIVE_PUBLISHED_AT,
    "schemaVersion": 1,
}
other = {
    "prefix": "web-pack/" + ("b" * 40) + "-" + PINNED_LIVE_PUBLISHED_AT,
    "cookSha": "b" * 40,
    "publishedAt": PINNED_LIVE_PUBLISHED_AT,
    "cookedAt": "",
    "schemaVersion": 1,
}

def bucket(pointer, files=None, missing_error="The specified key does not exist."):
    puts = []
    store = {}
    if files:
        for key, blob in files.items():
            store[key] = blob
    if pointer is not None:
        store["heartbeat-packs/web-pack/current.json"] = pointer if isinstance(pointer, bytes) else json.dumps(pointer).encode()
    def fake(args, check=True):
        class Result:
            def __init__(self, code=0, err=""):
                self.returncode = code
                self.stderr = err
                self.stdout = ""
        key = args[3]
        dest = next(item.split("=", 1)[1] for item in args if str(item).startswith("--file="))
        if args[:3] == ["r2", "object", "get"]:
            if key not in store:
                return Result(1, missing_error)
            Path(dest).write_bytes(store[key])
            return Result(0)
        if args[:3] == ["r2", "object", "put"]:
            store[key] = Path(dest).read_bytes()
            puts.append(key)
            return Result(0)
        return Result(1, "temporary error")
    return fake, puts

def pinned_files():
    files = {}
    for rel, digest in PINNED_FILE_SHA256.items():
        files[f"heartbeat-packs/{PINNED_LIVE_PREFIX}/{rel}"] = (Path("public/data") / rel).read_bytes()
    return files

def refused(pointer, files=None, error="The specified key does not exist."):
    fake, puts = bucket(pointer, files, error)
    try:
        preflight_pointer(Path("public/data"), fake)
    except SystemExit as exc:
        return (exc.code if isinstance(exc.code, str) else "", puts)
    return ("", puts)

absent_fake, absent_puts = bucket(None)
assert preflight_pointer(Path("public/data"), absent_fake) == "absent", absent_puts
assert absent_puts == []
temp_msg, temp_puts = refused(None, None, "connection reset by peer")
assert "get failed" in temp_msg, temp_msg
assert "connection reset" in temp_msg
assert temp_puts == []
verified_fake, verified_puts = bucket(pinned)
assert preflight_pointer(Path("public/data"), verified_fake) == "verified"
assert verified_puts == []
cooked_fake, cooked_puts = bucket(cooked)
assert preflight_pointer(Path("public/data"), cooked_fake) == "verified"
assert cooked_puts == []
other_msg, other_puts = refused(other)
assert "not a cooked pack" in other_msg, other_msg
assert other_puts == []
corrupt_msg, corrupt_puts = refused(b"not-json")
assert "not json" in corrupt_msg, corrupt_msg
assert corrupt_puts == []
empty_msg, empty_puts = refused(b"")
assert "empty" in empty_msg, empty_msg
assert empty_puts == []
migrate_fake, migrate_puts = bucket(None, pinned_files())
assert migrate_pinned_pointer(Path("public/data"), migrate_fake) == "migrated"
assert migrate_puts == ["heartbeat-packs/web-pack/current.json"]
cut = pinned_files()
cut[f"heartbeat-packs/{PINNED_LIVE_PREFIX}/section/labor.json"] = b'{"schemaVersion":1,"cookSha":"' + PINNED_LIVE_COOK_SHA.encode() + b'","rows":[]}'
cut_fake, cut_puts = bucket(None, cut)
try:
    migrate_pinned_pointer(Path("public/data"), cut_fake)
    raise SystemExit("cut-down labor was published")
except SystemExit as exc:
    assert "section/labor.json sha256 does not match" in str(exc.code), exc.code
assert cut_puts == []
exists_fake, exists_puts = bucket(pinned, pinned_files())
try:
    migrate_pinned_pointer(Path("public/data"), exists_fake)
    raise SystemExit("existing pointer was overwritten")
except SystemExit as exc:
    assert "already exists" in str(exc.code), exc.code
assert exists_puts == []
from pack_publish import _put_pointer
def mismatch(args, check=True):
    class Result:
        def __init__(self):
            self.returncode = 0
            self.stderr = ""
            self.stdout = ""
    if args[:3] == ["r2", "object", "get"]:
        dest = next(item.split("=", 1)[1] for item in args if str(item).startswith("--file="))
        Path(dest).write_text('{"prefix":"web-pack/wrong"}', encoding="utf-8")
        return Result()
    if args[:3] == ["r2", "object", "put"]:
        return Result()
    return Result()
with tempfile.TemporaryDirectory() as tmp:
    try:
        _put_pointer(mismatch, Path(tmp), pinned)
        raise SystemExit("bad readback was accepted")
    except SystemExit as exc:
        assert "readback does not match" in str(exc.code), exc.code
bucket_msg, bucket_puts = refused(None, None, "The specified bucket does not exist.")
assert "get failed" in bucket_msg, bucket_msg
assert "absent" not in bucket_msg
assert bucket_puts == []
buried_fake, buried_puts = bucket(None, None, "warning\\nThe specified key does not exist.\\n")
assert preflight_pointer(Path("public/data"), buried_fake) == "absent"
assert buried_puts == []
from pack_publish import upload_pack
upload_sha = "c" * 40
upload_cooked = "2026-10-07T02:00:00Z"
def pack_dir(tmp):
    data = Path(tmp) / "data"
    data.mkdir()
    (data / "home.json").write_text(json.dumps({
        "cookSha": upload_sha,
        "publishedAt": PINNED_LIVE_PUBLISHED_AT,
        "cookedAt": upload_cooked,
        "schemaVersion": 1,
        "metadata": {"schemaVersion": 1, "cookSha": upload_sha},
    }), encoding="utf-8")
    return data
absent_upload, absent_upload_puts = bucket(None)
with tempfile.TemporaryDirectory() as tmp:
    try:
        upload_pack(pack_dir(tmp), Path("check_pack.mjs"), absent_upload)
        raise SystemExit("absent pointer was accepted")
    except SystemExit as exc:
        assert "absent" in str(exc.code) and "--first-publish" in str(exc.code), exc.code
assert absent_upload_puts == []
empty_upload, empty_upload_puts = bucket(b"   ")
with tempfile.TemporaryDirectory() as tmp:
    try:
        upload_pack(pack_dir(tmp), Path("check_pack.mjs"), empty_upload)
        raise SystemExit("empty pointer was accepted")
    except SystemExit as exc:
        assert "--first-publish" in str(exc.code), exc.code
assert empty_upload_puts == []
class Ok:
    returncode = 0
first_fake, first_puts = bucket(None)
with tempfile.TemporaryDirectory() as tmp:
    first_plan = upload_pack(pack_dir(tmp), Path("check_pack.mjs"), first_fake, checker=lambda downloaded: Ok(), first_publish=True)
assert first_plan["cookSha"] == upload_sha
assert any(item.endswith("current.json") for item in first_puts), first_puts
`,
  ],
  { cwd: root, encoding: "utf8" },
);
assert.equal(preflightPlan.status, 0, preflightPlan.stderr || preflightPlan.stdout);
const lostRegions = [
  ["East", "$100.00"],
  ["South", "$200.00"],
  ["California", "$300.00"],
  ["West", "$400.00"],
];
const goodLostHome = {
  cookedAt: "2026-10-07T00:00:00Z",
  companyTiles: { lost_revenue: { labels: ["Lost $", "Missed"], values: ["$1,050.00", "$50.00"] } },
  regionLines: lostRegions.map(([region, value]) => ({
    section: "lost_revenue",
    region,
    title: "Lost $ excl. Missed",
    value,
    count: 1,
    missed: "Not available",
    children: [{ division: "Shaws", value, count: 1, missed: "Not available" }],
  })),
  regionTables: [{ section: "lost_revenue", region: "South", headline: "$200.00" }],
  summaries: [
    { section: "lost_revenue", storeCount: 4 },
    { section: "missing_items", storeCount: 1 },
    { section: "five_star", storeCount: 1 },
    { section: "pre_sub_oos", storeCount: 2 },
  ],
  pickerRollups: { company: { stores: 2 } },
};
const goodLostRows = { rows: [{ store: "1" }, { store: "2" }, { store: "3" }, { store: "4" }] };
assert.deepEqual(lostRollupErrors(goodLostHome, goodLostRows), []);
assert.deepEqual(currencyPrecisionErrors(goodLostHome), []);
const shortLost = structuredClone(goodLostHome);
shortLost.companyTiles.lost_revenue.values[0] = "$1,080.00";
assert.ok(lostRollupErrors(shortLost, goodLostRows).some((item) => item.startsWith("lost rollup")));
const roughMoney = structuredClone(goodLostHome);
roughMoney.regionTables[0].headline = "$779,589.702";
assert.ok(currencyPrecisionErrors(roughMoney).some((item) => item.includes("$779,589.702")));
const countFiles = {
  lost_revenue: goodLostRows,
  missing_items: { rows: [{ store: "1" }] },
  five_star: { rows: [{ store: "1" }] },
  pre_sub_oos: { rows: [{ store: "1" }, { store: "2" }] },
  picker_scorecard: { rows: [{ store: "210" }, { store: "210" }, { store: "239" }] },
};
assert.deepEqual(storeCountErrors(goodLostHome, countFiles), []);
const staleCounts = structuredClone(goodLostHome);
staleCounts.summaries[0].storeCount = 2165;
staleCounts.pickerRollups.company.stores = 2165;
assert.ok(storeCountErrors(staleCounts, countFiles).some((item) => item.includes("lost_revenue storeCount")));
assert.ok(storeCountErrors(staleCounts, countFiles).some((item) => item.includes("picker stores")));
const identDir = mkdtempSync(join(tmpdir(), "hb-ident-"));
const identStamp = { publishedAt: "2026-10-06T01:35:23Z", schemaVersion: SCHEMA_VERSION, cookSha: "a".repeat(40) };
writeFileSync(join(identDir, "home.json"), JSON.stringify({ ...identStamp, cookedAt: "2026-10-07T00:00:00Z" }));
writeFileSync(join(identDir, "schedule.json"), JSON.stringify(identStamp));
assert.ok(packIdentityErrors(identDir).some((item) => item.includes("does not match")));
rmSync(identDir, { recursive: true, force: true });
const fifteen = mkdtempSync(join(tmpdir(), "hb-fifteen-"));
const fifteenStamp = {
  publishedAt: "2026-10-06T01:35:23Z",
  schemaVersion: SCHEMA_VERSION,
  cookSha: "a".repeat(40),
  cookedAt: "2026-10-07T00:00:00Z",
};
for (const rel of PACK_FILES) {
  if (rel === "section/pick_path.json") continue;
  const dest = join(fifteen, rel);
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, JSON.stringify(fifteenStamp));
}
assert.ok(packIdentityErrors(fifteen).some((item) => item === "section/pick_path.json is missing"));
rmSync(fifteen, { recursive: true, force: true });
const fetchPackSrc = app.slice(app.indexOf("async function fetchPack"), app.indexOf("async function loadOptional"));
assert.match(fetchPackSrc, /state\.packs\.clear\(\)/);
assert.match(fetchPackSrc, /state\.failedPacks\.clear\(\)/);
assert.match(fetchPackSrc, /acceptHome\(home\)/);
assert.equal(fetchPackSrc.includes('state.packs.delete("home")'), false);
const publishPy = readFileSync(join(root, "scripts/pack_publish.py"), "utf8");
assert.match(publishPy, /The specified key does not exist\./);
assert.equal(publishPy.includes("NOT_FOUND_MARKERS"), false);
assert.match(publishPy, /pass --first-publish/);
assert.match(publishPy, /web-pack\/current\.json/);
assert.match(publishPy, /check_pack failed on the uploaded set/);
assert.match(publishPy, /refusing to write into the live pack folder/);
assert.match(publishPy, /refusing to write into the fallback pack folder/);
assert.equal(publishScript.includes("web-pack/packs/"), false);
assert.equal(publishPy.includes("web-pack/packs/"), false);
assert.equal(publishScript.includes("web-pack/pointer.json"), false);
assert.equal(publishPy.includes("web-pack/pointer.json"), false);
assert.match(publishPy, /site tree not deployed/);
assert.match(publishScript, /print_pack_stamp\.mjs/);
assert.match(publishScript, /signed-in compare/);
assert.match(publishScript, /2026-09-29/);
assert.match(publishScript, /2026-09-30/);
assert.match(readFileSync(join(root, "../Tools/HeartbeatIngest/cook-local.sh"), "utf8"), /HEARTBEAT_DATA_ONLY=1/);
assert.match(readFileSync(join(root, "package.json"), "utf8"), />=22\.5\.0/);
assert.match(publishScript, /\{"error":"unauthorized"\}/);
assert.equal(publishScript.includes("--commit-dirty=true"), false);
assert.match(publishScript, /refusing publish: git worktree is dirty/);
const dirtyAt = publishScript.indexOf("refusing publish: git worktree is dirty");
const npmAt = publishScript.indexOf("\nnpm test");
const secretAt = publishScript.indexOf("put_secret_if_missing");
assert.ok(dirtyAt !== -1 && dirtyAt < npmAt && dirtyAt < secretAt);
assert.equal(publishScript.includes("--project-name heartbeat-web"), false);
const wrangler = readFileSync(join(root, "wrangler.toml"), "utf8");
assert.match(wrangler, /name = "fulfillment-heartbeat-web"/);
assert.match(wrangler, /pages_build_output_dir = "dist"/);
assert.match(wrangler, /binding = "HB_AUTH"/);
assert.match(wrangler, /database_name = "fulfillment-heartbeat-auth"/);
assert.match(wrangler, /database_id = "646c017a-802f-4395-b635-d4b5bd66c1cb"/);
assert.match(wrangler, /preview_database_id = "291dfe6d-fcc1-4b15-90c7-768db26d1f8e"/);
assert.match(wrangler, /database_name = "hb-auth-preview"/);
assert.equal(wrangler.includes('preview_database_id = "646c017a-802f-4395-b635-d4b5bd66c1cb"'), false);
const wranglerEnvs = new Set([...wrangler.matchAll(/\[\[env\.([^.]+)\./g)].map((match) => match[1]));
assert.deepEqual([...wranglerEnvs].sort(), ["preview", "production"]);
for (const name of wranglerEnvs) {
  const block = wrangler.slice(wrangler.indexOf(`[[env.${name}.r2_buckets]]`));
  assert.match(block, /binding = "HEARTBEAT_PACKS"/);
  assert.match(block, /bucket_name = "heartbeat-packs"/);
}
assert.match(wrangler, /\[\[env\.preview\.d1_databases\]\][\s\S]*database_id = "291dfe6d-fcc1-4b15-90c7-768db26d1f8e"/);
assert.match(wrangler, /\[\[env\.production\.d1_databases\]\][\s\S]*database_id = "646c017a-802f-4395-b635-d4b5bd66c1cb"/);
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
assert.match(distIndex, /app\.css\?v=28/);
assert.match(distIndex, /app\.js\?v=45/);
assert.match(readFileSync(join(root, "scripts/stage_pages.mjs"), "utf8"), /Build-label only/);
const distApp = readFileSync(join(root, "dist/app.js"), "utf8");
assert.equal(distApp.includes("__BUILD_SHA__"), false);
const stagedSha = spawnSync("git", ["rev-parse", "--short=7", "HEAD"], { cwd: root, encoding: "utf8" }).stdout.trim();
assert.match(distApp, new RegExp(`Build \\$\\{esc\\(buildLine\\)\\}`));
assert.match(distApp, new RegExp(`const BUILD_SHA = "${stagedSha}"`));
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
assert.match(loginHTML, /Email or username/);
assert.match(loginHTML, /type="text"/);
assert.match(loginHTML, /inputmode="email"/);
assert.match(loginHTML, /autocapitalize="none"/);
assert.equal(loginHTML.includes('type="email"'), false);
assert.match(loginHTML, /name="email"/);
assert.match(loginHTML, /type="password"/);
assert.match(loginHTML, /autocomplete="username"/);
assert.match(loginHTML, /autocomplete="current-password"/);
assert.match(loginHTML, /<span class="fulfill">Fulfill<\/span><span class="ment">ment<\/span>/);
assert.match(loginHTML, /src="\/nav-boot\.js\?v=3"/);
assert.equal(loginHTML.includes('class="header-back"'), false);
assert.match(accountsSrc, /class="header-back"/);
assert.match(accountsSrc, />Dashboard</);
assert.equal(accountsSrc.includes("Back to Heartbeat"), false);
assert.match(accountsSrc, /aria-controls="drawer"/);
assert.match(accountsSrc, /"\/\?page=pph"/);
assert.match(accountsSrc, /"\/\?page=schedule"/);
assert.match(accountsSrc, /src="\/shell-nav\.js\?v=1"/);
assert.match(readFileSync(join(root, "public/login.css"), "utf8"), /\.header-back,\s*#nav-toggle \{[^}]*min-height:\s*44px/);
assert.match(app, /function applyPageQuery/);
assert.match(loginHTML, /href="\/favicon\.svg"/);
assert.match(loginHTML, /href="\/favicon-32\.png"/);
assert.match(loginHTML, /href="\/apple-touch-icon\.png"/);
assert.match(readFileSync(join(root, "public/favicon.svg"), "utf8"), /stop-color="#3d8dff"/);
for (const file of ["public/favicon-16.png", "public/favicon-32.png", "public/apple-touch-icon.png"]) {
  const bytes = readFileSync(join(root, file));
  assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a", file);
}
let bootServed = false;
const boot = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/nav-boot.js?v=3"),
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
for (const iconPath of ["/favicon-32.png", "/favicon-16.png", "/apple-touch-icon.png"]) {
  let pngServed = false;
  const png = await basicGate({
    request: new Request(`https://fulfillment-heartbeat-web.pages.dev${iconPath}`),
    env: gateEnv,
    next: async () => {
      pngServed = true;
      return new Response("png", { status: 200, headers: { "content-type": "image/png" } });
    },
  });
  assert.equal(png.status, 200, iconPath);
  assert.equal(pngServed, true, iconPath);
}
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
const signedAuth = openAuth();
const signedIn = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/login", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded", "sec-fetch-site": "same-origin" },
    body: "username=heartbeat&password=test-only-secret",
  }),
  env: accountEnv(signedAuth.db),
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
assert.match(sessionCookie.split("=")[1], /^[a-f0-9]{64}\.[a-f0-9]{64}$/);
const opened = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db),
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(opened.status, 200);
assert.equal(await opened.text(), "page");
const dataOpened = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db),
  next: async () => new Response("{}", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(dataOpened.status, 200);
assert.equal(dataOpened.headers.get("cache-control"), "private, no-store");
assert.equal(rawDivisionName("JEWEL"), true);
assert.equal(rawDivisionName("Jewel Osco"), false);
assert.equal(rawDivisionName("DENVER"), true);
assert.equal(rawDivisionName("INTERMOUNTAIN"), true);
const goodSha = "a".repeat(40);
const badSha = "b".repeat(40);
const publishedAt = "2026-10-06T01:35:23Z";
const goodCookedAt = "2026-10-07T04:00:00Z";
const goodPrefix = packPrefix(goodSha, publishedAt);
const badPrefix = packPrefix(badSha, publishedAt);
assert.equal(PINNED_LIVE_COOK_SHA, "74d44dde02a0e1c6430a9a78b06034099c84e001");
assert.equal(PINNED_LIVE_PUBLISHED_AT, publishedAt);
assert.equal(PINNED_LIVE_PREFIX, `web-pack/${PINNED_LIVE_COOK_SHA}-${publishedAt}`);
assert.equal(PINNED_HOME_SHA256, "fece0ad52e54aa5cb3cb7a3637552d831a4e276d28b695ca3b2797172f7d839a");
assert.equal(isPinnedLivePack(PINNED_LIVE_COOK_SHA, publishedAt, "", ""), false);
assert.equal(isPinnedLivePack(PINNED_LIVE_COOK_SHA, publishedAt, "", PINNED_LIVE_PREFIX), true);
assert.equal(await sha256Hex(readFileSync(join(root, "public/data/home.json"), "utf8")), PINNED_HOME_SHA256);
assert.equal(PACK_POINTER_KEY, "web-pack/current.json");
assert.equal(goodPrefix, `web-pack/${goodSha}-${publishedAt}`);
assert.equal(packObjectKey(goodPrefix, "section/labor.json"), `${goodPrefix}/section/labor.json`);
const goodHome = {
  schemaVersion: SCHEMA_VERSION,
  cookSha: goodSha,
  publishedAt,
  cookedAt: goodCookedAt,
  metadata: { schemaVersion: SCHEMA_VERSION, cookSha: goodSha, cookedAt: goodCookedAt },
  laborMarket: { aiv_impact_pct: 3, uplh_impact_pct: 1, wage_impact_pct: 2, target_vs_actual_pct: 6 },
  regionTables: [{ region: "West" }],
  summaries: [{ section: "sales" }],
  companyTiles: { sales: { labels: [], values: [] } },
  filters: { stores: [{ store: "1", division: "Mountain West" }] },
};
const badHome = {
  schemaVersion: 0,
  cookSha: badSha,
  publishedAt,
  metadata: { schemaVersion: 0, cookSha: badSha },
  laborMarket: { aiv_impact_pct: 1, uplh_impact_pct: 1, wage_impact_pct: 1, target_vs_actual_pct: 3 },
  regionTables: [{ region: "West" }],
  summaries: [{ section: "sales" }],
  companyTiles: {},
  filters: { stores: [{ store: "1" }] },
};
assert.equal(guardHome(goodHome).length, 0);
assert.ok(guardHome(badHome).some((item) => item.startsWith("schemaVersion=")));
function memoryBucket(files) {
  return {
    async get(key) {
      if (!Object.prototype.hasOwnProperty.call(files, key)) return null;
      const text = files[key];
      return { text: async () => text, body: text };
    },
    async list({ prefix } = {}) {
      const objects = Object.keys(files)
        .filter((key) => !prefix || key.startsWith(prefix))
        .map((key) => ({ key }));
      return { objects, truncated: false };
    },
  };
}
const packFiles = {
  [PACK_POINTER_KEY]: JSON.stringify({
    prefix: badPrefix,
    cookSha: badSha,
    cookedAt: "2026-10-07T01:00:00Z",
    publishedAt,
    schemaVersion: SCHEMA_VERSION,
    previous: { prefix: goodPrefix, cookSha: goodSha, cookedAt: goodCookedAt, publishedAt, schemaVersion: SCHEMA_VERSION },
  }),
  [packObjectKey(badPrefix, "home.json")]: JSON.stringify({ ...badHome, cookedAt: "2026-10-07T01:00:00Z" }),
  [packObjectKey(badPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: badSha,
    cookedAt: "2026-10-07T01:00:00Z",
    rows: [{ store: "879", division: "DENVER" }],
  }),
  [packObjectKey(goodPrefix, "home.json")]: JSON.stringify(goodHome),
  [packObjectKey(goodPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: goodSha,
    cookedAt: goodCookedAt,
    rows: [{ store: "879", division: "Mountain West" }],
  }),
};
resetPackCache();
const packed = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(packFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(packed.status, 200);
assert.equal(packed.headers.get("cache-control"), "private, no-store");
assert.match(await packed.text(), /Mountain West/);
resetPackCache();
{
  const flightSha = "e".repeat(40);
  const nextSha = "f".repeat(40);
  const flightCooked = "2026-10-08T00:00:00Z";
  const nextCooked = "2026-10-08T01:00:00Z";
  const flightPrefix = `web-pack/${flightSha}-${flightCooked}`;
  const nextPrefix = `web-pack/${nextSha}-${nextCooked}`;
  const packHome = (sha, cooked) =>
    JSON.stringify({
      publishedAt,
      schemaVersion: SCHEMA_VERSION,
      cookSha: sha,
      cookedAt: cooked,
      metadata: { schemaVersion: SCHEMA_VERSION, cookSha: sha, cookedAt: cooked },
      summaries: [{ section: "sales" }],
      laborMarket: { aiv_impact_pct: 0, uplh_impact_pct: 0, wage_impact_pct: 0, target_vs_actual_pct: 0 },
      regionTables: [{}],
      companyTiles: { sales: { labels: [], values: [] } },
      filters: { stores: [{ store: "1" }] },
    });
  const files = {
    [PACK_POINTER_KEY]: JSON.stringify({
      prefix: flightPrefix,
      cookSha: flightSha,
      cookedAt: flightCooked,
      publishedAt,
      schemaVersion: SCHEMA_VERSION,
    }),
    [`${flightPrefix}/home.json`]: packHome(flightSha, flightCooked),
    [`${nextPrefix}/home.json`]: packHome(nextSha, nextCooked),
  };
  let swapped = false;
  const flightBucket = {
    async get(key) {
      if (key === `${flightPrefix}/home.json` && !swapped) {
        swapped = true;
        files[PACK_POINTER_KEY] = JSON.stringify({
          prefix: nextPrefix,
          cookSha: nextSha,
          cookedAt: nextCooked,
          publishedAt,
          schemaVersion: SCHEMA_VERSION,
        });
        const nested = await readPackObject(flightBucket, "https://fulfillment-heartbeat-web.pages.dev/data/home.json");
        assert.equal(nested.missing, undefined);
        assert.match(await nested.text(), new RegExp(nextSha));
      }
      if (!Object.prototype.hasOwnProperty.call(files, key)) return null;
      const text = files[key];
      return { text: async () => text };
    },
    async list({ prefix } = {}) {
      return {
        objects: Object.keys(files)
          .filter((key) => !prefix || key.startsWith(prefix))
          .map((key) => ({ key })),
        truncated: false,
      };
    },
  };
  const dropped = await readPackObject(
    flightBucket,
    `https://fulfillment-heartbeat-web.pages.dev/data/home.json?cookSha=${flightSha}&publishedAt=${encodeURIComponent(publishedAt)}&cookedAt=${encodeURIComponent(flightCooked)}`,
  );
  assert.equal(dropped.missing, true);
}
resetPackCache();
const skewSha = "c".repeat(40);
const skewPrefix = packPrefix(skewSha, publishedAt);
const skewCookedAt = "2026-10-07T05:00:00Z";
const skewHome = {
  ...goodHome,
  cookSha: skewSha,
  cookedAt: skewCookedAt,
  metadata: { schemaVersion: SCHEMA_VERSION, cookSha: skewSha, cookedAt: skewCookedAt },
};
const skewFiles = {
  [PACK_POINTER_KEY]: JSON.stringify({
    prefix: skewPrefix,
    cookSha: skewSha,
    cookedAt: skewCookedAt,
    publishedAt,
    schemaVersion: SCHEMA_VERSION,
    previous: { prefix: goodPrefix, cookSha: goodSha, cookedAt: goodCookedAt, publishedAt, schemaVersion: SCHEMA_VERSION },
  }),
  [packObjectKey(skewPrefix, "home.json")]: JSON.stringify(skewHome),
  [packObjectKey(skewPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: goodSha,
    cookedAt: skewCookedAt,
    rows: [{ store: "879", division: "DENVER" }],
  }),
  [packObjectKey(goodPrefix, "home.json")]: JSON.stringify(goodHome),
  [packObjectKey(goodPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: goodSha,
    cookedAt: goodCookedAt,
    rows: [{ store: "879", division: "Mountain West" }],
  }),
};
resetPackCache();
const skewed = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(skewFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.match(await skewed.text(), /Mountain West/);
const skewedHome = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(skewFiles) }),
  next: async () => new Response("static-home", { status: 200, headers: { "content-type": "application/json" } }),
});
const skewedHomeText = await skewedHome.text();
assert.match(skewedHomeText, new RegExp(goodSha));
assert.equal(skewedHomeText.includes(skewSha), false);
const siblingSha = "d".repeat(40);
const siblingPrefix = `web-pack/${siblingSha}-2026-10-07T00:00:00Z`;
const siblingHome = {
  ...goodHome,
  cookSha: siblingSha,
  cookedAt: "2026-10-07T00:00:00Z",
  metadata: { schemaVersion: SCHEMA_VERSION, cookSha: siblingSha, cookedAt: "2026-10-07T00:00:00Z" },
};
const siblingFiles = {
  [PACK_POINTER_KEY]: JSON.stringify({
    prefix: siblingPrefix,
    cookSha: siblingSha,
    cookedAt: "2026-10-07T00:00:00Z",
    publishedAt,
    schemaVersion: SCHEMA_VERSION,
    previous: { prefix: goodPrefix, cookSha: goodSha, cookedAt: goodCookedAt, publishedAt, schemaVersion: SCHEMA_VERSION },
  }),
  [packObjectKey(siblingPrefix, "home.json")]: JSON.stringify(siblingHome),
  [packObjectKey(siblingPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: siblingSha,
    cookedAt: "2026-10-07T00:00:00Z",
    rows: [{ store: "879", division: "DENVER" }],
  }),
  [packObjectKey(siblingPrefix, "section/labor.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: goodSha,
    cookedAt: "2026-10-07T00:00:00Z",
    rows: [{ store: "1" }],
  }),
  [packObjectKey(goodPrefix, "home.json")]: JSON.stringify(goodHome),
  [packObjectKey(goodPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: goodSha,
    cookedAt: goodCookedAt,
    rows: [{ store: "879", division: "Mountain West" }],
  }),
};
resetPackCache();
const siblingSection = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(siblingFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
const siblingText = await siblingSection.text();
assert.match(siblingText, /Mountain West/);
assert.equal(siblingText.includes("DENVER"), false);
resetPackCache();
const cookedMismatch = {
  ...siblingFiles,
  [packObjectKey(siblingPrefix, "section/labor.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: siblingSha,
    cookedAt: "2026-10-06T00:00:00Z",
    rows: [{ store: "1" }],
  }),
};
const cookedSkew = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(cookedMismatch) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.match(await cookedSkew.text(), /Mountain West/);
resetPackCache();
const unsignedPack = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json"),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(packFiles) }),
  next: async () => new Response("static-pack", { status: 200 }),
});
assert.equal(unsignedPack.status, 401);
assert.equal(unsignedPack.headers.get("cache-control"), "private, no-store");
assert.deepEqual(await unsignedPack.json(), { error: "unauthorized" });
resetPackCache();
const staticFallback = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({
      [PACK_POINTER_KEY]: JSON.stringify({
        prefix: badPrefix,
        cookSha: badSha,
        publishedAt,
        schemaVersion: SCHEMA_VERSION,
        previous: "",
      }),
    }),
  }),
  next: async () => new Response("static-home", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(staticFallback.status, 404);
assert.deepEqual(await staticFallback.json(), { error: "NO DATA" });
assert.equal(staticFallback.headers.get("cache-control"), "private, no-store");
const pinnedPrefix = PINNED_LIVE_PREFIX;
const pinnedHomeText = readFileSync(join(root, "public/data/home.json"), "utf8");
function realPinnedPack() {
  const files = {};
  for (const rel of PACK_FILES) {
    files[packObjectKey(pinnedPrefix, rel)] = readFileSync(join(root, "public/data", rel), "utf8");
  }
  return files;
}
const pinnedFiles = {
  [PACK_POINTER_KEY]: JSON.stringify({
    prefix: pinnedPrefix,
    cookSha: PINNED_LIVE_COOK_SHA,
    publishedAt,
    schemaVersion: SCHEMA_VERSION,
  }),
  [packObjectKey(pinnedPrefix, "home.json")]: pinnedHomeText,
  [packObjectKey(pinnedPrefix, "section/missing_items.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: PINNED_LIVE_COOK_SHA,
    rows: [{ store: "210", division: "United" }],
  }),
};
resetPackCache();
const pinnedServed = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(pinnedFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(pinnedServed.status, 404);
assert.equal((await pinnedServed.text()).includes("United"), false);
resetPackCache();
const realPinned = {
  [PACK_POINTER_KEY]: JSON.stringify({
    prefix: pinnedPrefix,
    cookSha: PINNED_LIVE_COOK_SHA,
    publishedAt,
    schemaVersion: SCHEMA_VERSION,
  }),
  ...realPinnedPack(),
};
const realLabor = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/labor.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(realPinned) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(realLabor.status, 200);
assert.equal(await sha256Hex(await realLabor.text()), PINNED_FILE_SHA256["section/labor.json"]);
const cutLabor = {
  ...realPinned,
  [packObjectKey(pinnedPrefix, "section/labor.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: PINNED_LIVE_COOK_SHA,
    publishedAt,
    rows: [{ store: "1", division: "CUT-DOWN" }],
  }),
};
resetPackCache();
const cutServed = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/labor.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(cutLabor) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(cutServed.status, 404);
assert.equal((await cutServed.text()).includes("CUT-DOWN"), false);
const looseSha = "f".repeat(40);
const loosePrefix = packPrefix(looseSha, publishedAt);
const looseHome = {
  ...goodHome,
  cookSha: looseSha,
  metadata: { schemaVersion: SCHEMA_VERSION, cookSha: looseSha },
};
delete looseHome.cookedAt;
const pinnedObjects = realPinnedPack();
resetPackCache();
const looseRefused = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({
      ...pinnedObjects,
      [packObjectKey(loosePrefix, "home.json")]: JSON.stringify(looseHome),
      [packObjectKey(loosePrefix, "section/missing_items.json")]: JSON.stringify({
        schemaVersion: SCHEMA_VERSION,
        cookSha: looseSha,
        rows: [{ store: "1", division: "Haggen" }],
      }),
      [PACK_POINTER_KEY]: JSON.stringify({
        prefix: loosePrefix,
        cookSha: looseSha,
        publishedAt,
        schemaVersion: SCHEMA_VERSION,
        previous: { prefix: pinnedPrefix, cookSha: PINNED_LIVE_COOK_SHA, publishedAt, schemaVersion: SCHEMA_VERSION },
      }),
    }),
  }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
const looseText = await looseRefused.text();
assert.match(looseText, /eComm sales/);
assert.match(looseText, new RegExp(PINNED_LIVE_COOK_SHA));
assert.equal(looseText.includes(looseSha), false);
const tabCurrentPrefix = packPrefix(goodSha, publishedAt);
const tabFiles = {
  [PACK_POINTER_KEY]: JSON.stringify({
    prefix: tabCurrentPrefix,
    cookSha: goodSha,
    cookedAt: goodCookedAt,
    publishedAt,
    schemaVersion: SCHEMA_VERSION,
    previous: { prefix: pinnedPrefix, cookSha: PINNED_LIVE_COOK_SHA, publishedAt, schemaVersion: SCHEMA_VERSION },
  }),
  [packObjectKey(tabCurrentPrefix, "home.json")]: JSON.stringify(goodHome),
  [packObjectKey(tabCurrentPrefix, "section/labor.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: goodSha,
    cookedAt: goodCookedAt,
    rows: [{ store: "1", division: "CURRENT" }],
  }),
  [packObjectKey(pinnedPrefix, "home.json")]: pinnedHomeText,
  [packObjectKey(pinnedPrefix, "section/labor.json")]: JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    cookSha: PINNED_LIVE_COOK_SHA,
    publishedAt,
    rows: [{ store: "1", division: "PINNED" }],
  }),
};
const pinnedQuery = `cookSha=${PINNED_LIVE_COOK_SHA}&publishedAt=${encodeURIComponent(publishedAt)}`;
resetPackCache();
const pinnedTab = await basicGate({
  request: new Request(`https://fulfillment-heartbeat-web.pages.dev/data/section/labor.json?${pinnedQuery}`, {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(tabFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(pinnedTab.status, 404);
assert.equal((await pinnedTab.text()).includes("PINNED"), false);
const currentQuery = `cookSha=${goodSha}&publishedAt=${encodeURIComponent(publishedAt)}&cookedAt=${encodeURIComponent(goodCookedAt)}`;
resetPackCache();
const currentTab = await basicGate({
  request: new Request(`https://fulfillment-heartbeat-web.pages.dev/data/section/labor.json?${currentQuery}`, {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(tabFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.match(await currentTab.text(), /CURRENT/);
resetPackCache();
const missingOnPin = await basicGate({
  request: new Request(`https://fulfillment-heartbeat-web.pages.dev/data/section/sales.json?${currentQuery}`, {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(tabFiles) }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(missingOnPin.status, 404);
assert.deepEqual(await missingOnPin.json(), { error: "NO DATA" });
resetPackCache();
const wholePrevious = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/labor.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({
      [PACK_POINTER_KEY]: JSON.stringify({
        prefix: tabCurrentPrefix,
        cookSha: goodSha,
        cookedAt: goodCookedAt,
        publishedAt,
        schemaVersion: SCHEMA_VERSION,
        previous: { prefix: pinnedPrefix, cookSha: PINNED_LIVE_COOK_SHA, publishedAt, schemaVersion: SCHEMA_VERSION },
      }),
      [packObjectKey(tabCurrentPrefix, "home.json")]: JSON.stringify(goodHome),
      [packObjectKey(pinnedPrefix, "home.json")]: pinnedHomeText,
      [packObjectKey(pinnedPrefix, "section/labor.json")]: JSON.stringify({
        schemaVersion: SCHEMA_VERSION,
        cookSha: PINNED_LIVE_COOK_SHA,
        publishedAt,
        rows: [{ store: "1", division: "PINNED" }],
      }),
    }),
  }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(wholePrevious.status, 404);
assert.equal((await wholePrevious.text()).includes("PINNED"), false);
const wrongPublished = "2026-11-01T00:00:00Z";
resetPackCache();
const wrongPin = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({
      [PACK_POINTER_KEY]: JSON.stringify({
        prefix: pinnedPrefix,
        cookSha: PINNED_LIVE_COOK_SHA,
        publishedAt: wrongPublished,
        schemaVersion: SCHEMA_VERSION,
      }),
      [packObjectKey(pinnedPrefix, "home.json")]: pinnedHomeText,
    }),
  }),
  next: async () => new Response("static-home", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(wrongPin.status, 404);
assert.equal((await wrongPin.text()).includes("static-home"), false);
resetPackCache();
const absentPointer = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket({}) }),
  next: async () => new Response("static-home", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(absentPointer.status, 200);
assert.equal(await absentPointer.text(), "static-home");
resetPackCache();
const absentApi = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/api/home", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket({}) }),
  next: async () => new Response("static-api", { status: 200 }),
});
assert.equal(absentApi.status, 404);
assert.equal((await absentApi.text()).includes("static-api"), false);
resetPackCache();
const corruptPointer = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({ [PACK_POINTER_KEY]: "not-json" }),
  }),
  next: async () => new Response("static-home", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(corruptPointer.status, 404);
assert.equal((await corruptPointer.text()).includes("static-home"), false);
resetPackCache();
const wrongPrefix = "web-pack/not-the-pinned-prefix";
const wrongPrefixPin = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/home.json", { headers: { cookie: sessionCookie } }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({
      [PACK_POINTER_KEY]: JSON.stringify({
        prefix: wrongPrefix,
        cookSha: PINNED_LIVE_COOK_SHA,
        publishedAt,
        schemaVersion: SCHEMA_VERSION,
      }),
      [packObjectKey(wrongPrefix, "home.json")]: pinnedHomeText,
    }),
  }),
  next: async () => new Response("static-home", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(wrongPrefixPin.status, 404);
assert.equal((await wrongPrefixPin.text()).includes("static-home"), false);
resetPackCache();
const reshapedHome = JSON.stringify(JSON.parse(pinnedHomeText));
const wrongHash = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/data/section/missing_items.json", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, {
    HEARTBEAT_PACKS: memoryBucket({
      ...pinnedFiles,
      [packObjectKey(pinnedPrefix, "home.json")]: reshapedHome,
    }),
  }),
  next: async () => new Response("static-pack", { status: 200, headers: { "content-type": "application/json" } }),
});
assert.equal(wrongHash.status, 404);
assert.equal((await wrongHash.text()).includes("static-pack"), false);
assert.notEqual(await sha256Hex(reshapedHome), PINNED_HOME_SHA256);
resetPackCache();
const apiPacked = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/api/section/missing_items", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(packFiles) }),
  next: async () => new Response("api-function", { status: 200 }),
});
assert.equal(apiPacked.status, 200);
assert.equal(apiPacked.headers.get("cache-control"), "private, no-store");
assert.match(await apiPacked.text(), /Mountain West/);
resetPackCache();
const staleOnly = {
  "web-pack/home.json": JSON.stringify({ publishedAt: "2026-09-29T20:29:58Z" }),
};
const apiStale = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/api/home", {
    headers: { cookie: sessionCookie },
  }),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(staleOnly) }),
  next: async () => new Response("stale-body", { status: 200 }),
});
assert.equal(apiStale.status, 404);
assert.equal(apiStale.headers.get("cache-control"), "private, no-store");
assert.equal((await apiStale.text()).includes("2026-09-29"), false);
resetPackCache();
const apiUnsigned = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/api/home"),
  env: accountEnv(signedAuth.db, { HEARTBEAT_PACKS: memoryBucket(packFiles) }),
  next: async () => new Response("api-function", { status: 200 }),
});
assert.equal(apiUnsigned.status, 401);
assert.equal(apiUnsigned.headers.get("cache-control"), "private, no-store");
assert.deepEqual(await apiUnsigned.json(), { error: "unauthorized" });
const wrong = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/login", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded", "sec-fetch-site": "same-origin" },
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
  env: accountEnv(signedAuth.db, { BASIC_PASS: "rotated-secret" }),
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(await rotated.text(), "page");
const testerIn = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/login", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded", "sec-fetch-site": "same-origin" },
    body: "username=tester&password=tester-only-secret",
  }),
  env: accountEnv(signedAuth.db),
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(testerIn.status, 303);
const testerCookie = (testerIn.headers.get("set-cookie") || "").split(";")[0];
assert.match(testerCookie.split("=")[1], /^[a-f0-9]{64}\.[a-f0-9]{64}$/);
const testerAfterRotate = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: testerCookie } }),
  env: accountEnv(signedAuth.db, { BASIC_PASS_TESTER: "rotated-tester" }),
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(await testerAfterRotate.text(), "page");
const testerLogout = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/logout", { method: "POST", headers: { cookie: testerCookie } }),
  env: accountEnv(signedAuth.db),
  next: async () => new Response("page", { status: 200 }),
});
assert.equal(testerLogout.status, 302);
const testerReplay = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: testerCookie } }),
  env: accountEnv(signedAuth.db),
  next: async () => new Response("page", { status: 200 }),
});
assert.match(await testerReplay.text(), /action="\/login"/);
const legacyCookie = await legacyPasswordCookie(gateEnv, "heartbeat", "test-only-secret");
const legacyRejected = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: `hb_session=${legacyCookie}` } }),
  env: accountEnv(signedAuth.db),
  next: async () => new Response("page", { status: 200 }),
});
assert.match(await legacyRejected.text(), /action="\/login"/);
assert.equal(middleware.includes("passwordVersion"), false);
assert.equal(middleware.includes("createSessionToken"), false);
assert.equal(middleware.includes("readSession"), false);
assert.equal(middleware.includes("revokeLegacyToken"), false);
assert.equal(accountsSrc.includes("revoked_legacy"), false);
const flippedCookie = sessionCookie.slice(0, -1) + (sessionCookie.endsWith("a") ? "b" : "a");
const tampered = await basicGate({
  request: new Request("https://fulfillment-heartbeat-web.pages.dev/", { headers: { cookie: flippedCookie } }),
  env: accountEnv(signedAuth.db),
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
assert.equal(cooked.publishedAt, "2026-10-06T01:35:23Z");
assert.equal(cooked.metadata.schemaVersion, SCHEMA_VERSION);
assert.equal(cooked.metadata.cookSha, packHome.metadata.cookSha);
assert.ok(cooked.publishedAt > "2026-10-05T22:57:06Z");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Lost %")], "5.19%");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Goal %")], "3.06%");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Missed")], "$420,030.87");
const southDyn = cooked.regionLines.find((line) => line.section === "dynacap" && line.region === "South");
assert.equal(southDyn.children.find((child) => child.division === "United").value, "—");
assert.equal(southDyn.children.find((child) => child.division === "Southwest").value, "51.1");
assert.equal(southDyn.children.find((child) => child.division === "Southern").value, "71.0");
assert.ok(Array.isArray(cooked.regionTables) && cooked.regionTables.length > 10);
const cookedPph = cooked.summaries.find((item) => item.section === "pph");
assert.match(cookedPph.secondary, /between 74 and 80/);
assert.notEqual(cookedPph.health, "risk");
const laborFile = JSON.parse(readFileSync(join(root, "dist/data/section/labor.json"), "utf8"));
const laborBridge = laborFile.rows.filter((row) => {
  const payload = row.payload || {};
  return ["uplh_impact_pct", "wage_impact_pct", "aiv_impact_pct", "target_vs_actual_pct"].every(
    (key) => payload[key] != null,
  );
});
assert.equal(laborBridge.length, 2109);
assert.ok(
  laborBridge.every((row) => {
    const payload = row.payload;
    return (
      Math.abs(payload.uplh_impact_pct + payload.wage_impact_pct + payload.aiv_impact_pct - payload.target_vs_actual_pct) <=
      0.01
    );
  }),
);
const laborByStore = Object.fromEntries(laborFile.rows.map((row) => [row.store, row]));
assert.equal(laborByStore["233"].sourceIssue, "source data issue");
assert.ok(Math.abs(laborByStore["233"].payload.aiv_impact_pct - 587.2133705452294) < 1e-6);
assert.equal(laborByStore["4799"].sourceIssue, "source data issue");
assert.ok(Math.abs(laborByStore["4799"].payload.aiv_impact_pct - 12.298494468568636) < 1e-6);
assert.equal(laborByStore["1509"].sourceIssue, "source data issue");
assert.equal(laborByStore["1509"].payload.sch_hrs, 0);
assert.equal(laborByStore["1"].sourceIssue, undefined);
assert.ok(Math.abs(laborByStore["1"].payload.aiv_impact_pct - -0.38645958215580284) < 1e-9);
assert.equal(laborByStore["1"].payload.weight, 383);
assert.equal(laborByStore["233"].payload.weight, 334);
assert.equal(laborByStore["1509"].payload.weight, 45);
let aivNum = 0;
let aivDen = 0;
for (const row of laborFile.rows) {
  const payload = row.payload || {};
  if (payload.cost_trgt_pct == null || payload.aiv_impact_pct == null || payload.weight == null) continue;
  aivNum += payload.aiv_impact_pct * payload.weight;
  aivDen += payload.weight;
}
assert.ok(aivDen > 0);
assert.ok(Math.abs(aivNum / aivDen - packHome.laborMarket.aiv_impact_pct) <= 0.001);
const lostFile = JSON.parse(readFileSync(join(root, "dist/data/section/lost_revenue.json"), "utf8"));
assert.equal(lostFile.rows.length, 2167);
assert.ok(new Set(lostFile.rows.map((row) => row.division)).size > 8);
assert.ok(lostFile.rows.filter((row) => row.division === "Haggen").length < 30);
const lostByStore = Object.fromEntries(lostFile.rows.map((row) => [row.store, row]));
assert.equal(lostByStore["210"].division, "United");
assert.equal(lostByStore["210"].payload.lost_revenue, 263);
assert.ok(Math.abs(lostByStore["210"].payload.lost_revenue_goal_pct - 0.051076243935462035) < 1e-12);
assert.equal(lostByStore["239"].division, "Southwest");
assert.equal(lostByStore["239"].payload.lost_revenue, 239);
assert.ok(Math.abs(lostByStore["239"].payload.lost_revenue_goal_pct - 0.028608328507213076) < 1e-12);
assert.equal(lostByStore["1509"].payload.lost_revenue_goal_pct, undefined);
const unitedDyn = JSON.parse(readFileSync(join(root, "dist/data/section/dynacap.json"), "utf8")).rows.filter(
  (row) => row.division === "United",
);
assert.ok(unitedDyn.length >= 50);
assert.ok(unitedDyn.every((row) => row.payload.eot_capacity != null && row.payload.used_capacity != null));
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
assert.equal(pct(southSched.eff), "91.04%");
assert.notEqual(pct(southSched.eff), "92.64%");
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
assert.equal(pct(southOnly.eff), "91.04%");
const southDivisions = rankedDivisions(schedule, filters({ region: "South Region" }), []);
assert.equal(southDivisions.find((row) => row.division === "Southwest").scope, 190);
assert.equal(southDivisions.find((row) => row.division === "Southern").scope, 136);
assert.equal(southDivisions.find((row) => row.division === "United").scope, 71);
assert.equal(countStores(cooked.filters.stores, filters({ region: "South Region" })), 397);
assert.equal(regionStoreCount(cooked.filters.stores, "South"), 397);
assert.match(app, /sectionStoreCount/);
assert.match(app, /roster stores/);
assert.match(app, /figureAbsent/);
assert.equal(figureAbsent("$1.00"), false);
assert.equal(figureAbsent("—"), true);
assert.equal(figureAbsent(""), true);
const stickyTop = css.slice(css.indexOf(".sticky-top"), css.indexOf(".titles { min-width"));
assert.equal(stickyTop.includes("position: sticky"), false);
const thRule = css.slice(css.indexOf("\nth {"), css.indexOf("td.good"));
assert.equal(thRule.includes("position: sticky"), false);
const laborRows = JSON.parse(readFileSync(join(root, "public/data/section/labor.json"), "utf8")).rows;
const lostRows = JSON.parse(readFileSync(join(root, "public/data/section/lost_revenue.json"), "utf8")).rows;
const noScope = filters({});
assert.equal(packHome.summaries.find((item) => item.section === "labor").storeCount, 2149);
assert.equal(sectionStoreCount(laborRows, noScope, packRoster, "labor"), 2151);
const laborGrain = sectionRowGrain("labor", laborRows, noScope, packRoster, packHome.regionLines);
assert.deepEqual(
  laborGrain.filter((row) => row.grain === "region").map((row) => [row.label, row.count]),
  [
    ["East", 610],
    ["South", 392],
    ["California", 599],
    ["West", 548],
  ],
);
const poisonedLines = JSON.parse(JSON.stringify(packHome.regionLines)).map((line) => ({
  ...line,
  count: 900000000 + Number(line.count || 0),
  value: typeof line.value === "string" && line.value.endsWith("shoppers") ? `900000000 shoppers` : line.value,
  children: (line.children || []).map((child) => ({ ...child, count: 900000000 + Number(child.count || 0) })),
}));
assert.equal(sectionRowGrain("labor", laborRows, noScope, packRoster, poisonedLines).find((row) => row.label === "East").count, 610);
const pickerRows = JSON.parse(readFileSync(join(root, "public/data/section/picker_scorecard.json"), "utf8")).rows;
const pickerGrain = sectionRowGrain("picker_scorecard", pickerRows, noScope, packRoster, poisonedLines);
const eastPickers = pickerGrain.find((row) => row.grain === "region" && row.label === "East");
assert.equal(eastPickers.count, 9368);
assert.equal(eastPickers.value, "9,368 shoppers");
assert.equal(distinctShopperCount(pickerRows), 29838);
const pickerBands = pickerShopperBands(pickerRows);
assert.equal(pickerBands.shoppers, 29838);
assert.equal(pickerBands.healthy, 2846);
assert.equal(pickerBands.watch, 3261);
assert.equal(pickerBands.risk, 23731);
assert.equal(summarizeSeat("picker_scorecard", pickerRows).secondary, "23731 opportunity · 3261 watch · 2846 doing well");
const eastPickerBuilt = summarizeSeat(
  "picker_scorecard",
  rowsInScope(pickerRows, filters({ region: "East Region" }), packRoster, "picker_scorecard"),
);
assert.equal(eastPickerBuilt.secondary, "8355 opportunity · 612 watch · 401 doing well");
assert.equal(eastPickerBuilt.healthyCount + eastPickerBuilt.watchCount + eastPickerBuilt.riskCount, 9368);
const southernPickers = summarizeSeat(
  "picker_scorecard",
  rowsInScope(pickerRows, filters({ division: "Southern" }), packRoster, "picker_scorecard"),
);
assert.equal(southernPickers.headline, 1613);
const salesRows = JSON.parse(readFileSync(join(root, "public/data/section/sales.json"), "utf8")).rows;
const southernSales = summarizeSeat(
  "sales",
  rowsInScope(salesRows, filters({ division: "Southern" }), packRoster, "sales"),
);
assert.equal(money(southernSales.headline), "$4,351,261.96");
assert.equal(southernSales.health, "good");
const southernLabor = summarizeSeat(
  "labor",
  rowsInScope(laborRows, filters({ division: "Southern" }), packRoster, "labor"),
);
assert.equal(formatHeadline("labor", southernLabor.headline), "-3.09%");
assert.equal(southernLabor.health, "good");
const eastSalesRows = summarizeSeat(
  "sales",
  rowsInScope(salesRows, filters({ region: "East Region" }), packRoster, "sales"),
);
assert.equal(eastSalesRows.health, "good");
assert.match(eastSalesRows.secondary, /499 up/);
assert.match(eastSalesRows.secondary, /85 down/);
const eastLaborRows = summarizeSeat(
  "labor",
  rowsInScope(laborRows, filters({ region: "East Region" }), packRoster, "labor"),
);
assert.equal(eastLaborRows.health, "good");
const dynRows = JSON.parse(readFileSync(join(root, "public/data/section/dynacap.json"), "utf8")).rows;
const dynBuilt = summarizeSeat("dynacap", dynRows);
assert.equal(dynBuilt.storeCount, 2089);
assert.equal(formatHeadline("dynacap", dynBuilt.headline), "67.8");
assert.match(dynBuilt.secondary, /75 stores have capacity but no Pcs\/Hr/);
assert.equal(metricCountLine(dynRows, ["dynacap_rate", "pieces_per_hour"]), "2,089 of 2,164");
assert.equal(metricCountLine(dynRows, ["utilization_pct", "pickup_util_pct"]), "2,089 of 2,164");
assert.equal(metricCountLine(dynRows, ["eot_capacity", "used_capacity"]), "");
assert.match(app, /metricCountLine\(/);
assert.match(app, /<small class="count">/);
assert.match(css, /\.chip small\.count/);
assert.match(app, /stores with no division/);
assert.match(app, /stores with source issues not scored/);
const missingBuilt = summarizeSeat("missing_items", JSON.parse(readFileSync(join(root, "public/data/section/missing_items.json"), "utf8")).rows);
assert.equal(missingBuilt.healthyCount, 252);
assert.equal(missingBuilt.riskCount, 1319);
const presubBuilt = summarizeSeat("pre_sub_oos", JSON.parse(readFileSync(join(root, "public/data/section/pre_sub_oos.json"), "utf8")).rows);
assert.equal(presubBuilt.watchCount, 653);
assert.equal(presubBuilt.riskCount, 522);
const pphBuilt = summarizeSeat("pph", JSON.parse(readFileSync(join(root, "public/data/section/pph.json"), "utf8")).rows);
assert.equal(pphBuilt.atGoalCount, 564);
assert.equal(pphBuilt.riskCount, 1133);
const californiaScope = filters({ region: "California Region" });
assert.equal(countStores(packRoster, californiaScope), 601);
assert.equal(sectionStoreCount(lostRows, californiaScope, packRoster, "lost_revenue"), 600);
for (const region of ["East Region", "South Region", "West Region"]) {
  const scope = filters({ region });
  const rosterCount = countStores(packRoster, scope);
  const lostCount = sectionStoreCount(lostRows, scope, packRoster, "lost_revenue");
  assert.equal(lostCount, rosterCount, region);
}
assert.match(app, /const valueHead = section === "lost_revenue" \? LOST_EXCL_LABEL : "Value"/);
const liveUnited = summary(schedule, filters({ division: "United" }), []);
assert.equal(liveUnited.under, null);
assert.equal(liveUnited.over, null);
assert.equal(liveUnited.eff, null);
const unitedDivision = rankedDivisions(schedule, empty, []).find((row) => row.division === "United");
assert.equal(unitedDivision.under, null);
assert.equal(unitedDivision.over, null);
assert.equal(unitedDivision.eff, null);
assert.equal(scheduleGapNote(schedule, filters({ division: "United" }), []), "No data");
assert.equal(scheduleGapNote(schedule, empty, []).includes("United: No data"), true);
const scheduleByStore = Object.fromEntries(schedule.stores.map((row) => [row.store, row]));
assert.equal(scheduleByStore["210"].om, "Andrew Quinn");
assert.equal(scheduleByStore["239"].om, "Ben Sarmadi");
assert.equal(notScheduled(scheduleByStore["2575"]), true);
assert.equal(notScheduled(scheduleByStore["3066"]), true);
const liveB1 = summary(schedule, filters({ district: "B1" }), []);
assert.equal(pct(liveB1.eff), "67.97%");
assert.notEqual(pct(liveB1.eff), "-480.82%");
assert.equal(summary(schedule, filters({ store: "2575" }), []).eff, null);
assert.equal(notScheduled(scheduleByStore["3566"]), true);
assert.equal(
  schedule.stores.filter((row) => row.under != null && row.under >= 99.5 && (row.eff == null || row.eff <= 0)).length,
  0,
);
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

async function accountRequest(db, path, { method = "GET", body = "", cookie = "", headers = {}, env = null, fetchSite = "same-origin" } = {}) {
  const requestHeaders = { ...headers };
  if (fetchSite && !Object.prototype.hasOwnProperty.call(headers, "sec-fetch-site")) {
    requestHeaders["sec-fetch-site"] = fetchSite;
  }
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
assert.equal(peopleHtml.includes("Back to Heartbeat"), false);
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
assert.equal(viewerDeniedHtml.includes("Back to Heartbeat"), false);
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
const otherIp = await accountRequest(throttle.db, "/login", {
  method: "POST",
  body: "email=nobody@example.com&password=not-a-real-password",
  headers: { "x-forwarded-for": "203.0.113.9" },
});
assert.equal(otherIp.status, 401);
const heartbeatSameIp = await accountRequest(throttle.db, "/login", {
  method: "POST",
  body: "email=heartbeat&password=not-the-shared-password",
});
assert.equal(heartbeatSameIp.status, 401);

const legacy = openAuth();
const legacyIn = await accountRequest(legacy.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
});
assert.equal(legacyIn.status, 303);
const sharedWhileAccounts = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=heartbeat&password=test-only-secret",
});
assert.equal(sharedWhileAccounts.status, 303);
const sharedSession = await accountRequest(auth.db, "/session", { cookie: cookieHeader(sharedWhileAccounts) });
assert.deepEqual(await sharedSession.json(), { email: "heartbeat", role: "viewer", account: false });
const sharedAdmin = await accountRequest(auth.db, "/admin", { cookie: cookieHeader(sharedWhileAccounts) });
assert.equal(sharedAdmin.status, 403);
const sharedCookie = cookieHeader(sharedWhileAccounts);
const sharedLogout = await accountRequest(auth.db, "/logout", { method: "POST", cookie: sharedCookie });
assert.equal(sharedLogout.status, 302);
assert.match(sharedLogout.headers.get("set-cookie") || "", /Max-Age=0/);
const sharedReplay = await accountRequest(auth.db, "/session", { cookie: sharedCookie });
assert.equal(sharedReplay.status, 401);
const sharedReplayPage = await accountRequest(auth.db, "/", { cookie: sharedCookie });
assert.match(await sharedReplayPage.text(), /action="\/login"/);
const testerWhileAccounts = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "email=tester&password=tester-only-secret",
});
assert.equal(testerWhileAccounts.status, 303);
const testerSession = await accountRequest(auth.db, "/session", { cookie: cookieHeader(testerWhileAccounts) });
assert.deepEqual(await testerSession.json(), { email: "tester", role: "viewer", account: false });
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
  headers: { origin: "https://evil.example", "sec-fetch-site": "cross-site" },
});
assert.equal(crossSite.status, 403);
const crossSiteHtml = await crossSite.text();
assert.match(crossSiteHtml, /Sign-in blocked: please open the site directly and try again/);
assert.equal(crossSiteHtml.includes("That email or password is wrong."), false);

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
assert.match(viewerAccountHtml, /class="header-back"/);
assert.equal(viewerAccountHtml.includes("Back to Heartbeat"), false);
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
assert.deepEqual(await legacySession.json(), { email: "heartbeat", role: "viewer", account: false });
const legacyAccount = await accountRequest(legacy.db, "/account", { cookie: cookieHeader(legacyIn) });
const legacyAccountHtml = await legacyAccount.text();
assert.match(legacyAccountHtml, /does not have its own password/);
assert.match(legacyAccountHtml, /class="header-back"/);
assert.equal(legacyAccountHtml.includes('href="/admin">User management'), false);
assert.equal(legacyAccountHtml.includes("Back to Heartbeat"), false);
const sessionDenied = await accountRequest(auth.db, "/session");
assert.equal(sessionDenied.status, 401);
const loginPage = await accountRequest(auth.db, "/login");
assert.equal(loginPage.status, 200);
assert.equal(loginPage.headers.get("referrer-policy"), "same-origin");
const browserLogin = openAuth();
const nullOrigin = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null", "sec-fetch-site": "same-origin" },
});
assert.equal(nullOrigin.status, 303);
assert.match(nullOrigin.headers.get("set-cookie") || "", /^hb_session=/);
const nullOriginWrong = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=not-the-shared-password",
  headers: { origin: "null", "sec-fetch-site": "same-origin" },
});
assert.equal(nullOriginWrong.status, 401);
const nullOriginWrongHtml = await nullOriginWrong.text();
assert.match(nullOriginWrongHtml, /That email or password is wrong/);
assert.equal(nullOriginWrongHtml.includes("Sign-in blocked:"), false);
assert.equal(browserLogin.raw.prepare("SELECT failures FROM login_attempts").get().failures, 1);
const nullOriginBlocked = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null", "sec-fetch-site": "cross-site" },
});
assert.equal(nullOriginBlocked.status, 403);
const nullOriginBlockedHtml = await nullOriginBlocked.text();
assert.match(nullOriginBlockedHtml, /Sign-in blocked: please open the site directly and try again/);
assert.equal(nullOriginBlockedHtml.includes("That email or password is wrong."), false);
assert.equal(browserLogin.raw.prepare("SELECT failures FROM login_attempts").get().failures, 1);
const blockedBefore = browserLogin.raw.prepare("SELECT failures FROM login_attempts").get().failures;
for (const site of ["cross-site", "same-site"]) {
  const blocked = await accountRequest(browserLogin.db, "/login", {
    method: "POST",
    body: "username=heartbeat&password=test-only-secret",
    headers: {
      origin: "null",
      "sec-fetch-site": site,
      referer: "https://fulfillment-heartbeat-web.pages.dev/login",
    },
  });
  assert.equal(blocked.status, 403);
  const blockedHtml = await blocked.text();
  assert.match(blockedHtml, /Sign-in blocked: please open the site directly and try again/);
  assert.equal(blockedHtml.includes("That email or password is wrong."), false);
}
assert.equal(browserLogin.raw.prepare("SELECT failures FROM login_attempts").get().failures, blockedBefore);
const refererLogin = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null", "sec-fetch-site": "none", referer: "https://fulfillment-heartbeat-web.pages.dev/login" },
});
assert.equal(refererLogin.status, 303);
const missingFetchBlocked = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null" },
  fetchSite: false,
});
assert.equal(missingFetchBlocked.status, 403);
const missingFetchBlockedHtml = await missingFetchBlocked.text();
assert.match(missingFetchBlockedHtml, /Sign-in blocked: please open the site directly and try again/);
assert.equal(missingFetchBlockedHtml.includes("That email or password is wrong."), false);
assert.equal(browserLogin.raw.prepare("SELECT COUNT(*) AS n FROM login_attempts").get().n, 0);
const missingFetchWrongHost = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null", referer: "https://evil.example/login" },
  fetchSite: false,
});
assert.equal(missingFetchWrongHost.status, 403);
assert.match(await missingFetchWrongHost.text(), /Sign-in blocked: please open the site directly and try again/);
assert.equal(browserLogin.raw.prepare("SELECT COUNT(*) AS n FROM login_attempts").get().n, 0);
const missingFetch = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "null", referer: "https://fulfillment-heartbeat-web.pages.dev/login" },
  fetchSite: false,
});
assert.equal(missingFetch.status, 303);
assert.match(missingFetch.headers.get("set-cookie") || "", /^hb_session=/);
const sameOriginLogin = await accountRequest(auth.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: { origin: "https://fulfillment-heartbeat-web.pages.dev" },
});
assert.equal(sameOriginLogin.status, 303);
const ownOriginAttempts = browserLogin.raw.prepare("SELECT COUNT(*) AS n FROM login_attempts").get().n;
const crossSiteOwnOrigin = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: {
    origin: "https://fulfillment-heartbeat-web.pages.dev",
    "sec-fetch-site": "cross-site",
  },
});
assert.equal(crossSiteOwnOrigin.status, 403);
const crossSiteOwnOriginHtml = await crossSiteOwnOrigin.text();
assert.match(crossSiteOwnOriginHtml, /Sign-in blocked: please open the site directly and try again/);
assert.equal(crossSiteOwnOriginHtml.includes("That email or password is wrong."), false);
assert.equal(browserLogin.raw.prepare("SELECT COUNT(*) AS n FROM login_attempts").get().n, ownOriginAttempts);
const sameSiteOwnOrigin = await accountRequest(browserLogin.db, "/login", {
  method: "POST",
  body: "username=heartbeat&password=test-only-secret",
  headers: {
    origin: "https://fulfillment-heartbeat-web.pages.dev",
    "sec-fetch-site": "same-site",
  },
});
assert.equal(sameSiteOwnOrigin.status, 403);
assert.match(await sameSiteOwnOrigin.text(), /Sign-in blocked: please open the site directly and try again/);
assert.equal(browserLogin.raw.prepare("SELECT COUNT(*) AS n FROM login_attempts").get().n, ownOriginAttempts);

const formOrigin = openAuth();
const formSetup = await accountRequest(formOrigin.db, "/setup", { headers: { authorization: "Bearer setup-secret-value" } });
const formAdminInvite = inviteToken(await formSetup.text());
const formJoined = await accountRequest(formOrigin.db, `/invite/${formAdminInvite}`, {
  method: "POST",
  body: "password=long-enough-1&confirm=long-enough-1",
  headers: { origin: "null", "sec-fetch-site": "same-origin" },
});
assert.equal(formJoined.status, 303);
const formAdmin = cookieHeader(formJoined);
const formCrossInvite = await accountRequest(formOrigin.db, "/admin", {
  method: "POST",
  cookie: formAdmin,
  body: "action=add&email=cross-invite@example.com&role=viewer",
  headers: { origin: "https://evil.example", "sec-fetch-site": "cross-site" },
});
assert.equal(formCrossInvite.status, 403);
const formCrossInviteHtml = await formCrossInvite.text();
assert.match(formCrossInviteHtml, /Sign-in blocked: please open the site directly and try again/);
assert.equal(formCrossInviteHtml.includes("/invite/"), false);
const formAdded = await accountRequest(formOrigin.db, "/admin", {
  method: "POST",
  cookie: formAdmin,
  body: "action=add&email=same-invite@example.com&role=viewer",
  headers: { origin: "null", "sec-fetch-site": "same-origin" },
});
assert.equal(formAdded.status, 200);
const formInvite = inviteToken(await formAdded.text());
const formInviteBlocked = await accountRequest(formOrigin.db, `/invite/${formInvite}`, {
  method: "POST",
  body: "password=viewer-pass-8&confirm=viewer-pass-8",
  headers: { origin: "https://evil.example", "sec-fetch-site": "cross-site" },
});
assert.equal(formInviteBlocked.status, 403);
assert.match(await formInviteBlocked.text(), /Sign-in blocked: please open the site directly and try again/);
const formInviteReferer = await accountRequest(formOrigin.db, `/invite/${formInvite}`, {
  method: "POST",
  body: "password=viewer-pass-8&confirm=viewer-pass-8",
  headers: { origin: "null", referer: "https://fulfillment-heartbeat-web.pages.dev/invite/" + formInvite },
  fetchSite: false,
});
assert.equal(formInviteReferer.status, 303);
const formViewer = cookieHeader(formInviteReferer);
const formAccountBlocked = await accountRequest(formOrigin.db, "/account", {
  method: "POST",
  cookie: formViewer,
  body: "current=viewer-pass-8&password=viewer-pass-9&confirm=viewer-pass-9",
  headers: { origin: "https://evil.example", "sec-fetch-site": "cross-site" },
});
assert.equal(formAccountBlocked.status, 403);
assert.match(await formAccountBlocked.text(), /Sign-in blocked: please open the site directly and try again/);
const formAccount = await accountRequest(formOrigin.db, "/account", {
  method: "POST",
  cookie: formViewer,
  body: "current=viewer-pass-8&password=viewer-pass-9&confirm=viewer-pass-9",
  headers: { origin: "null", "sec-fetch-site": "same-origin" },
});
assert.equal(formAccount.status, 200);
assert.match(await formAccount.text(), /Password saved/);
const formStill = await accountRequest(formOrigin.db, "/", { cookie: formViewer });
assert.equal(await formStill.text(), "page");

async function legacyPasswordCookie(env, user, pass) {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(pass));
  const version = [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("").slice(0, 32);
  const body = `${user}|${exp}|${version}`;
  const bytes = new TextEncoder().encode(body);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  const encoded = btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(env.SESSION_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(encoded));
  const sig = [...new Uint8Array(signed)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${encoded}.${sig}`;
}

const { runFakeCountLab } = await import("./test_fake_counts.mjs");
await runFakeCountLab(join(root, "public"));

console.log("web ok");
