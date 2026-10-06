// Architecture's fake-count lab. Every digit in a home.json text field is
// rewritten, and each hit is tagged. A count tag on screen fails the run
// unless it is the Sales Orders or Items tile labeled workbook total.
import { money } from "./public/clock.js";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, normalize } from "node:path";

const DIGITS = "5678901234";
const LABEL_KEYS = new Set([
  "section",
  "region",
  "title",
  "label",
  "labels",
  "division",
  "health",
  "name",
  "store",
  "om",
  "district",
  "headlineLabel",
  "id",
  "kind",
  "grain",
  "page",
  "role",
  "email",
  "cookSha",
  "schemaVersion",
  "publishedAt",
  "asOf",
  "updatedAt",
  "generatedAt",
  "week",
]);
const NUMBER_KEYS = new Set([
  "headline",
  "watchCount",
  "riskCount",
  "healthyCount",
  "atGoalCount",
  "betweenCount",
  "count",
  "storeCount",
  "shoppers",
  "healthy",
  "watch",
  "risk",
  "stores",
]);
const PAGES = [
  "dashboard",
  "sales",
  "lost_revenue",
  "missing_items",
  "five_star",
  "pre_sub_oos",
  "pick_path",
  "prep_not_ready",
  "dynacap",
  "schedule_quality",
  "schedule",
  "picker_scorecard",
  "pph",
  "labor",
];
function mapDigits(text) {
  return String(text).replace(/\d/g, (digit) => DIGITS[digit]);
}

function classify(source, index, raw) {
  const before = source.slice(Math.max(0, index - 24), index);
  const after = source.slice(index + raw.length, index + raw.length + 24);
  const window = source.slice(Math.max(0, index - 24), index + raw.length + 24);
  if (/\d{4}-\d{2}-\d{2}/.test(window) || /T\d{2}:\d{2}/.test(window) || /\d[/-]$/.test(before) || /^[/-]\d/.test(after)) {
    return "date";
  }
  if (raw.includes("$") || /\$\s*$/.test(before)) return "money";
  if (raw.includes("%") || after.startsWith("%")) return "percent";
  if (raw.includes(".")) return "decimal";
  return "count";
}

function tagNumber(key, value, section) {
  if (key !== "headline") return "count";
  if (section === "picker_scorecard") return "count";
  if (section === "sales" || section === "lost_revenue") return "money";
  if (section === "five_star" || section === "dynacap" || section === "pph") return "decimal";
  if (Number.isInteger(value)) return "count";
  return "percent";
}

function bareDigits(token) {
  return String(token).replace(/[^\d]/g, "");
}

function remember(book, literal, tag, allowWorkbook, field = "") {
  const bare = bareDigits(literal);
  book.tags.push({ literal, bare, tag, field });
  if (tag !== "count" || !bare) return literal;
  book.countBares.add(bare);
  book.countBares.add(Number(bare).toLocaleString("en-US").replace(/,/g, ""));
  if (allowWorkbook) book.allowBares.add(bare);
  return literal;
}

function prefixCount(raw) {
  const lead = (/^(\$?-?)/.exec(raw) || ["", ""])[1];
  return `${lead}900${raw.slice(lead.length)}`;
}

function rewriteString(text, book, allowWorkbook, field = "") {
  return String(text).replace(/\$?-?\d[\d,]*(?:\.\d+)?%?/g, (raw, index) => {
    const tag = classify(text, index, raw);
    const mapped = mapDigits(raw);
    const fake = tag === "date" ? mapped : prefixCount(mapped);
    return remember(book, fake, tag, allowWorkbook && tag === "count", field);
  });
}

function rewriteNumber(value, tag, book) {
  const negative = Number(value) < 0;
  const mapped = mapDigits(String(Math.abs(Number(value))));
  const fake = `${negative ? "-" : ""}900${mapped}`;
  remember(book, fake, tag, false);
  const numeric = Number(fake);
  return Number.isFinite(numeric) ? numeric : value;
}

