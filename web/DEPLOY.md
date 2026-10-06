# Heartbeat web

The site lives in this repo, in `web/`. It is not a separate repository.

Read-only Cloudflare Pages site. It mirrors the Heartbeat pages (Dashboard through Labor, including Upcoming Weeks Schedule Check), the region / division / district / OM / store filters, the Updated clock, and the new-data banner. Settings stays on the phone.

Do not connect this git branch to Pages auto-deploy.

`https://heartbeat-web.pages.dev/` is an unrelated site. Do not deploy this shell there. Do not pass `--project-name heartbeat-web`. The Pages project for this shell is `fulfillment-heartbeat-web`, and only after you create that project yourself.

Build the shell locally. This does not upload anything:

```bash
cd web
npm run build
```

That writes `web/dist/` (`pages_build_output_dir`). Functions stay in `web/functions`.

## What Cory sets up

Do these in order. Pages, the existing R2 bucket, and one D1 database for accounts. No Access PIN, no paid add-on, no custom domain, no DNS change.

### 1. Allowlist

`web/functions/allowlist.txt` is unused by the pack routes. Scorecard pages read cooked JSON from the site itself. They do not stop on an email PIN. Do not put Access in front of `fulfillment-heartbeat-web.pages.dev` if you want those pages to open.

### 2. Pages project (direct upload)

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Upload assets** (direct upload). Do not connect GitHub. A Git connection would publish this feature branch on every push.
2. Project name: `fulfillment-heartbeat-web`. Do not reuse `heartbeat-web`. That name is the unrelated `heartbeat-web.pages.dev` site.
3. After the first empty upload, open the project → **Settings** → **Bindings** → **Add** → **R2 bucket**.
   - Variable name: `HEARTBEAT_PACKS`
   - Bucket: the existing bucket `heartbeat-packs`
   - Do not create a new bucket. Do not turn on public access here.
4. **Settings** → **Bindings** → **Add** → **D1 database**. Production and Preview are separate databases. The binding name is `HB_AUTH` in both environments. Repeat `HEARTBEAT_PACKS` in both environments too. An env block that omits R2 drops the pack bucket.
   - Production variable name: `HB_AUTH`. Database name: `fulfillment-heartbeat-auth`. Database id: `646c017a-802f-4395-b635-d4b5bd66c1cb`.
   - Preview variable name: `HB_AUTH`. Database name: `hb-auth-preview`. Database id: `291dfe6d-fcc1-4b15-90c7-768db26d1f8e`.
   - Those ids are already in `web/wrangler.toml`. Preview must stay on `291dfe6d`. Do not point Preview at `646c017a`.
   - `web/migrations/0001_accounts.sql` adds columns to the tables already in that database. It does not seed a user or a password. The function applies the same statements on the first request. To apply them yourself, use the dashboard console or the D1 HTTP API below. Do not use `wrangler d1` for this; the account token has no D1 permission.
5. Pages secrets: `BASIC_USER`, `BASIC_PASS`, `BASIC_PASS_TESTER`, `SESSION_SECRET`, `SETUP_SECRET`, and `ADMIN_EMAIL`. Do not put a password in the repo. `ADMIN_EMAIL` is the first admin address. Leave `AUTH_CUTOVER` unset until an account sign-in has been verified. The shared password is a viewer and cannot open user management.
6. Do **not** set `HEARTBEAT_WEB_DEV`. That flag only bypasses an old localhost check.
7. Do **not** set `AUTH_CUTOVER` until an account sign-in has been verified. Until then the shared `BASIC_PASS` login still works, as a viewer.
8. Do **not** add a custom domain. Leave the `*.pages.dev` hostname. Do not change DNS.
9. Do **not** attach Cloudflare Access to this hostname. A PIN in front of the HTML, or a 401 on `/api/section`, is what left every scorecard on "Sign in with the email PIN".

The databases already exist. Apply `web/migrations/0001_accounts.sql` to preview (`291dfe6d-fcc1-4b15-90c7-768db26d1f8e`) from the dashboard: **D1** → **hb-auth-preview** → **Console**, one statement at a time. `ALTER` errors that say the column already exists mean that statement is done. The same console on `fulfillment-heartbeat-auth` is production; leave it until preview sign-in works. The Pages function also runs those statements on the first request.

