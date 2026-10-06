import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// The Mac checkout owns these files. Leave them alone; they may still name a public host.
const allow = new Set([
  "Tools/HeartbeatIngest/pack_freshness.py",
  "Tools/HeartbeatIngest/test_pack_freshness.py",
]);

const needle = Buffer.from(["r2", "dev"].join("."));

export function assertNoPublicR2(repoRoot) {
  const listed = spawnSync("git", ["ls-files", "-z"], { cwd: repoRoot, encoding: "buffer" });
  assert.equal(listed.status, 0, listed.stderr?.toString() || "git ls-files failed");
  const files = listed.stdout.toString("utf8").split("\0").filter(Boolean);
  const hits = [];
  for (const rel of files) {
    if (allow.has(rel)) continue;
    const data = readFileSync(join(repoRoot, rel));
    let from = 0;
    while (true) {
      const at = data.indexOf(needle, from);
      if (at < 0) break;
      const line = data.subarray(0, at).toString("utf8").split("\n").length;
      hits.push(`${rel}:${line}`);
      from = at + needle.length;
    }
  }
  assert.deepEqual(hits, []);
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  assertNoPublicR2(join(dirname(fileURLToPath(import.meta.url)), "../.."));
}