export function poisonHome(home) {
  const copy = structuredClone(home);
  const book = { tags: [], countBares: new Set(), allowBares: new Set(), orders: "", items: "" };
  const tileBlocks = new Set();
  const tiles = copy.companyTiles && typeof copy.companyTiles === "object" ? copy.companyTiles : {};
  for (const [section, block] of Object.entries(tiles)) {
    if (!block || !Array.isArray(block.labels) || !Array.isArray(block.values)) continue;
    tileBlocks.add(block);
    block.labels.forEach((label, index) => {
      if (typeof block.values[index] !== "string") return;
      const allow = section === "sales" && (label === "Orders" || label === "Items");
      block.values[index] = rewriteString(block.values[index], book, allow, `${section}:${label}`);
      if (section === "sales" && label === "Orders") book.orders = block.values[index];
      if (section === "sales" && label === "Items") book.items = block.values[index];
    });
  }
  const walk = (node) => {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (tileBlocks.has(node)) return;
    const section = typeof node.section === "string" ? node.section : "";
    const tiled = Array.isArray(node.labels) && Array.isArray(node.values);
    if (tiled) {
      node.labels.forEach((label, index) => {
        if (typeof node.values[index] === "string") {
          node.values[index] = rewriteString(node.values[index], book, false);
        }
      });
    }
    for (const [key, value] of Object.entries(node)) {
      if (LABEL_KEYS.has(key) || (tiled && key === "values")) continue;
      if (typeof value === "string") node[key] = rewriteString(value, book, false);
      else if (typeof value === "number" && Number.isFinite(value) && NUMBER_KEYS.has(key)) {
        node[key] = rewriteNumber(value, tagNumber(key, value, section), book);
      } else if (value && typeof value === "object") walk(value);
    }
  };
  walk(copy);
  return { home: copy, book };
}

function hasNumber(text, number) {
  const bare = String(number);
  const comma = Number(number).toLocaleString("en-US");
  const pattern = (token) => new RegExp(`(^|\\D)${token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(\\D|$)`);
  return pattern(bare).test(text) || pattern(comma).test(text);
}

