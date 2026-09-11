# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` plus **seat packs** and publishes them to `heartbeat-packs`.

See [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md) for the Tip 1 contract.

## Layout

```
current.sqlite                         # market — Who’s looking roster + Clear
packs/manifest.json
packs/seat/company/all/current.sqlite  # thin company summary
packs/seat/district/03/current.sqlite
packs/seat/om/Jino-Arvin/current.sqlite
packs/seat/store/12/current.sqlite
```

Under a seat the hub paints from **that** sqlite only. Market
`current.sqlite` is not the primary. `applySeatSlice` of the full market
is banned.

District 03 is 20 NorCal stores. Every section Stores N = 20.

## Stamp

HB-0828.399 / 1.0 (725) — Cook-only publish: company `current.sqlite` + `packs/manifest.json` go LIVE first; ~2300 seats upload in parallel (`xargs -P 16`) with curl timeouts/retries. Company green even if some seats retry. Authenticated xlsx URL is `/storage/v1/object/authenticated/heartbeat-packs/Heartbeat Daily Report.xlsx` (≥1MB). Cook runs on `workflow_dispatch`, `repository_dispatch` (`cook-heartbeat-pack`), or when xlsx `updated_at` is newer than a usable sqlite. Kitchen still compiles tip Storage sources without SwiftUI/HubLayout. Phone Pages / filter-chip locks from .398 stay. Who’s looking stays locked off. Unassigned Markets/Regions stay hidden.
