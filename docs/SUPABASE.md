# Heartbeat pack (what testers open)

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`  
Workbook bucket: `heartbeat-packs` (xlsx list/download only)

**Packs are not served from Supabase.** Testers download `current.sqlite`
from Cloudflare R2. See [SQLITE.md](SQLITE.md). This does not require Supabase Pro.

Testers download **`current.sqlite`** and, after Continue,
**`packs/seat/{grain}/{id}/current.sqlite`** from the R2 pack host.
They never download or parse Excel. See [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md).

## Daily

1. Export `Heartbeat Daily Report.xlsx` from Power BI.
2. Upload it and kick GitHub cook (no Mac, no iPad):

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"
```

`ingest-heartbeat.sh` upserts the xlsx on Supabase, then `gh workflow run cook-heartbeat-pack.yml`.
Actions downloads that workbook, cooks, and publishes **company LIVE to R2**
(`current.sqlite`, `packs/manifest.json`, and the company seat path), then
uploads seat packs to the same R2 host. Testers force-close Heartbeat. They never pick a file.

If `gh workflow run` is unavailable, kick the same cook with
`repository_dispatch`:

```bash
gh api repos/murraycory-gif/FulfillmentHeartbeat-iOS/dispatches \
  -f event_type=cook-heartbeat-pack
```

The 15-minute cron is a backup when the xlsx is newer than `current.sqlite`.

## Storage file size

Sqlite packs publish to Cloudflare R2, not Supabase. The ~50MB Supabase object
cap does not apply to `current.sqlite`. The Daily Report workbook stays in the
Supabase bucket.

## First-time bucket

1. Storage → New bucket → `heartbeat-packs` → Public ON.
2. Policies: SELECT + INSERT + UPDATE for `anon` / `authenticated`.
3. Storage → Settings → Global file size limit → **60 MB+** (see above).
