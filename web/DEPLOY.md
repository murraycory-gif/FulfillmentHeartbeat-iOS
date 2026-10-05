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

Do these in order. Free tier only: Pages and one existing R2 bucket binding. No Access PIN, no D1, no paid add-on, no custom domain, no DNS change.

### 1. Allowlist

`web/functions/allowlist.txt` is unused by the pack routes. Scorecard pages read cooked JSON from the site itself. They do not stop on an email PIN. Do not put Access in front of `fulfillment-heartbeat-web.pages.dev` if you want those pages to open.

### 2. Pages project (direct upload)

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Upload assets** (direct upload). Do not connect GitHub. A Git connection would publish this feature branch on every push.
2. Project name: `fulfillment-heartbeat-web`. Do not reuse `heartbeat-web`. That name is the unrelated `heartbeat-web.pages.dev` site.
3. After the first empty upload, open the project → **Settings** → **Bindings** → **Add** → **R2 bucket**.
   - Variable name: `HEARTBEAT_PACKS`
   - Bucket: the existing bucket `heartbeat-packs`
   - Do not create a new bucket. Do not turn on public access here.
4. Do **not** set `HEARTBEAT_WEB_DEV`. That flag only bypasses an old localhost check.
5. Do **not** add a custom domain. Leave the `*.pages.dev` hostname. Do not change DNS.
6. Do **not** attach Cloudflare Access to this hostname. A PIN in front of the HTML, or a 401 on `/api/section`, is what left every scorecard on "Sign in with the email PIN".

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