The HTTP API is the other path. Set `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`. One statement per request:

```bash
curl -sS -X POST "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/d1/database/291dfe6d-fcc1-4b15-90c7-768db26d1f8e/query" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"sql":"ALTER TABLE users ADD COLUMN password_algo TEXT NOT NULL DEFAULT '\''PBKDF2-SHA256'\''"}'
```

Mint the first admin on the preview database only. Both commands run on your machine and use that HTTP API. The site does not serve them.

```bash
ADMIN_EMAIL=you@example.com node admin-scripts/hb-setup.mjs --database hb-auth-preview --origin https://YOUR-PREVIEW.pages.dev
node admin-scripts/hb-user.mjs create --email qc-viewer@example.com --role viewer --database hb-auth-preview
node admin-scripts/hb-user.mjs create --email qc-admin@example.com --role admin --database hb-auth-preview
```

`hb-setup.mjs` prints a one-time link for `ADMIN_EMAIL` to stdout. It expires in 24 hours, works once, and only while no active admin exists. `hb-user.mjs` prints a random password once. Neither command writes the secret into the repo. `fulfillment-heartbeat-auth` and database id `646c017a-802f-4395-b635-d4b5bd66c1cb` are production; both scripts refuse them unless `HB_ALLOW_PROD=1`.

Preview deploy, from `web/`:

```bash
npx wrangler pages deploy dist --project-name fulfillment-heartbeat-web --branch cursor/user-accounts-93a9
```

That is a branch deployment. Do not omit `--branch`. Do not deploy production from this change. Preview's `HB_AUTH` binding stays on `291dfe6d-fcc1-4b15-90c7-768db26d1f8e`.

### 3. Cook the pack into the site

The browser loads `/data/home.json`, `/data/section/<section>.json`, `/data/presub.json`, and `/data/schedule.json`. It does not open sqlite and it does not call a public bucket host.

The seat file is `packs/seat/company/all/current.sqlite`, not a root `current.sqlite`.

```bash
python3 web/scripts/extract_web_pack.py /path/to/packs/seat/company/all/current.sqlite web/public/data
```

That writes `home.json` (summaries, region lines, the store roster, and `metadata.schemaVersion` plus `metadata.cookSha`), `section/*.json`, and `presub.json`. `cookSha` is the git SHA of the cook. Before upload, the required-keys check has to pass:

```bash
node web/check_pack.mjs web/public/data
```

A non-zero exit refuses the pack. `publish-web.sh` runs that check. The page warns when the loaded `schemaVersion` is older than the page expects. `schedule.json` is written only when that sqlite has `schedule_pack` / `schedule_store` rows, or when `schedule-check.json` sits in the same folder as the sqlite. If neither has rows, the page still shows Action Needed, Summary, and Store Detail and does not invent stores. Copy an existing schedule pack yourself when you have one:

```bash
cp /path/to/schedule-check.json web/public/data/schedule.json
```

Do not upload `current.sqlite`. This extract is not wired into `.github/workflows/cook-heartbeat-pack.yml`.

### 4. Deploy the site (manual)

`npm test` needs Node >= 22.5 because the tests use `node:sqlite`. An older Node fails in `web/scripts/require-node.mjs` before the suite starts.

From `web/`, only when you mean to publish. `npm run build` runs the tests and stages `web/dist` (`pages_build_output_dir`), including `public/data`. This repo does not run the upload:

```bash
cd web
npm run build
npx wrangler pages deploy dist --project-name fulfillment-heartbeat-web
```

This environment has no Wrangler login. Set `CLOUDFLARE_API_TOKEN` to an account token with Cloudflare Pages Edit, then run the command. Do not pass `--project-name heartbeat-web`. That upload is the site. Re-run step 3 when the seat pack changes, then step 4. Do not deploy to `heartbeat-web.pages.dev`.

### 5. Public bucket URL — read this before you click

The web app does not use a public R2 URL. `connect-src` is `'self'`. The function will not serve a key that points at a public bucket host or a sqlite file. `heartbeat-packs` has no custom domain. Its managed public hostname stays disabled. Pages reads the bucket only through the `HEARTBEAT_PACKS` binding, inside `_middleware.js`, after the session check. `/data` and `/api` responses send `Cache-Control: private, no-store`. A pack whose `schemaVersion` or required keys fail `guardHome` is not served; the function uses `current.json` `previous`, then the static files from the last full Pages deploy.

