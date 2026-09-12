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
(the ~21MB company seat as `current.sqlite` when the ~56MB market pack is over
the Storage cap, plus `packs/manifest.json` + the company seat path), then
uploads seats in parallel. Testers force-close Heartbeat. They never pick a file.

If `gh workflow run` is unavailable, kick the same cook with
`repository_dispatch`:

```bash
gh api repos/murraycory-gif/FulfillmentHeartbeat-iOS/dispatches \
  -f event_type=cook-heartbeat-pack
```

The 15-minute cron is a backup when the xlsx is newer than `current.sqlite`.

## Storage file size (Cory — required)

The cooked **market** `current.sqlite` is ~**56MB after VACUUM**. This project
rejects that with **413 EntityTooLarge / TUS "Maximum size exceeded"**
(limit appears **~50MB**). The publishable API cannot raise it.

**Do this once in the dashboard:**

1. Open [Supabase](https://supabase.com/dashboard) → project `pcnjujfmlsklhrosxzlt`
2. **Storage → Settings**
3. Set **Global file size limit** to **60 MB or higher** (80 MB is fine)
4. Save

Until that is raised, Actions publishes the **~21MB company seat**
(`packs/seat/company/all/current.sqlite`) as **both** root `current.sqlite`
and the company seat path. District seats stay parallel. A company **413**
fails the cook job — it does **not** leave a stale pack looking fresh.

## First-time bucket

1. Storage → New bucket → `heartbeat-packs` → Public ON.
2. Policies: SELECT + INSERT + UPDATE for `anon` / `authenticated`.
3. Storage → Settings → Global file size limit → **60 MB+** (see above).
