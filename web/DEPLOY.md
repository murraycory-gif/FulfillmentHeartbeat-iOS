# Heartbeat web

The site lives in this repo, in `web/`. It is not a separate repository.

Read-only Cloudflare Pages site. It mirrors the Heartbeat pages (Dashboard through Labor, including Upcoming Weeks Schedule Check), the region / division / district / OM / store filters, the Updated clock, and the new-data banner. Settings stays on the phone.

Nothing in this folder has been deployed. Do not connect this git branch to Pages auto-deploy.

## What Cory sets up

Do these in order. Free tier only: Pages, Pages Functions (Workers free), one existing R2 bucket, and Cloudflare Access email one-time PIN for 50 people or fewer. No D1, no paid add-on, no custom domain, no DNS change.

### 1. Allowlist

Edit `web/functions/allowlist.txt`. One approved email per line. Blank lines and `#` comments are ignored. An empty file denies everyone.

The same addresses go in the Access policy in step 3. This file is the origin check. Access is the door.

### 2. Pages project (direct upload)

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Upload assets** (direct upload). Do not connect GitHub. A Git connection would publish this feature branch on every push.
2. Project name: `heartbeat-web`.
3. After the first empty upload, open the project → **Settings** → **Bindings** → **Add** → **R2 bucket**.
   - Variable name: `HEARTBEAT_PACKS`
   - Bucket: the existing bucket `heartbeat-packs`
   - Do not create a new bucket. Do not turn on public access here.
4. **Settings** → **Environment variables** (Production):
   - `CF_ACCESS_TEAM_DOMAIN` = your team host, such as `your-team.cloudflareaccess.com` (no `https://`)
   - `CF_ACCESS_AUD` = the application AUD tag from step 3
5. Do **not** set `HEARTBEAT_WEB_DEV`. That flag only bypasses the gate on `localhost`.
6. Do **not** add a custom domain. Leave the `*.pages.dev` hostname. Do not change DNS.

### 3. Cloudflare Access (email PIN)

1. **Zero Trust** → **Access** → **Applications** → **Add an application** → **Self-hosted**.
2. Application domain: the Pages hostname, including `*.pages.dev` (for example `heartbeat-web.pages.dev`). Add both the apex name and a wildcard if Access asks for a path. Leave a custom domain off.
3. Identity provider: **One-time PIN**.
4. Policy: Action **Allow**. Include rule **Emails**. Paste the same addresses as `allowlist.txt`.
5. Copy the application **AUD** tag into `CF_ACCESS_AUD` (step 2) and save the Pages variable.
6. Session: the default Access session is fine. The origin still checks the JWT and the allowlist on every pack read.

Someone not on both lists gets no pack. The browser asks for an email PIN before the HTML loads, once Access is in front of the hostname.

### 4. Upload the packs (after a cook, on a Mac)

The function only reads these keys from `heartbeat-packs`. It never redirects to a public URL.

Heartbeat web pack (from the company seat sqlite, usually `packs/seat/company/all/current.sqlite`):

```bash
python3 web/scripts/extract_web_pack.py /path/to/current.sqlite ./out
cd web
npx wrangler r2 object put heartbeat-packs/web-pack/home.json --file=../out/home.json
npx wrangler r2 object put heartbeat-packs/web-pack/presub.json --file=../out/presub.json
for f in ../out/section/*.json; do
  npx wrangler r2 object put "heartbeat-packs/web-pack/section/$(basename "$f")" --file="$f"
done
```

Schedule Check is the object already cooked as `schedule-check.json` (HB-0828.492). Do not rename it. If it is not in the bucket yet:

```bash
npx wrangler r2 object put heartbeat-packs/schedule-check.json --file=/path/to/schedule-check.json
```

Do not upload `current.sqlite` for the web. The browser never receives the database. `web-pack/home.json` is the first load. A section file loads only when that page opens. `schedule-check.json` loads only on Upcoming Weeks Schedule Check.

This extract is not wired into `.github/workflows/cook-heartbeat-pack.yml`. The 2-minute cook will not publish the web pack until you run the commands above.

### 5. Deploy the site (manual)

From `web/`, after steps 2 and 3:

```bash
npx wrangler pages deploy public --project-name heartbeat-web
```

Wrangler will ask you to log in. That upload is the site. Re-run it when this folder changes. Re-run step 4 when the packs change. They are separate.

### 6. Public bucket URL — read this before you click

The web app does not use a public R2 URL. `connect-src` is `'self'`. The function will not serve a key that points at `r2.dev` or a sqlite file.

The current iPhone / iPad / Mac build still downloads packs from the public host in `PulseCloud.defaultPackHost` (`HBPackHost`, the `r2.dev` URL). Turning **public access off** on `heartbeat-packs` is what keeps the bucket off the public internet. It also stops that phone build until a later build reads through a protected origin.

Do that only when you are ready for the phone to miss packs. This change does not flip the switch and does not change the phone URL.

## What you should see

- First paint is the shell. The first network read is `/api/home`.
- Header clock matches the phone: `Updated Mon 9/28 3:10 PM`, in the browser's local zone. Missing cook time shows `Updated —`.
- Banner `New data uploaded …` only when a newer cook replaces a time already stored in this browser. The first open does not banner.
- Company cards use the cooked chrome. A filter does not replace that grade with an average. It adds `In this scope: N stores` and filters the store table.
- Prep Not Ready with thin coverage stays NO DATA, with the cooked "Only N of M stores reported" line.
- Picker shows cooked shopper counts. It does not download the shopper tape.
- Pre-Sub with no item tab says `Item detail not in this upload`.
- Schedule Check keeps Market Look under/over when the filter is company or one whole division (a blank Market Look stays blank), uses the store average inside a district / OM / store, and leaves "Not scheduled yet" gray.

## Local check (optional)

`HEARTBEAT_WEB_DEV=1` bypasses Access only when the hostname is `localhost` or `127.0.0.1`. Do not set it on Pages.

```bash
cd web && npx wrangler pages dev public
```