The current iPhone / iPad / Mac build still downloads packs from the public host in `PulseCloud.defaultPackHost` (`HBPackHost`, the `r2.dev` URL). Turning **public access off** on `heartbeat-packs` is what keeps the bucket off the public internet. It also stops that phone build until a later build reads through a protected origin.

Do that only when you are ready for the phone to miss packs. This change does not flip the switch and does not change the phone URL.

## Data-only refresh (R2)

A Pages upload always ships the Functions bundle. The Mac must not create a Pages deployment when the only change is the pack. It uploads JSON to R2. The Pages Function reads that pack after sign-in. An unsigned `/data` request stays `401` `{"error":"unauthorized"}` with `Cache-Control: private, no-store`.

Binding name: `HEARTBEAT_PACKS`  
Bucket name: `heartbeat-packs`

Key layout:

```text
web-pack/current.json
  {
    "prefix": "web-pack/<cookSha>-<publishedAt>",
    "cookSha": "<40-hex cookSha>",
    "publishedAt": "<publishedAt>",
    "schemaVersion": 1,
    "previous": { "prefix": "...", "cookSha": "...", "publishedAt": "...", "schemaVersion": 1 }
  }

web-pack/<cookSha>-<publishedAt>/home.json
web-pack/<cookSha>-<publishedAt>/schedule.json
web-pack/<cookSha>-<publishedAt>/presub.json
web-pack/<cookSha>-<publishedAt>/section/<section>.json
```

`cookSha` is `metadata.cookSha` in `home.json`. The object paths under `web-pack/<cookSha>-<publishedAt>/` match the paths under `/data/`.

The function reads `current.json` only. It does not read a bare `web-pack/home.json` key. A September 2026 object at that key was an older pack with no `schemaVersion`, and serving it made `home.json` disagree with `schedule.json`. Each served file's `schemaVersion` and `cookSha` have to match the pointer entry, and `home.json` has to pass `guardHome` in `web/functions/pack-store.js` (`schemaVersion`, `cookSha`, `laborMarket`, `regionTables`, `summaries`, `companyTiles`, `filters.stores`). If the current prefix fails, the function serves `previous` and leaves the pointer object unchanged. If neither pack is valid, or the bucket has no pointer yet, `/data/*` falls through to the static files from the last full Pages deploy. Those static files are still behind the sign-in middleware. `/api/*` uses the same guarded pack and does not fall through to a bare bucket key. An unsigned `/api` request is `401`, the same as `/data`.

Every JSON file in one cook carries the same top-level `publishedAt`, `schemaVersion`, and `cookSha`. `publish-web.sh` prints those three fields for each file and refuses a deploy when they disagree, or when `publishedAt` is `2026-09-29` or `2026-09-30`.

Upload with an API token that has **Account → Workers R2 Storage → Edit** on `heartbeat-packs`. Do not grant **Cloudflare Pages → Edit**. Then this token cannot create a Pages deployment.

From the repo, after `node web/check_pack.mjs web/public/data` exits 0:

```bash
# HEARTBEAT_DATA_ONLY=1 never runs `wrangler pages deploy`.
HEARTBEAT_DATA_ONLY=1 bash Tools/HeartbeatIngest/publish-web.sh
```

That command puts every pack JSON at `web-pack/<cookSha>-<publishedAt>/`, downloads that set, and runs `check_pack` on it. It writes `web-pack/current.json` last. `previous` becomes the prior pointer entry. A pack that fails `check_pack` does not move the pointer. A served file whose `schemaVersion` or `cookSha` disagrees with the pointer does not replace the last good entry. When `~/.config/heartbeat/web-email` and `web-password` are present, the data-only upload signs in and reads every `/data` JSON file back.

A one-file upload, if you are not using the script:

```bash
SHA="$(python3 -c 'import json; print(json.load(open("web/public/data/home.json"))["metadata"]["cookSha"])')"
PUBLISHED="$(python3 -c 'import json; print(json.load(open("web/public/data/home.json"))["publishedAt"])')"
npx wrangler r2 object put "heartbeat-packs/web-pack/${SHA}-${PUBLISHED}/home.json" \
  --file=web/public/data/home.json --remote
# repeat for schedule.json, presub.json, and section/*.json
# run check_pack on the uploaded set
# write current.json only after that check passes
```

