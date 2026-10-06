// Stage the Pages shell into web/dist. Does not deploy and does not
// contact Cloudflare. Functions stay in web/functions, beside this output.
import { execSync } from "node:child_process";
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const web = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(web, "dist");
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
cpSync(join(web, "public"), dist, { recursive: true });
// Build-label only. The short sha replaces __BUILD_SHA__ in the staged app.js
// so the drawer can name this commit. It does not change pack data.
const buildSha = execSync("git rev-parse --short=7 HEAD", { cwd: web, encoding: "utf8" }).trim();
const stagedApp = join(dist, "app.js");
writeFileSync(stagedApp, readFileSync(stagedApp, "utf8").replaceAll("__BUILD_SHA__", buildSha));
writeFileSync(
  join(dist, "BUILD.txt"),
  [
    "Fulfillment Heartbeat web shell",
    "project: fulfillment-heartbeat-web",
    "deploy: not run",
    "pages.dev: do not upload to heartbeat-web.pages.dev",
    "",
  ].join("\n"),
);
console.log(`staged ${dist}`);
