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

HB-0828.402 / 1.0 (728) — Share Send dismisses SharePulseSheet first, then presents MFMailCompose from the key-window root (never over the active sheet). `canSendMail == false` copies the recap and offers Outlook / mailto with a clear alert. Jetsam Soft KEEP from .401: company does not pre-expand all sections into RAM — chrome/page/stream only. `expandTables` at region grain with no `only` returns empty. `canonicalName` is cached. Thin seat + .400 freshness kept.
