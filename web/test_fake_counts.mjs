// Architecture's fake-count lab. Every home.json count is rewritten to
// 900000000 + the original. The pages must keep painting section-row counts.
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, normalize } from "node:path";

const POISON = 900_000_000;
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
const COUNT_KEYS = new Set(["count", "storeCount", "shoppers", "healthy", "watch", "risk", "stores"]);

function remember(fakes, number) {
  const value = POISON + Math.round(Math.abs(Number(number)));
  fakes.add(String(value));
  fakes.add(value.toLocaleString("en-US"));
  return value;
}

export function poisonHome(home) {
  const copy = structuredClone(home);
  const fakes = new Set();
  const walk = (node) => {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    for (const [key, value] of Object.entries(node)) {
      if (typeof value === "number" && Number.isFinite(value) && COUNT_KEYS.has(key)) {
        node[key] = remember(fakes, value);
      } else if (key === "value" && typeof value === "string" && /^\d[\d,]* shoppers$/.test(value.trim())) {
        node[key] = `${remember(fakes, Number(value.replace(/[^\d]/g, ""))).toLocaleString("en-US")} shoppers`;
      } else if (value && typeof value === "object") {
        walk(value);
      }
    }
  };
  walk(copy);
  for (const summary of copy.summaries || []) {
    if (summary.section !== "picker_scorecard") continue;
    if (typeof summary.headline === "number") summary.headline = remember(fakes, summary.headline);
    if (typeof summary.secondary === "string") {
      summary.secondary = summary.secondary.replace(/\d[\d,]*/g, (token) =>
        remember(fakes, Number(token.replace(/,/g, ""))).toLocaleString("en-US"),
      );
    }
  }
  for (const tile of Object.values(copy.companyTiles || {})) {
    const labels = tile.labels || [];
    const values = tile.values || [];
    labels.forEach((label, index) => {
      if (label === "Orders" || label === "Items") return;
      const raw = String(values[index] ?? "").trim();
      if (!/^[\d,]+$/.test(raw)) return;
      values[index] = remember(fakes, Number(raw.replace(/,/g, ""))).toLocaleString("en-US");
    });
  }
  return { home: copy, fakes };
}

function fakeHits(text, fakes) {
  const hits = [];
  const seen = new Set();
  const re = /\d[\d,]*/g;
  let match;
  while ((match = re.exec(text))) {
    const token = match[0];
    const bare = token.replace(/,/g, "");
    if ((fakes.has(token) || fakes.has(bare)) && !seen.has(bare)) {
      seen.add(bare);
      hits.push(token);
    }
  }
  return hits;
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

function assertClean(text, fakes, where) {
  const hits = fakeHits(text, fakes);
  if (hits.length) {
    throw new Error(`${where} rendered fake count ${hits.slice(0, 6).join(", ")}`);
  }
}

export async function runFakeCountLab(publicDir) {
  const original = JSON.parse(readFileSync(join(publicDir, "data/home.json"), "utf8"));
  const { home, fakes } = poisonHome(original);
  const laborEast = home.regionLines.find((line) => line.section === "labor" && line.region === "East");
  if (!laborEast || laborEast.count === 609) throw new Error("labor east count was not poisoned");
  const orders = home.companyTiles.sales.values[home.companyTiles.sales.labels.indexOf("Orders")];
  if (orders !== "905,034") throw new Error("sales orders workbook total was poisoned");
  if (fakes.size < 20) throw new Error("fake-count set is too small");

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
      for (const marker of ["2,167", "2,151", "397", "600", "29,838", "workbook total", "905,034", "19,262,365"]) {
        if (!dashboard.toLowerCase().includes(marker.toLowerCase())) {
          throw new Error(`${width}px dashboard missing ${marker}`);
        }
      }
      assertClean(dashboard, fakes, `${width}px dashboard`);
      const scopes = [
        async () => {},
        async () => pickBrowse(client, "East"),
        async () => pickBrowse(client, ""),
        async () => pickBrowse(client, ""),
        async () => pickBrowse(client, ""),
      ];
      const scopeNames = ["company", "region", "division", "district", "store"];
      for (let index = 0; index < scopes.length; index += 1) {
        if (index === 0) await clearScope(client);
        await scopes[index]();
        for (const id of PAGES) {
          await showPage(client, id);
          const text = await visibleText(client);
          const where = `${width}px ${scopeNames[index]} ${id}`;
          assertClean(text, fakes, where);
          if (index === 0 && id === "labor") {
            for (const count of [610, 392, 599, 548]) {
              if (!hasNumber(text, count)) throw new Error(`${where} missing row count ${count}`);
            }
          }
          if (index === 1 && id === "picker_scorecard") {
            if (!hasNumber(text, 9368)) throw new Error(`${where} missing 9,368 shoppers`);
            if (hasNumber(text, 9391) || hasNumber(text, 9352)) {
              throw new Error(`${where} still shows a pack or row-length shopper count`);
            }
            if (text.includes("cooked shoppers")) throw new Error(`${where} still says cooked shoppers`);
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
