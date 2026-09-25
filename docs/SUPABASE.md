# Heartbeat pack (what testers open)

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`  
Workbook bucket: `heartbeat-packs` (xlsx list/download only)

**Testers on current main download `current.sqlite` from Cloudflare R2.**
See [SQLITE.md](SQLITE.md). Cook also upserts that same thin file to this
bucket at `current.sqlite` and `packs/seat/company/all/current.sqlite`, so a
build that still reads Supabase (tip HB-0828.468) does not keep Sunday-only
Sales after an R2 publish. The same successful mirror then deletes
`facts.json` from this bucket (the Sep 12 object). Delete must return 200,
204, or 404 or the cook fails. This does not require Supabase Pro.

Upload key, first match: GitHub secret `SUPABASE_SERVICE_ROLE_KEY`, then
`SUPABASE_KEY`, then `SUPABASE_ANON_KEY`, then the publishable key the cook
already uses to read the workbook. If Storage returns 401 or 403, set
`SUPABASE_SERVICE_ROLE_KEY`. Optional `SUPABASE_URL` overrides the project URL.

They never download or parse Excel.

## Daily

1. Export `Heartbeat Daily Report.xlsx` from Power BI.
2. One time on your Mac: `./scripts/setup-r2-keychain.sh`
3. Upload the workbook. No credential exports.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"
```

The xlsx goes to the private R2 bucket `heartbeat-workbook`. Testers only get the sqlite pack from public R2.

## First-time bucket

1. Storage → New bucket → `heartbeat-packs` → Public ON.
2. Policies: SELECT + INSERT + UPDATE for `anon` / `authenticated`.
