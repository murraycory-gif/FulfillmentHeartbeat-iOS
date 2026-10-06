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
4. **Settings** → **Bindings** → **Add** → **D1 database**, if the deploy did not attach it from `wrangler.toml`.
   - Variable name: `HB_AUTH`
   - Database: `fulfillment-heartbeat-auth`
   - Production and Preview both use that database
5. Pages secrets, set once and not rotated on later deploys: `SESSION_SECRET` (signs the cookie), `ADMIN_EMAIL` (the first admin's address), `SETUP_SECRET` (bearer token for the one-time `GET /setup` link). Do not put a password in the repo. Optional mail is off unless `INVITE_EMAIL` is `1` and `INVITE_EMAIL_URL` is a webhook. Copying the invite link works without mail.
6. Do **not** set `HEARTBEAT_WEB_DEV`. That flag only bypasses an old localhost check.
7. Do **not** set `AUTH_CUTOVER` until an account sign-in has been verified. Until then the shared `BASIC_PASS` login still works.
8. Do **not** add a custom domain. Leave the `*.pages.dev` hostname. Do not change DNS.
9. Do **not** attach Cloudflare Access to this hostname. A PIN in front of the HTML, or a 401 on `/api/section`, is what left every scorecard on "Sign in with the email PIN".

### 3. Cook the pack into the site

The browser loads `/data/home.json`, `/data/section/<section>.json`, `/data/presub.json`, and `/data/schedule.json`. It does not open sqlite and it does not call a public bucket host.

The seat file is `packs/seat/company/all/current.sqlite`, not a root `current.sqlite`.

```bash
python3 web/scripts/extract_web_pack.py /path/to/packs/seat/company/all/current.sqlite web/public/data
```

That writes `home.json` (summaries, region lines, and the store roster), `section/*.json`, and `presub.json`. `schedule.json` is written only when that sqlite has `schedule_pack` / `schedule_store` rows, or when `schedule-check.json` sits in the same folder as the sqlite. If neither has rows, the page still shows Action Needed, Summary, and Store Detail and does not invent stores. Copy an existing schedule pack yourself when you have one:

```bash
cp /path/to/schedule-check.json web/public/data/schedule.json
```

Do not upload `current.sqlite`. This extract is not wired into `.github/workflows/cook-heartbeat-pack.yml`.

### 4. Deploy the site (manual)

From `web/`, only when you mean to publish. `npm run build` runs the tests and stages `web/dist` (`pages_build_output_dir`), including `public/data`. This repo does not run the upload:

```bash
cd web
npm run build
npx wrangler pages deploy dist --project-name fulfillment-heartbeat-web
```

This environment has no Wrangler login. Set `CLOUDFLARE_API_TOKEN` to an account token with Cloudflare Pages Edit, then run the command. Do not pass `--project-name heartbeat-web`. That upload is the site. Re-run step 3 when the seat pack changes, then step 4. Do not deploy to `heartbeat-web.pages.dev`.

### 5. Public bucket URL — read this before you click

The web app does not use a public R2 URL. `connect-src` is `'self'`. The function will not serve a key that points at `r2.dev` or a sqlite file.

The current iPhone / iPad / Mac build still downloads packs from the public host in `PulseCloud.defaultPackHost` (`HBPackHost`, the `r2.dev` URL). Turning **public access off** on `heartbeat-packs` is what keeps the bucket off the public internet. It also stops that phone build until a later build reads through a protected origin.

Do that only when you are ready for the phone to miss packs. This change does not flip the switch and does not change the phone URL.

## Save in iCloud updates the site

Cory does not ask Bot to deploy. A launchd watcher on the Mac cooks a saved workbook and uploads the site.

What he clicks once:

1. Cloudflare dashboard → My Profile → **API Tokens** → **Create Token**. Use a custom token with **Account / Cloudflare Pages / Edit**. Copy the token into `~/.config/heartbeat/cloudflare-api-token` and run `chmod 600` on that file. Do not commit it and do not paste it into chat.
2. On the Mac, from this repo: `./Tools/HeartbeatIngest/setup-web-publish.sh`. If macOS asks for **Files and Folders** or iCloud Drive access, click **Allow**.

After that, leave these files in iCloud Drive `Heartbeat_Reports`:

- `Heartbeat Daily Report.xlsx`
- `Schedule Review Week NN - Summary.xlsx`

Saving either workbook runs `Tools/HeartbeatIngest/cook-local.sh`. That cooks the Daily Report and the Schedule Review sheet into `current.sqlite`, checks the pack, and deploys **only** to Pages project `fulfillment-heartbeat-web` (`https://fulfillment-heartbeat-web.pages.dev`). Dynacap health is the cooked band (goal 65, risk 60). The schedule title on the site uses the week from the workbook tabs. The cook does not invent metrics. If the cook or the pack check fails, the script exits and does not deploy. If neither file changed since the last successful deploy, it does nothing.

The Mac job signs in through the form and treats an unsigned `/data` response of `401` JSON `{"error":"unauthorized"}` as the lock. A UI deploy must not upload an older pack over the live one. `HEARTBEAT_UI_ONLY=1` skips the sqlite extract. Save the current pack in `web/public/data` and set `HEARTBEAT_USE_LOCAL_DATA=1`, or put the site login in `~/.config/heartbeat/web-email` and `web-password` so a newer live pack is downloaded first. A cook still passes `current.sqlite`. An older sqlite does not replace a newer pack already in `web/public/data`. After upload, `publish-web.sh` checks the unsigned `401` again.

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
