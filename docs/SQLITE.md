# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` plus **seat packs** and publishes them to `heartbeat-packs`.

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

HB-0828.402 / 1.0 (728) — JetsamEvent 2026-09-11 10:21:11 CT iPad13,10: FulfillmentHeartbeat rpages≈4.0GB frontmost. Thin company seat (≤28MB / ~21MB) kept from .401. Never promote 56MB market. Company grain expand is page/stream only — never prefill all `dashboardCards` grainTables. Drop company expand caches after seat promote. `canonicalName` is cached. keepLastGoodSeat still skips wipe; clear `factsOwned` and put `seatPaint` in `sectionSQLTaskToken` so `ensureSectionLoaded` re-runs.