Do not run `wrangler pages deploy` for a pack refresh.

## Save in iCloud updates the site

Cory does not ask Bot to deploy. A launchd watcher on the Mac cooks a saved workbook and uploads the site.

What he clicks once:

1. Cloudflare dashboard → My Profile → **API Tokens** → **Create Token**. Use a custom token with **Account / Workers R2 Storage / Edit** on bucket `heartbeat-packs`. Do not grant Cloudflare Pages Edit on the Mac token. Copy the token into `~/.config/heartbeat/cloudflare-api-token` and run `chmod 600` on that file. Do not commit it and do not paste it into chat.
2. On the Mac, from this repo: `./Tools/HeartbeatIngest/setup-web-publish.sh`. If macOS asks for **Files and Folders** or iCloud Drive access, click **Allow**.

After that, leave these files in iCloud Drive `Heartbeat_Reports`:

- `Heartbeat Daily Report.xlsx`
- `Schedule Review Week NN - Summary.xlsx`

Saving either workbook runs `Tools/HeartbeatIngest/cook-local.sh`. That cooks the Daily Report and the Schedule Review sheet into `current.sqlite`, checks the pack, and uploads **only** the JSON pack to R2 bucket `heartbeat-packs` for Pages project `fulfillment-heartbeat-web` (`https://fulfillment-heartbeat-web.pages.dev`). It does not create a Pages deployment. Dynacap health is the cooked band (goal 65, risk 60). The schedule title on the site uses the week from the workbook tabs. The cook does not invent metrics. If the cook or the pack check fails, the script exits and does not upload. If neither file changed since the last successful upload, it does nothing.

The Mac job signs in through the form and treats an unsigned `/data` response of `401` JSON `{"error":"unauthorized"}` as the lock. A UI deploy must not upload an older pack over the live one. `HEARTBEAT_UI_ONLY=1` skips the sqlite extract. Save the current pack in `web/public/data` and set `HEARTBEAT_USE_LOCAL_DATA=1`, or put the site login in `~/.config/heartbeat/web-email` and `web-password` so a newer live pack is downloaded first. A cook still passes `current.sqlite`. An older sqlite does not replace a newer pack already in `web/public/data`. After upload, `publish-web.sh` checks the unsigned `401` again. When `~/.config/heartbeat/web-email` and `web-password` are present, it signs in and reads every `/data` JSON file back, and exits if `publishedAt`, `schemaVersion`, or `cookSha` differs from the files just uploaded.

The token is read from `CLOUDFLARE_API_TOKEN` or `~/.config/heartbeat/cloudflare-api-token`. launchd does not need the token in the plist.

## What you should see

- First paint is the shell. The first network read is `/data/home.json`.
- Loss shows the pack dollar. 5 Star, Pick Path, Dynacap, Schedule Quality, Picker, and Labor show their cooked headlines.
- East Region limits the seat table to East. District, OM, and Store list the roster from the seat pack.
- Scorecard pages open on `/data/section/...` without an email PIN. Updated uses the pack time.
- Header clock matches the phone: `Updated Mon 9/28 3:10 PM`, in the browser's local zone. Missing cook time shows `Updated —`.
- Banner `New data uploaded …` only when a newer cook replaces a time already stored in this browser. The first open does not banner.
- Company cards use the cooked chrome. A filter does not replace that grade with an average. It adds `In this scope: N stores` and filters the store table.
- Prep Not Ready with thin coverage stays NO DATA, with the cooked "Only N of M stores reported" line.
- Picker shows cooked shopper counts. It does not download the shopper tape.
- Pre-Sub with no item tab says `Item detail not in this upload`.
- Schedule Check keeps Market Look under/over when the filter is company or one whole division (a blank Market Look stays blank), uses the store average inside a district / OM / store, and leaves "Not scheduled yet" gray.

## Local check (optional)

Serve `web/public` after the extract. Do not set `HEARTBEAT_WEB_DEV` on Pages.

```bash
cd web/public && python3 -m http.server 8765
```
