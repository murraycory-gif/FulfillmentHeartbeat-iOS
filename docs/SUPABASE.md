# Heartbeat pack (what testers open)

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`  
Workbook bucket: `heartbeat-packs` (xlsx list/download only)

**Testers on current main download `current.sqlite` from Cloudflare R2.**
See [SQLITE.md](SQLITE.md). Cook also upserts that same thin file to this
bucket at `current.sqlite` and `packs/seat/company/all/current.sqlite`, so a
build that still reads Supabase (tip HB-0828.468) does not keep Sunday-only
Sales after an R2 publish. This does not require Supabase Pro.

Upload key, first match: GitHub secret `SUPABASE_SERVICE_ROLE_KEY`, then
`SUPABASE_KEY`, then `SUPABASE_ANON_KEY`, then the publishable key the cook
already uses to read the workbook. If Storage returns 401 or 403, set
`SUPABASE_SERVICE_ROLE_KEY`. Optional `SUPABASE_URL` overrides the project URL.

They never download or parse Excel.

## Daily

1. Export `Heartbeat Daily Report.xlsx` from Power BI.
2. Open Heartbeat on *your* iPad once if this is a new file week (only you).
3. Publish the pack:

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./build-pack.sh "/path/Heartbeat Daily Report.xlsx"
```

The xlsx is archived in the bucket. Testers only get the sqlite pack.

## First-time bucket

1. Storage → New bucket → `heartbeat-packs` → Public ON.
2. Policies: SELECT + INSERT + UPDATE for `anon` / `authenticated`.
