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

HB-0828.393 / 1.0 (719) — iPhone UX rewrite: PhoneScorecardRow on every Pages row; pad table headers/cheap lines refuse to mount when idiom==.phone or compact. Filters sheet full-width 52pt. Command Center readable density. Who’s looking stays locked off. Unassigned Markets/Regions stay hidden. Recook + republish still required for OM people packs.
