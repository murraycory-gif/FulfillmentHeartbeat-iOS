// Local only. Prints a one-time setup link for murraycory@icloud.com.
// D1 stores the SHA-256 of the token. The link is written to stdout once.
// The site does not serve this script. It works only while no active admin exists.
//
//   node web/scripts/hb-setup.mjs --database hb-users-preview --origin https://YOUR-PREVIEW.pages.dev

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { FIRST_ADMIN_EMAIL, SETUP_TTL, issueFirstAdminLink } from "../functions/accounts.js";

function arg(name) {
  const index = process.argv.indexOf(name);
  if (index < 0) return "";
  return process.argv[index + 1] || "";
}

function sqlQuote(value) {
  const text = String(value);
  if (!/^[A-Za-z0-9@._+-]+$/.test(text)) throw new Error("Refusing an unsafe SQL value.");
  return `'${text}'`;
}

function runWrangler(database, file, local) {
  const args = ["wrangler", "d1", "execute", database, local ? "--local" : "--remote", `--file=${file}`];
  return new Promise((resolve, reject) => {
    const child = spawn("npx", args, { cwd: join(fileURLToPath(import.meta.url), "..", ".."), stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.stdout.on("data", () => {});
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || `wrangler exited ${code}`));
    });
  });
}

async function query(database, sql, local) {
  const args = ["wrangler", "d1", "execute", database, local ? "--local" : "--remote", "--json", `--command=${sql}`];
  return new Promise((resolve, reject) => {
    const child = spawn("npx", args, { cwd: join(fileURLToPath(import.meta.url), "..", ".."), stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(stderr.trim() || `wrangler exited ${code}`));
      else resolve(stdout);
    });
  });
}

async function main() {
  const database = arg("--database") || "hb-users-preview";
  const origin = arg("--origin").replace(/\/$/, "");
  const local = process.argv.includes("--local");
  if (!origin || !/^https:\/\//.test(origin)) {
    console.error("Pass --origin https://your-preview-host");
    process.exit(1);
  }
  if (database === "hb-users" && process.env.HB_ALLOW_PROD !== "1") {
    console.error("Refusing hb-users. Pass --database hb-users-preview.");
    process.exit(1);
  }
  const raw = await query(
    database,
    "SELECT id, email, role, status FROM users WHERE role = 'admin' OR email = 'murraycory@icloud.com'",
    local,
  );
  let rows = [];
  try {
    const parsed = JSON.parse(raw);
    const first = Array.isArray(parsed) ? parsed[0] : parsed;
    rows = (first && first.results) || [];
  } catch {
    console.error("Could not read the account database.");
    process.exit(1);
  }
  const memory = memoryDb(rows);
  const now = Math.floor(Date.now() / 1000);
  const issued = await issueFirstAdminLink(memory.db, now);
  if (!issued) {
    console.error("An admin already exists. This setup link can only create the first admin.");
    process.exit(1);
  }
  const statements = memory.sql.filter(Boolean).join("\n");
  if (statements.includes(issued.token)) {
    console.error("Refusing to store the setup token.");
    process.exit(1);
  }
  const dir = mkdtempSync(join(tmpdir(), "hb-setup-"));
  const file = join(dir, "setup.sql");
  try {
    writeFileSync(file, statements);
    await runWrangler(database, file, local);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "setup failed");
    process.exit(1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  const expires = new Date((now + SETUP_TTL) * 1000).toISOString();
  process.stdout.write(`email: ${FIRST_ADMIN_EMAIL}\nexpires: ${expires}\nsetup: ${origin}/invite/${issued.token}\n`);
}

function memoryDb(rows) {
  const sql = [];
  const users = rows.map((row) => ({ ...row }));
  const db = {
    prepare(text) {
      const statement = {
        bind(...params) {
          return {
            first: async () => first(text, params, users),
            run: async () => {
              sql.push(compile(text, params));
              apply(text, params, users);
              return { success: true, meta: { changes: 1 } };
            },
            all: async () => ({ results: [] }),
          };
        },
      };
      return statement;
    },
  };
  return { db, sql };
}

function first(text, params, users) {
  if (text.includes("role = 'admin' AND status = 'active'")) {
    return users.find((user) => user.role === "admin" && user.status === "active") || null;
  }
  if (text.includes("role = 'admin' AND email != ?")) {
    return users.find((user) => user.role === "admin" && user.email !== params[0]) || null;
  }
  if (text.includes("FROM users WHERE email = ?")) {
    return users.find((user) => user.email === params[0]) || null;
  }
  return null;
}

function apply(text, params, users) {
  if (text.startsWith("INSERT INTO users")) {
    users.push({ id: params[0], email: params[1], role: "admin", status: "invited" });
  }
}

function compile(text, params) {
  if (text.startsWith("UPDATE invites SET used_at")) {
    return `UPDATE invites SET used_at = ${Number(params[0])} WHERE user_id = ${sqlQuote(params[1])} AND used_at IS NULL;`;
  }
  if (text.startsWith("INSERT INTO users")) {
    return `INSERT INTO users (id, email, password_hash, password_salt, password_algo, password_iterations, role, status, created_at, last_login_at) VALUES (${sqlQuote(params[0])}, ${sqlQuote(params[1])}, '', '', ${sqlQuote(params[2])}, ${Number(params[3])}, 'admin', 'invited', ${Number(params[4])}, NULL);`;
  }
  if (text.startsWith("INSERT INTO invites")) {
    return `INSERT INTO invites (id, user_id, token_hash, purpose, expires_at, used_at, created_at) VALUES (${sqlQuote(params[0])}, ${sqlQuote(params[1])}, ${sqlQuote(params[2])}, ${sqlQuote(params[3])}, ${Number(params[4])}, NULL, ${Number(params[5])});`;
  }
  throw new Error("Unexpected setup statement.");
}

const invoked = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (invoked) main();
