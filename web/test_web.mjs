import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
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
import { bannerText, considerPublished, formatHeadline, money, publishClock, updatedLine } from "./public/clock.js";
import {
  canonicalDivision,
  canonicalStore,
  countStores,
  includesScope,
  isPersonOm,
  matchesDistrict,
  optionValues,
  matchesDivision,
  regionLineInScope,
  scopeStoreCount,
  sectionGrainRows,
} from "./public/filters.js";
import { FIGURE_SECTIONS, packURL } from "./public/packs.js";
import { chromeSeat, lossPercentPoints, seatSummary } from "./public/seat.js";
import {
  bannerMismatch,
  companyMarketNote,
  notScheduled,
  barelyScheduled,
  percentHealth,
  qualifies,
  qualifiesStore,
  scheduleVisibleTitle,
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
assert.match(app, /HB-0828\.494/);
assert.equal((stamp.match(/HB-0828\.494/g) || []).length, 1);
assert.equal(app.includes("Sign in with the email PIN"), false);
assert.equal(app.includes("/api/"), false);
assert.match(app, /packURL/);

assert.equal(packURL("home"), "/data/home.json");
assert.equal(packURL("section/sales"), "/data/section/sales.json");
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
assert.match(pageHtml, /src="\/nav-boot\.js"/);
assert.equal(/<script>\s*try/.test(pageHtml), false);
assert.match(readFileSync(join(root, "public/nav-boot.js"), "utf8"), /nav-collapsed/);
const lockup = pageHtml.slice(pageHtml.indexOf('class="brand-lockup"'), pageHtml.indexOf("</p>", pageHtml.indexOf('class="brand-lockup"')));
assert.ok(lockup.indexOf("wordmark") < lockup.indexOf('class="heart"'));
assert.ok(lockup.indexOf('class="heart"') < lockup.indexOf('class="pulse"'));
assert.match(css, /left:\s*50%/);
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
assert.equal(company.usesMarketLook, true);
assert.match(companyMarketNote(company, empty), /Under 60\.00% \/ Over 0\.50%/);
const united = summary(pack, filters({ division: "United" }));
assert.equal(united.usesMarketLook, true);
assert.equal(united.under, null);
assert.equal(united.over, null);
const cut = summary(pack, filters({ division: "United", district: "U1" }));
assert.equal(cut.usesMarketLook, false);
assert.equal(cut.under, 60);
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

const wrangler = readFileSync(join(root, "wrangler.toml"), "utf8");
assert.match(wrangler, /name = "fulfillment-heartbeat-web"/);
assert.match(wrangler, /pages_build_output_dir = "dist"/);
assert.equal(wrangler.includes("heartbeat-web.pages.dev"), false);
const built = spawnSync(process.execPath, ["scripts/stage_pages.mjs"], { cwd: root });
assert.equal(built.status, 0, built.stderr.toString());
const distIndex = readFileSync(join(root, "dist/index.html"), "utf8");
assert.match(distIndex, /HB-0828\.494/);
assert.match(distIndex, /aria-label="Fulfillment Heartbeat"/);
assert.match(distIndex, /class="fulfill">Fulfill</);
assert.equal(distIndex.includes("pages.dev"), false);
assert.match(app, /class="figure"/);
assert.equal(statSync(join(root, "functions/api/[[path]].js")).isFile(), true);

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
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Lost %")], "5.19%");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Goal %")], "3.06%");
assert.equal(lostTiles.values[lostTiles.labels.indexOf("Missed")], "$178,705.37");
const southDyn = cooked.regionLines.find((line) => line.section === "dynacap" && line.region === "South");
assert.ok(southDyn.children.some((child) => child.division === "United" && child.value === "—"));
assert.ok(Array.isArray(cooked.regionTables) && cooked.regionTables.some((row) => row.region === "East" && row.title === "Sales"));
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
assert.ok(schedule.week >= 32);
assert.ok(schedule.stores.length > 1000);
assert.match(scheduleVisibleTitle(schedule.summaryTitle, schedule.week), new RegExp(`Week ${schedule.week}`));
const storeOne = cooked.filters.stores.find((row) => row.store === "1");
assert.equal(isPersonOm(storeOne.om), true);
const quinnStores = cooked.filters.stores.filter((row) => row.om === "Andrew Quinn");
assert.ok(quinnStores.length > 1);
assert.ok(countStores(cooked.filters.stores, filters({ region: "East Region" })) > 400);

console.log("web ok");
