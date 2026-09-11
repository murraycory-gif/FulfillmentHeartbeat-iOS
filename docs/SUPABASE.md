# Heartbeat pack (what testers open)

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`  
Bucket: `heartbeat-packs`

Testers download **`current.sqlite`** (Who’s looking / Clear) and, after
Continue, **`packs/seat/{grain}/{id}/current.sqlite`**.  
They never download or parse Excel. See [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md).

## Daily

1. Export `Heartbeat Daily Report.xlsx` from Power BI.
2. Upload it and kick GitHub cook (no Mac, no iPad):

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"
```

`ingest-heartbeat.sh` upserts the xlsx, then `gh workflow run cook-heartbeat-pack.yml`.
Actions downloads the authenticated object, cooks, publishes **company LIVE**
(`current.sqlite` + `packs/manifest.json` + company seat), then uploads seats
in parallel. Testers force-close Heartbeat. They never pick a file.

If `gh workflow run` is unavailable, kick the same cook with
`repository_dispatch`:

```bash
gh api repos/murraycory-gif/FulfillmentHeartbeat-iOS/dispatches \
  -f event_type=cook-heartbeat-pack
```

The 15-minute cron is a backup when the xlsx is newer than `current.sqlite`.

## First-time bucket

1. Storage → New bucket → `heartbeat-packs` → Public ON.
2. Policies: SELECT + INSERT + UPDATE for `anon` / `authenticated`.
