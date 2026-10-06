// Local only. Creates one user in a named D1 database and prints the password once.
// The site does not serve this script. It calls the D1 HTTP API, not wrangler d1.
//
//   node web/scripts/hb-user.mjs create --email person@example.com --role viewer --database hb-auth-preview
//
// Refuses fulfillment-heartbeat-auth unless HB_ALLOW_PROD=1.

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { randomInt } from "node:crypto";
import { PASSWORD_ALGO, PBKDF2_ITERATIONS, emailOk, hashPassword } from "../functions/accounts.js";
import { PREVIEW_DATABASE_NAME, applyMigration, d1Query, productionBlocked } from "./d1-http.mjs";

const ALPHABET = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const root = join(dirname(fileURLToPath(import.meta.url)), "..");

export function generatePassword(length = 20) {
  const size = Math.max(16, Number(length) || 20);
  let out = "";
  for (let i = 0; i < size; i += 1) out += ALPHABET[randomInt(ALPHABET.length)];
  return out;
}

function sqlQuote(value) {
  const text = String(value);
  if (!/^[A-Za-z0-9@._+-]+$/.test(text)) throw new Error("Refusing an unsafe SQL value.");
  return `'${text}'`;
}

export function userInsertSql({ id, email, role, hash, salt, now }) {
  return `INSERT INTO users (id, email, password_hash, password_salt, password_algo, password_iterations, role, status, created_at, last_login_at) VALUES (${sqlQuote(id)}, ${sqlQuote(email)}, ${sqlQuote(hash)}, ${sqlQuote(salt)}, ${sqlQuote(PASSWORD_ALGO)}, ${Number(PBKDF2_ITERATIONS)}, ${sqlQuote(role)}, 'active', ${Number(now)}, NULL);`;
}

function arg(name) {
  const index = process.argv.indexOf(name);
  if (index < 0) return "";
  return process.argv[index + 1] || "";
}

async function main() {
  const command = process.argv[2];
  if (command !== "create") {
    console.error("Usage: node web/scripts/hb-user.mjs create --email EMAIL --role admin|viewer --database hb-auth-preview");
    process.exit(1);
  }
  const email = String(arg("--email") || "").trim().toLowerCase();
  const role = arg("--role");
  const database = arg("--database") || PREVIEW_DATABASE_NAME;
  if (!emailOk(email)) {
    console.error("Enter a full email address.");
    process.exit(1);
  }
  if (role !== "admin" && role !== "viewer") {
    console.error("Role must be admin or viewer.");
    process.exit(1);
  }
  if (productionBlocked(database)) {
    console.error("Refusing the production database. Set HB_ALLOW_PROD=1 to override.");
    process.exit(1);
  }
  const password = generatePassword(20);
  const hashed = await hashPassword(password);
  const id = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const sql = userInsertSql({ id, email, role, hash: hashed.hash, salt: hashed.salt, now });
  if (sql.includes(password)) {
    console.error("Refusing to write the password into SQL.");
    process.exit(1);
  }
  try {
    await applyMigration(database, readFileSync(join(root, "migrations/0001_accounts.sql"), "utf8"));
    await d1Query(
      database,
      "INSERT INTO users (id, email, password_hash, password_salt, password_algo, password_iterations, role, status, created_at, last_login_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?, NULL)",
      [id, email, hashed.hash, hashed.salt, PASSWORD_ALGO, PBKDF2_ITERATIONS, role, now],
    );
  } catch (error) {
    console.error(error instanceof Error ? error.message : "create failed");
    process.exit(1);
  }
  process.stdout.write(`email: ${email}\nrole: ${role}\npassword: ${password}\n`);
}

const invoked = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (invoked) main();
