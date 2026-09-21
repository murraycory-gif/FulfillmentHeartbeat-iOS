# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` plus **seat packs** and publishes them to Cloudflare R2.

Download: `https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite`

Company seat key: `https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/packs/seat/company/all/current.sqlite`

The Daily Report workbook stays on Supabase Storage. `r2.dev` is rate-limited.
Swap `HBPackHost` in `FulfillmentHeartbeat/Info.plist` (and `PulseCloud.defaultPackHost`)
to a custom domain later. Cook stays on the weekday `*/15` schedule.

See [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md) for the Tip 1 contract.

## Layout

```
current.sqlite                         # LIVE root. Company seat (~21MB) when market ~56MB exceeds Storage ~50MB.
packs/manifest.json
packs/seat/company/all/current.sqlite  # thin company summary (also copied to root when market is over the limit)
packs/seat/district/03/current.sqlite
packs/seat/om/Jino-Arvin/current.sqlite
packs/seat/store/12/current.sqlite
```

Under a seat the hub paints from **that** sqlite only. Market
`current.sqlite` is not the primary. `applySeatSlice` of the full market
is banned.

District 03 is 20 NorCal stores. Every section Stores N = 20.

## Stamp

HB-0828.464 / 1.0 (783) — THIS SEAT callout removed on every page and filter. Company seat cap 40MB. 436 KEEP: Pick Path expand shoppers + Prep Store chrome.
