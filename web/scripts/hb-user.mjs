// Local only. Creates one user in a named D1 database and prints the password once.
// The site does not serve this script.
//
//   node web/scripts/hb-user.mjs create --email person@example.com --role viewer --database hb-users-preview
//
// Refuses the production database name hb-users unless HB_ALLOW_PROD=1.

import { spawn } from "node:child_process";
import { randomInt } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { PASSWORD_ALGO, PBKDF2_ITERATIONS, emailOk, hashPassword } from "../functions/accounts.js";

const ALPHABET = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";

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

async function main() {
  const command = process.argv[2];
  if (command !== "create") {
    console.error("Usage: node web/scripts/hb-user.mjs create --email EMAIL --role admin|viewer --database hb-users-preview");
    process.exit(1);
  }
  const email = String(arg("--email") || "").trim().toLowerCase();
  const role = arg("--role");
  const database = arg("--database") || "hb-users-preview";
  const local = process.argv.includes("--local");
  if (!emailOk(email)) {
    console.error("Enter a full email address.");
    process.exit(1);
  }
  if (role !== "admin" && role !== "viewer") {
    console.error("Role must be admin or viewer.");
    process.exit(1);
  }
  if (database === "hb-users" && process.env.HB_ALLOW_PROD !== "1") {
    console.error("Refusing hb-users. Pass --database hb-users-preview.");
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
  const dir = mkdtempSync(join(tmpdir(), "hb-user-"));
  const file = join(dir, "user.sql");
  try {
    writeFileSync(file, sql);
    await runWrangler(database, file, local);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "create failed");
    process.exit(1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  process.stdout.write(`email: ${email}\nrole: ${role}\npassword: ${password}\n`);
}

const invoked = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (invoked) main();