function startServer(publicDir, poisoned) {
  const body = JSON.stringify(poisoned);
  const server = createServer((req, res) => {
    const url = new URL(req.url || "/", "http://127.0.0.1");
    if (url.pathname === "/data/home.json") {
      res.setHeader("content-type", "application/json");
      res.setHeader("cache-control", "no-store");
      res.end(body);
      return;
    }
    const requestPath = url.pathname === "/" ? "/index.html" : url.pathname;
    const rel = normalize(decodeURIComponent(requestPath)).replace(/^([/\\])+/, "");
    if (rel.includes("..")) {
      res.statusCode = 404;
      res.end("missing");
      return;
    }
    const file = join(publicDir, rel);
    if (!file.startsWith(publicDir)) {
      res.statusCode = 404;
      res.end("missing");
      return;
    }
    try {
      if (!statSync(file).isFile()) throw new Error("dir");
    } catch {
      res.statusCode = 404;
      res.end("missing");
      return;
    }
    const type = file.endsWith(".html")
      ? "text/html"
      : file.endsWith(".js")
        ? "text/javascript"
        : file.endsWith(".css")
          ? "text/css"
          : file.endsWith(".json")
            ? "application/json"
            : file.endsWith(".svg")
              ? "image/svg+xml"
              : file.endsWith(".png")
                ? "image/png"
                : "application/octet-stream";
    res.setHeader("content-type", type);
    res.end(readFileSync(file));
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForJson(port) {
  const started = Date.now();
  let last = "";
  while (Date.now() - started < 15000) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`);
      if (response.ok) {
        const list = await response.json();
        const page = list.find((item) => item.type === "page" && item.webSocketDebuggerUrl);
        if (page) return page;
      }
    } catch (error) {
      last = error instanceof Error ? error.message : String(error);
    }
    await sleep(100);
  }
  throw new Error(`chrome debug port did not open (${last})`);
}

async function debugPort(profile) {
  const file = join(profile, "DevToolsActivePort");
  const started = Date.now();
  while (Date.now() - started < 15000) {
    try {
      const port = readFileSync(file, "utf8").split("\n")[0].trim();
      if (port) return port;
    } catch {
      /* chrome is still starting */
    }
    await sleep(50);
  }
  throw new Error("chrome did not write a debug port");
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const pending = new Map();
  const opened = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve);
    ws.addEventListener("error", () => reject(new Error("chrome socket failed")));
  });
  ws.addEventListener("message", (event) => {
    const message = JSON.parse(typeof event.data === "string" ? event.data : event.data.toString());
    if (!message.id || !pending.has(message.id)) return;
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(JSON.stringify(message.error)));
    else resolve(message.result);
  });
  return {
    ready: opened,
    send(method, params = {}) {
      const next = ++id;
      return new Promise((resolve, reject) => {
        pending.set(next, { resolve, reject });
        ws.send(JSON.stringify({ id: next, method, params }));
      });
    },
    close() {
      ws.close();
    },
  };
}

async function evaluate(client, expression) {
  const result = await client.send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  if (result.exceptionDetails) {
    const text = result.exceptionDetails.exception && result.exceptionDetails.exception.description;
    throw new Error(text || JSON.stringify(result.exceptionDetails));
  }
  return result.result ? result.result.value : undefined;
}

async function settle(client, timeout = 60000) {
  const started = Date.now();
  let last = "";
  while (Date.now() - started < timeout) {
    last = await evaluate(client, `document.querySelector("#main") ? document.querySelector("#main").innerText : ""`);
    if (last && !last.includes("Loading…")) return last;
    await sleep(150);
  }
  const href = await evaluate(client, "location.href").catch(() => "");
  throw new Error(`page stayed on Loading… ${href} ${String(last).slice(0, 240)}`);
}

async function visibleText(client) {
  return evaluate(
    client,
    `(() => {
      const open = document.querySelector("#browse-open");
      if (open && open.getAttribute("aria-expanded") !== "true") open.click();
      return document.body.innerText;
    })()`,
  );
}

async function readTiles(client) {
  return evaluate(
    client,
    `(() => {
      const chips = [...document.querySelectorAll(".chip")].map((node) => {
        const span = node.querySelector("span");
        const strong = node.querySelector("strong");
        return { label: span ? span.textContent.trim() : "", value: strong ? strong.textContent.trim() : "" };
      });
      const figures = [...document.querySelectorAll(".figure, .line-value strong")].map((node) => ({
        label: node.textContent.trim(),
        value: node.textContent.trim(),
        figure: true,
      }));
      return chips.concat(figures);
    })()`,
  );
}

async function showPage(client, id) {
  await evaluate(
    client,
    `(() => {
      const button = document.querySelector('#drawer [data-page="${id}"]');
      if (!button) throw new Error("missing page ${id}");
      button.click();
    })()`,
  );
  await settle(client);
}

async function pickBrowse(client, prefix) {
  await evaluate(
    client,
    `(() => {
      const open = document.querySelector("#browse-open");
      if (open.getAttribute("aria-expanded") !== "true") open.click();
      const rows = [...document.querySelectorAll("#browse-list .browse-row")];
      const hit = ${prefix ? `rows.find((row) => row.textContent.trim().startsWith(${JSON.stringify(prefix)}))` : "rows[0]"};
      if (!hit) throw new Error("no browse row ${prefix || "first"} :: " + rows.map((row) => row.textContent.trim()).slice(0, 6).join(" | "));
      hit.click();
    })()`,
  );
  await settle(client);
}

async function clearScope(client) {
  await evaluate(
    client,
    `(() => {
      const button = document.querySelector("[data-clear-scope]") || document.querySelector("#clear-filters");
      if (button) button.click();
    })()`,
  );
  await settle(client);
}

// Workbook Total fields. A "workbook total" label excuses only that field's own element.
const WORKBOOK_FIELDS = new Set([
  "sales:Sales $",
  "sales:YoY",
  "sales:Ord YoY",
  "sales:Orders",
  "sales:Items",
  "lost_revenue:Lost $",
  "lost_revenue:Lost %",
  "lost_revenue:Goal %",
  "lost_revenue:eComm $",
  "lost_revenue:Post Sub",
  "lost_revenue:Refund",
  "lost_revenue:Missed",
  "lost_revenue:Cancel",
  "lost_revenue:Kill",
  "labor:Target Vs Actual",
  "labor:Act Cost",
  "labor:Cost Tgt",
  "labor:Sch Eff",
  "labor:UPLH",
  "labor:Wage",
  "labor:AIV",
]);

function displayForms(tag, literal) {
  const forms = new Set([String(literal)]);
  if (tag === "money" || String(literal).includes("$")) forms.add(money(literal));
  return [...forms].filter((form) => form && form !== "—");
}

function labelAllows(label, field) {
  const text = String(label || "").toLowerCase().replace(/\s+/g, " ").trim();
  if (field === "prep_not_ready:Goal") return text === "goal target";
  if (field === "prep_not_ready:Watch") return text === "watch target";
  const workbook = text.includes("workbook total") || text.includes("workbook roll-up");
  if (field && WORKBOOK_FIELDS.has(field)) {
    if (!workbook) return false;
    const name = field.split(":")[1].toLowerCase();
    return text.startsWith(name);
  }
  if (field) return false;
  if (text === "goal target" || text === "watch target") return true;
  return text.endsWith("workbook total") || text.endsWith("workbook roll-up");
}

export function packFigureLeaks(tiles, book) {
  const leaks = [];
  for (const tag of book.tags || []) {
    if (tag.tag !== "percent" && tag.tag !== "money" && tag.tag !== "decimal") continue;
    const forms = displayForms(tag.tag, tag.literal);
    for (const tile of tiles || []) {
      const shown = forms.some((form) => tile.value === form || (tile.figure && String(tile.value).includes(form)));
      if (!shown) continue;
      if (!labelAllows(tile.label, tag.field || "")) leaks.push(`${tag.field || tag.literal} on ${tile.label}`);
    }
  }
  return leaks;
}

function countAuthorized(tiles, token) {
  return (tiles || []).some((tile) => {
    if (!String(tile.value).includes(token)) return false;
    const label = String(tile.label || "").toLowerCase();
    if (!label.includes("workbook total")) return false;
    return label.startsWith("orders") || label.startsWith("items");
  });
}

function assertClean(text, book, where, tiles = []) {
  const hits = [];
  const re = /\d[\d,]*/g;
  let match;
  while ((match = re.exec(text))) {
    const token = match[0];
    const bare = token.replace(/,/g, "");
    if (!book.countBares.has(bare)) continue;
    const after = text[match.index + token.length] || "";
    const before = text[match.index - 1] || "";
    if (after === "." || after === "%" || before === "$" || before === ".") continue;
    if (book.allowBares.has(bare) && countAuthorized(tiles, token)) continue;
    hits.push(token);
  }
  if (hits.length) throw new Error(`${where} rendered fake count ${hits.slice(0, 6).join(", ")}`);
  const rates = packFigureLeaks(tiles, book);
  if (rates.length) throw new Error(`${where} rendered unlabeled pack figure ${rates.slice(0, 6).join(", ")}`);
}

function plantedLeakBook() {
  const book = { tags: [], countBares: new Set(), allowBares: new Set() };
  remember(book, "$9001.00", "money", false, "lost_revenue:eComm $");
  remember(book, "90080.91%", "percent", false, "five_star:Flash");
  remember(book, "9002.65%", "percent", false, "prep_not_ready:PNR %");
  remember(book, "900905,034", "count", true, "sales:Orders");
  return book;
}

export function plantedLeakFailures() {
  const book = plantedLeakBook();
  const formatted = money("$9001.00");
  const flash = packFigureLeaks([{ label: "Flash workbook total", value: "90080.91%" }], book);
  const ecomm = packFigureLeaks([{ label: "eComm", value: formatted }], book);
  const pnr = packFigureLeaks(
    [
      { label: "Target Vs Actual workbook total", value: "-4.06%" },
      { label: "PNR %", value: "9002.65%" },
    ],
    book,
  );
  const goal = packFigureLeaks([{ label: "Goal target", value: "1.9%" }], book);
  const kept = packFigureLeaks([{ label: "eComm $ workbook total", value: formatted }], book);
  const orders = countAuthorized([{ label: "Orders workbook total", value: "900905,034" }], "900905,034");
  const ordersNearby = countAuthorized([{ label: "Flash workbook total", value: "900905,034" }], "900905,034");
  if (!flash.length) throw new Error("planted Flash workbook total was excused");
  if (!ecomm.length) throw new Error("planted plain eComm label was excused");
  if (!pnr.length) throw new Error("planted PNR was excused by Target Vs Actual");
  if (goal.length) throw new Error("goal target was flagged");
  if (kept.length) throw new Error("labeled eComm workbook total was flagged");
  if (!orders || ordersNearby) throw new Error("count allow list is not per field");
}

async function regionPickerChips(client) {
  return evaluate(
    client,
    `(() => [...document.querySelectorAll(".region-cards article")].map((card) => {
      const name = card.querySelector("h2") ? card.querySelector("h2").textContent.trim() : "";
      const chip = [...card.querySelectorAll(".chip")].find((node) => {
        const span = node.querySelector("span");
        return span && span.textContent.trim() === "Picker";
      });
      const strong = chip && chip.querySelector("strong");
      return { name, value: strong ? strong.textContent.trim() : "" };
    }))()`,
  );
}

async function readChip(client, labelStart) {
  return evaluate(
    client,
    `(() => {
      const chip = [...document.querySelectorAll(".chip")].find((node) => {
        const span = node.querySelector("span");
        return span && span.textContent.trim().toLowerCase().startsWith(${JSON.stringify(labelStart.toLowerCase())});
      });
      if (!chip) return null;
      const span = chip.querySelector("span");
      const strong = chip.querySelector("strong");
      return { label: span ? span.textContent.trim() : "", value: strong ? strong.textContent.trim() : "" };
    })()`,
  );
}

async function regionNamedChip(client, title) {
  return evaluate(
    client,
    `(() => {
      const card = document.querySelector(".region-cards article");
      if (!card) return "";
      const chip = [...card.querySelectorAll(".chip")].find((node) => {
        const span = node.querySelector("span");
        return span && span.textContent.trim().toLowerCase().startsWith(${JSON.stringify(title.toLowerCase())});
      });
      const strong = chip && chip.querySelector("strong");
      return strong ? strong.textContent.trim() : "";
    })()`,
  );
}

function expectChips(chips, expected, where) {
  const got = Object.fromEntries((chips || []).map((chip) => [chip.name, chip.value]));
  for (const [name, value] of Object.entries(expected)) {
    if (got[name] !== value) throw new Error(`${where} ${name} picker chip ${got[name] || "missing"}, expected ${value}`);
  }
}

async function searchStore(client, query) {
  await evaluate(
    client,
    `(() => {
      const input = document.querySelector("#scope-search");
      const proto = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
      proto.set.call(input, ${JSON.stringify(query)});
      input.dispatchEvent(new Event("input", { bubbles: true }));
    })()`,
  );
  await sleep(250);
  const clicked = await evaluate(
    client,
    `(() => {
      const rows = [...document.querySelectorAll("#scope-results [data-hit]")];
      const hit = rows.find((row) => row.textContent.trim().startsWith("0688"));
      if (!hit) return rows.map((row) => row.textContent.trim()).slice(0, 8).join(" | ") || "no hits";
      hit.click();
      return "ok";
    })()`,
  );
  if (clicked !== "ok") throw new Error(`store search missed 0688: ${clicked}`);
  await settle(client);
  const chips = await evaluate(
    client,
    `[...document.querySelectorAll("#scope-chips .scope-chip")].map((node) => node.textContent.trim()).join(" > ")`,
  );
  if (!String(chips).includes("0688")) throw new Error(`store scope is not 0688: ${chips}`);
}

async function assertDynacapDirect(client, port) {
  const url = `http://127.0.0.1:${port}/?page=dynacap`;
  await client.send("Page.navigate", { url });
  await settle(client, 90000);
  const opened = await readChip(client, "PPH");
  if (!opened || opened.value === "Loading…" || opened.value === "—" || !opened.label.toLowerCase().includes("store average")) {
    throw new Error(`direct dynacap PPH ${opened ? `${opened.label} ${opened.value}` : "missing"}`);
  }
  const pcs = await readChip(client, "Pcs/Hr");
  if (!pcs || pcs.value !== "67.8" || !pcs.label.toLowerCase().includes("store average")) {
    throw new Error(`direct dynacap Pcs/Hr ${pcs ? `${pcs.label} ${pcs.value}` : "missing"}`);
  }
  await client.send("Page.reload", { ignoreCache: true });
  await settle(client, 90000);
  const again = await readChip(client, "PPH");
  if (!again || again.value === "Loading…" || again.value === "—") {
    throw new Error(`reloaded dynacap PPH ${again ? `${again.label} ${again.value}` : "missing"}`);
  }
  const href = await evaluate(client, "location.search");
  if (!String(href).includes("page=dynacap")) throw new Error(`reload left dynacap: ${href}`);
}

export async function runFakeCountLab(publicDir) {
  plantedLeakFailures();
  const original = JSON.parse(readFileSync(join(publicDir, "data/home.json"), "utf8"));
  const { home, book } = poisonHome(original);
  const laborEast = home.regionLines.find((line) => line.section === "labor" && line.region === "East");
  if (!laborEast || laborEast.count === 609) throw new Error("labor east count was not poisoned");
  const pickerEast = home.regionTables.find((row) => row.section === "picker_scorecard" && row.region === "East");
  if (!pickerEast || pickerEast.headline === "9,352") throw new Error("picker east headline was not poisoned");
  if (!book.orders || book.orders === "905,034") throw new Error("sales orders were not poisoned");
  if (!book.items || book.items === "19,262,365") throw new Error("sales items were not poisoned");
  if (book.countBares.size < 20) throw new Error("fake-count set is too small");
  for (const bare of ["9368", "5476", "8125", "6869", "29838", "2167", "2151", "1613", "610", "392", "599", "548"]) {
    if (book.countBares.has(bare)) throw new Error(`fake count collided with row count ${bare}`);
  }

  const chromeBin = "/usr/bin/google-chrome";
  const server = await startServer(publicDir, home);
  const port = server.address().port;
  const profile = mkdtempSync(join(tmpdir(), "hb-fake-"));
  const chrome = spawn(
    chromeBin,
    [
      "--headless=new",
      "--no-sandbox",
      "--disable-gpu",
      "--disable-dev-shm-usage",
      "--no-first-run",
      "--disable-extensions",
      "--remote-debugging-port=0",
      `--user-data-dir=${profile}`,
      "about:blank",
    ],
    { stdio: "ignore" },
  );
  let client;
  try {
    const page = await waitForJson(await debugPort(profile));
    client = connect(page.webSocketDebuggerUrl);
    await client.ready;
    await client.send("Runtime.enable");
    await client.send("Page.enable");
    await assertDynacapDirect(client, port);
    const widths = [
      [1280, 800],
      [390, 844],
    ];
    for (const [width, height] of widths) {
      const url = `http://127.0.0.1:${port}/`;
      await client.send("Page.navigate", { url });
      const opened = Date.now();
      let href = "";
      while (Date.now() - opened < 15000) {
        href = await evaluate(client, "location.href");
        if (String(href).includes(String(port))) break;
        await sleep(100);
      }
      if (!String(href).includes(String(port))) {
        await evaluate(client, `location.assign(${JSON.stringify(url)})`);
        const again = Date.now();
        while (Date.now() - again < 15000) {
          href = await evaluate(client, "location.href");
          if (String(href).includes(String(port))) break;
          await sleep(100);
        }
      }
      if (!String(href).includes(String(port))) throw new Error(`browser stayed on ${href}`);
      await client.send("Emulation.setDeviceMetricsOverride", {
        width,
        height,
        deviceScaleFactor: 1,
        mobile: width < 800,
      });
      await settle(client, 90000);
      const dashboard = await visibleText(client);
      for (const marker of ["2,167", "2,151", "397", "600", "29,838", "workbook total", book.orders, book.items]) {
        if (!dashboard.toLowerCase().includes(String(marker).toLowerCase())) {
          throw new Error(`${width}px dashboard missing ${marker}`);
        }
      }
      expectChips(
        await regionPickerChips(client),
        { East: "9,368", South: "5,476", California: "8,125", West: "6,869" },
        `${width}px company`,
      );
      const yoy = await readChip(client, "YoY");
      const ord = await readChip(client, "Ord YoY");
      if (!yoy || yoy.value === "16.00%" || !yoy.label.toLowerCase().includes("workbook total")) {
        throw new Error(`${width}px company YoY ${yoy ? `${yoy.label} ${yoy.value}` : "missing"}`);
      }
      if (!ord || ord.value === "16.61%" || !ord.label.toLowerCase().includes("workbook total")) {
        throw new Error(`${width}px company Ord YoY ${ord ? `${ord.label} ${ord.value}` : "missing"}`);
      }
      if (!dashboard.toLowerCase().includes("workbook roll-up")) {
        throw new Error(`${width}px dashboard missing workbook roll-up`);
      }
      if (!dashboard.toLowerCase().includes("pph store average")) {
        throw new Error(`${width}px dashboard missing PPH store average`);
      }
      for (const [label, rowSum] of [
        ["Post Sub", "$2,944,940.00"],
        ["Refund", "$591,560.00"],
        ["Cancel", "$272,310.00"],
      ]) {
        const chip = await readChip(client, label);
        if (!chip || chip.value === rowSum || !chip.label.toLowerCase().includes("workbook total")) {
          throw new Error(`${width}px company ${label} ${chip ? `${chip.label} ${chip.value}` : "missing"}`);
        }
      }
      assertClean(dashboard, book, `${width}px dashboard`, await readTiles(client));
      await pickBrowse(client, "South");
      await showPage(client, "dashboard");
      expectChips(await regionPickerChips(client), { South: "5,476" }, `${width}px South`);
      assertClean(await visibleText(client), book, `${width}px South dashboard`, await readTiles(client));
      await pickBrowse(client, "Southern");
      await showPage(client, "dashboard");
      expectChips(await regionPickerChips(client), { Southern: "1,613" }, `${width}px Southern`);
        const southernSales = await regionNamedChip(client, "Sales");
        const southernLabor = await regionNamedChip(client, "Labor");
        if (southernSales !== "$4,351,261.96") {
          throw new Error(`${width}px Southern sales chip ${southernSales || "missing"}`);
        }
        if (southernLabor !== "-3.09%") {
          throw new Error(`${width}px Southern labor chip ${southernLabor || "missing"}`);
        }
        const southernText = await visibleText(client);
        if (southernText.includes("$14,738,247.12") || southernText.includes("-3.64%")) {
          throw new Error(`${width}px Southern still shows the South region figure`);
        }
        if (!southernText.toLowerCase().includes("labor store average")) {
          throw new Error(`${width}px Southern labor rate is unlabeled`);
        }
        const resetRow = await evaluate(
          client,
          `(() => {
            const chip = document.querySelector("#scope-chips .scope-chip");
            const reset = document.querySelector("#scope-reset .scope-reset");
            if (!chip || !reset) return "missing";
            if (document.querySelector("#scope-chips .scope-reset")) return "inside";
            const same = Math.abs(chip.getBoundingClientRect().top - reset.getBoundingClientRect().top) < 2;
            return same ? "ok" : "wrapped";
          })()`,
        );
        if (resetRow !== "ok") throw new Error(`${width}px clear chip ${resetRow}`);
        assertClean(southernText, book, `${width}px Southern dashboard`, await readTiles(client));
        await clearScope(client);
      const scopes = [
        async () => {},
        async () => pickBrowse(client, "East"),
        async () => pickBrowse(client, ""),
        async () => pickBrowse(client, ""),
        async () => searchStore(client, "0688"),
      ];
      const scopeNames = ["company", "region", "division", "district", "store"];
      for (let index = 0; index < scopes.length; index += 1) {
        if (index === 0 || index === 4) await clearScope(client);
        await scopes[index]();
        for (const id of PAGES) {
          await showPage(client, id);
          const text = await visibleText(client);
          const where = `${width}px ${scopeNames[index]} ${id}`;
          assertClean(text, book, where, await readTiles(client));
          if (index === 0 && id === "labor") {
            for (const count of [610, 392, 599, 548]) {
              if (!hasNumber(text, count)) throw new Error(`${where} missing row count ${count}`);
            }
            if (!text.includes("2 stores with no division (1708, 3197)")) {
              throw new Error(`${where} missing the no-division note`);
            }
            if (!text.includes("4 stores with source issues not scored")) {
              throw new Error(`${where} missing the source-issue note`);
            }
          }
          if (index === 0 && id === "dynacap") {
            const pcsChip = await readChip(client, "Pcs/Hr");
            const utilChip = await readChip(client, "Util");
            if (!pcsChip || pcsChip.value !== "67.8" || !pcsChip.label.toLowerCase().includes("store average")) {
              throw new Error(`${where} Pcs/Hr ${pcsChip ? `${pcsChip.label} ${pcsChip.value}` : "missing"}`);
            }
            if (pcsChip.value === "67.9") throw new Error(`${where} Pcs/Hr is the pack tile`);
            if (!utilChip || utilChip.value !== "21.81%" || !utilChip.label.toLowerCase().includes("store average")) {
              throw new Error(`${where} Util ${utilChip ? `${utilChip.label} ${utilChip.value}` : "missing"}`);
            }
            if (!text.includes("74.2")) throw new Error(`${where} missing the PPH row mean 74.2`);
            if (text.toLowerCase().includes("pph workbook")) throw new Error(`${where} still labels PPH as workbook`);
            if (!text.includes("75 stores have capacity but no Pcs/Hr")) {
              throw new Error(`${where} missing the capacity note`);
            }
          }
          if (index === 0 && id === "missing_items") {
            const rate = await readChip(client, "Rate");
            if (!rate || rate.value !== "7.55%" || !rate.label.toLowerCase().includes("store average")) {
              throw new Error(`${where} Rate ${rate ? `${rate.label} ${rate.value}` : "missing"}`);
            }
          }
          if (index === 0 && id === "schedule_quality") {
            const over = await readChip(client, "Over");
            if (!over || over.value !== "6.09%" || !over.label.toLowerCase().includes("store average")) {
              throw new Error(`${where} Over ${over ? `${over.label} ${over.value}` : "missing"}`);
            }
          }
          if (index === 0 && id === "lost_revenue") {
            const ecomm = await readChip(client, "eComm");
            if (!ecomm || !ecomm.label.toLowerCase().includes("ecomm $") || !ecomm.label.toLowerCase().includes("workbook total")) {
              throw new Error(`${where} eComm label ${ecomm ? ecomm.label : "missing"}`);
            }
          }
          if (index === 0 && id === "prep_not_ready") {
            const lower = text.toLowerCase();
            if (!lower.includes("goal target") || !lower.includes("watch target")) {
              throw new Error(`${where} prep targets are not labeled target`);
            }
            if (!text.includes("1.9%") || !text.includes("1.9–2.5%")) {
              throw new Error(`${where} prep targets are not the config values`);
            }
          }
          if (index === 1 && id === "sales") {
            if (!text.includes("499 up") || !text.includes("85 down")) {
              throw new Error(`${where} missing the East sales row sentence`);
            }
            if (text.includes("At risk")) throw new Error(`${where} sales badge contradicts the row sentence`);
          }
          if (index === 1 && id === "labor") {
            if (text.includes("At risk")) throw new Error(`${where} labor badge contradicts the chip`);
            if (!text.toLowerCase().includes("workbook roll-up")) {
              throw new Error(`${where} labor callout is not labeled workbook roll-up`);
            }
          }
          if (index === 2 && id === "labor" && !text.toLowerCase().includes("store average")) {
            throw new Error(`${where} filtered labor rate is unlabeled`);
          }
          if (index === 0 && id === "labor" && text.toLowerCase().includes("labor sch eff workbook")) {
            throw new Error(`${where} Sch Eff tile still has a Labor prefix`);
          }
          if (index === 1 && id === "picker_scorecard") {
            if (!hasNumber(text, 9368)) throw new Error(`${where} missing 9,368 shoppers`);
            if (!text.includes("612") || !text.includes("401")) throw new Error(`${where} missing watch or healthy`);
            if (hasNumber(text, 9391) || hasNumber(text, 9352)) {
              throw new Error(`${where} still shows a pack or row-length shopper count`);
            }
            if (text.includes("cooked shoppers")) throw new Error(`${where} still says cooked shoppers`);
            if (!text.toLowerCase().includes("watch") || !text.toLowerCase().includes("at risk")) {
              throw new Error(`${where} hid the filtered tiles or badge`);
            }
          }
          if (index === 0 && id === "sales" && !text.toLowerCase().includes("orders workbook total")) {
            throw new Error(`${where} missing workbook total label`);
          }
        }
      }
    }
  } finally {
    if (client) {
      try {
        client.close();
      } catch {
        /* socket already closed */
      }
    }
    chrome.kill("SIGKILL");
    server.close();
    await sleep(200);
    try {
      rmSync(profile, { recursive: true, force: true, maxRetries: 3, retryDelay: 50 });
    } catch {
      /* the profile is a temp dir */
    }
  }
}
