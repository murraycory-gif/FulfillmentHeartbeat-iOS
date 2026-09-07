# Heartbeat pack (what testers open)

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`  
Bucket: `heartbeat-packs`

Testers download **`current.sqlite`** and **`pulse-cards.json`**.  
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
