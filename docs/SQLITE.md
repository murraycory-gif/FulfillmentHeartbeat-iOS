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

HB-0828.400 / 1.0 (726) — Open/foreground replaces a stale local pack. Cold open painted the cached company seat and stamped `hb.cloudPackUpdated` after downloading `current.sqlite` into `heartbeat.sqlite`, then `loadPack()` read the old seat file — same ~21MB size skipped the next fetch. Now compare storage `updated_at` vs `pack_meta.written_at`, copy root onto the company seat, invalidate seat chrome, stamp UserDefaults only after reload. Cook-only 50MB / company-as-root from .399 stay.
