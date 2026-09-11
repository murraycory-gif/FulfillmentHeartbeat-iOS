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

HB-0828.399 / 1.0 (725) — Cook-only: Storage ~50MB TUS cap. Market pack ~56MB is never uploaded as root (that 413s and can bump `updated_at` on a stale file). Company seat ~21MB is published as `current.sqlite` + seat path LIVE first; seats upload `xargs -P 16` with retries. A company 413 fails the job loudly. Cory: Dashboard → Storage → Settings → Global file size limit → 60MB+. Authenticated xlsx URL; refuse under 1MB. Skip only if sqlite is newer and ≥1MB. Phone locks from .398 stay.
