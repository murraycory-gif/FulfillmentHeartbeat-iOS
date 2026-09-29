// Stage the Pages shell into web/dist. Does not deploy and does not
// contact Cloudflare. Functions stay in web/functions, beside this output.
import { cpSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const web = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(web, "dist");
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
cpSync(join(web, "public"), dist, { recursive: true });
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
