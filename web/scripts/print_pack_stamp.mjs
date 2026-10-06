// Print publishedAt, schemaVersion, and cookSha for every pack file.
// Exits non-zero when the files are not one cook, or the date is a retired pack.
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { packIdentityErrors } from "../check_pack.mjs";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

function jsonFiles(dir, rel = "") {
  const out = [];
  for (const name of readdirSync(join(dir, rel))) {
    const next = rel ? `${rel}/${name}` : name;
    const full = join(dir, next);
    if (statSync(full).isDirectory()) out.push(...jsonFiles(dir, next));
    else if (name.endsWith(".json")) out.push(next);
  }
  return out.sort();
}

function main() {
  const dir = resolve(process.argv[2] || "");
  if (!process.argv[2]) {
    console.error("usage: node web/scripts/print_pack_stamp.mjs <dir>");
    process.exit(2);
  }
  for (const rel of jsonFiles(dir)) {
    const value = JSON.parse(readFileSync(join(dir, rel), "utf8"));
    const schema = value.schemaVersion ?? "missing";
    const sha = value.cookSha ?? "missing";
    const published = value.publishedAt ?? "missing";
    console.log(`${rel} publishedAt=${published} schemaVersion=${schema} cookSha=${sha}`);
  }
  const errors = packIdentityErrors(dir);
  if (errors.length) {
    console.error(`refusing deploy:\n- ${errors.join("\n- ")}`);
    process.exit(1);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
