// Local only. Prints a one-time setup link for the address in ADMIN_EMAIL.
// D1 stores the SHA-256 of the token. The link is written to stdout once.
// The site does not serve this script. It uses the D1 HTTP API, not wrangler d1.
// It works only while no active admin exists.
//
//   ADMIN_EMAIL=you@example.com node web/scripts/hb-setup.mjs --database hb-auth-preview --origin https://YOUR-PREVIEW.pages.dev

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { SETUP_TTL, configuredAdminEmail, issueFirstAdminLink } from "../functions/accounts.js";
import { PREVIEW_DATABASE_NAME, applyMigration, d1Query, productionBlocked } from "./d1-http.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function arg(name) {
  const index = process.argv.indexOf(name);
  if (index < 0) return "";
  return process.argv[index + 1] || "";
}

function sqlQuote(value) {
  const text = String(value);
  if (text === "") return "''";
  if (!/^[A-Za-z0-9@._+-]+$/.test(text)) throw new Error("Refusing an unsafe SQL value.");
  return `'${text}'`;
}

async function main() {
  const database = arg("--database") || PREVIEW_DATABASE_NAME;
  const origin = arg("--origin").replace(/\/$/, "");
  const email = configuredAdminEmail({ ADMIN_EMAIL: process.env.ADMIN_EMAIL });
  if (!origin || !/^https:\/\//.test(origin)) {
    console.error("Pass --origin https://your-preview-host");
    process.exit(1);
  }
  if (!email) {
    console.error("Set ADMIN_EMAIL to the first admin address.");
    process.exit(1);
  }
  if (productionBlocked(database)) {
    console.error("Refusing the production database. Set HB_ALLOW_PROD=1 to override.");
    process.exit(1);
  }
  let rows = [];
  try {
    await applyMigration(database, readFileSync(join(root, "migrations/0001_accounts.sql"), "utf8"));
    const queried = await d1Query(
      database,
      "SELECT id, email, role, status FROM users WHERE role = 'admin' OR email = ?",
      [email],
    );
    rows = (queried && queried.results) || [];
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Could not read the account database.");
    process.exit(1);
  }
  const memory = memoryDb(rows);
  const now = Math.floor(Date.now() / 1000);
  const issued = await issueFirstAdminLink(memory.db, { ADMIN_EMAIL: email }, now);
  if (!issued) {
    console.error("An admin already exists. This setup link can only create the first admin.");
    process.exit(1);
  }
  const statements = memory.sql.filter(Boolean);
  if (statements.some((statement) => statement.includes(issued.token))) {
    console.error("Refusing to store the setup token.");
    process.exit(1);
  }
  try {
    for (const statement of statements) await d1Query(database, statement);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "setup failed");
    process.exit(1);
  }
  const expires = new Date((now + SETUP_TTL) * 1000).toISOString();
  process.stdout.write(`email: ${email}\nexpires: ${expires}\nsetup: ${origin}/invite/${issued.token}\n`);
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
    return `UPDATE invites SET used_at = ${Number(params[0])} WHERE user_id = ${sqlQuote(params[1])} AND used_at IS NULL`;
  }
  if (text.startsWith("INSERT INTO users")) {
    return `INSERT INTO users (id, email, password_hash, password_salt, password_algo, password_iterations, role, status, created_at, last_login_at) VALUES (${sqlQuote(params[0])}, ${sqlQuote(params[1])}, '', '', ${sqlQuote(params[2])}, ${Number(params[3])}, 'admin', 'invited', ${Number(params[4])}, NULL)`;
  }
  if (text.startsWith("INSERT INTO invites")) {
    return `INSERT INTO invites (id, user_id, token_hash, token_enc, purpose, expires_at, used_at, created_at) VALUES (${sqlQuote(params[0])}, ${sqlQuote(params[1])}, ${sqlQuote(params[2])}, ${sqlQuote(params[3])}, ${sqlQuote(params[4])}, ${Number(params[5])}, NULL, ${Number(params[6])})`;
  }
  throw new Error("Unexpected setup statement.");
}

const invoked = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (invoked) main();
