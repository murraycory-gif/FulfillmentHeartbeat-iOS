# Heartbeat cloud

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`  
Workbook bucket: `heartbeat-packs` (xlsx only)

**Packs are not served from Supabase anymore.** Testers download
`current.sqlite` and seat packs from Cloudflare R2. See [SQLITE.md](SQLITE.md)
and [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md).

The Daily Report is still uploaded here so GitHub can cook it:

1. Export `Heartbeat Daily Report.xlsx` from Power BI.
2. `./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"`
3. GitHub cooks and publishes **company LIVE** to R2 (`current.sqlite` +
   `packs/manifest.json` + the company seat path), then seat packs.

Testers force-close Heartbeat. They never pick a file.

If `gh workflow run` is unavailable, kick the same cook with
`repository_dispatch`:

```bash
gh api repos/murraycory-gif/FulfillmentHeartbeat-iOS/dispatches \
  -f event_type=cook-heartbeat-pack
```

The hourly cron (`0 * * * *`) is a backup when the xlsx is newer than the
R2 `current.sqlite`.

## First-time workbook bucket

1. Storage → New bucket → `heartbeat-packs` → Public ON.
2. Policies: SELECT + INSERT + UPDATE for `anon` / `authenticated`.
